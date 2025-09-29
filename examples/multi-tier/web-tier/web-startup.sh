#!/bin/bash

# Web tier startup script for multi-tier application
# This script configures and starts the web server

set -e

# Update system packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    nginx \
    curl \
    wget \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq

# Install Node.js (for modern web applications)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install monitoring agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# Create application user
useradd -m -s /bin/bash webapp
usermod -aG sudo webapp

# Create application directories
mkdir -p /opt/webapp/{app,logs,config}
chown -R webapp:webapp /opt/webapp

# Configure nginx
cat > /etc/nginx/sites-available/webapp << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Application proxy
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Static files
    location /static/ {
        alias /opt/webapp/app/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Logging
    access_log /var/log/nginx/webapp_access.log;
    error_log /var/log/nginx/webapp_error.log;
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Create a simple Node.js application
cat > /opt/webapp/app/app.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

// Middleware
app.use(express.json());
app.use('/static', express.static('static'));

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).send('healthy');
});

// API status endpoint
app.get('/api/status', (req, res) => {
    res.json({
        status: 'running',
        tier: 'web',
        timestamp: new Date().toISOString(),
        hostname: require('os').hostname(),
        uptime: process.uptime()
    });
});

// Main application route
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Multi-Tier Web Application</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    margin: 40px;
                    background-color: #f5f5f5;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                    background: white;
                    padding: 30px;
                    border-radius: 8px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                h1 { color: #333; }
                .status {
                    background: #e8f5e8;
                    padding: 15px;
                    border-radius: 4px;
                    margin: 20px 0;
                }
                .tier {
                    color: #4285f4;
                    font-weight: bold;
                }
                .hostname {
                    color: #666;
                    font-size: 0.9em;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🌐 Multi-Tier Web Application</h1>
                <div class="status">
                    <p><strong>Status:</strong> Running</p>
                    <p><strong>Tier:</strong> <span class="tier">Web (Frontend)</span></p>
                    <p><strong>Hostname:</strong> <span class="hostname">${require('os').hostname()}</span></p>
                    <p><strong>Timestamp:</strong> ${new Date().toISOString()}</p>
                </div>

                <h2>Architecture Overview</h2>
                <p>This is the web tier of a three-tier application architecture:</p>
                <ul>
                    <li><strong>Web Tier:</strong> Frontend servers (this server)</li>
                    <li><strong>Application Tier:</strong> Backend API servers</li>
                    <li><strong>Data Tier:</strong> Database servers</li>
                </ul>

                <h2>Features</h2>
                <ul>
                    <li>Load balanced web servers</li>
                    <li>Auto-scaling instance groups</li>
                    <li>Health checks and monitoring</li>
                    <li>Security best practices</li>
                    <li>Automated deployment with Terragrunt</li>
                </ul>

                <p><a href="/api/status">View API Status</a></p>
            </div>
        </body>
        </html>
    `);
});

// API proxy to application tier
app.get('/api/*', async (req, res) => {
    try {
        const appTierUrl = '${app_lb_ip}' || 'http://10.0.2.100:8080';
        const response = await fetch(appTierUrl + req.path);
        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(503).json({
            error: 'Application tier unavailable',
            message: error.message
        });
    }
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        error: 'Internal server error',
        tier: 'web'
    });
});

// Start server
app.listen(port, '0.0.0.0', () => {
    console.log(`Web tier application listening on port ${port}`);
});
EOF

# Create package.json
cat > /opt/webapp/app/package.json << 'EOF'
{
  "name": "webapp-frontend",
  "version": "1.0.0",
  "description": "Multi-tier web application frontend",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# Install Node.js dependencies
cd /opt/webapp/app
sudo -u webapp npm install

# Create systemd service for the web application
cat > /etc/systemd/system/webapp.service << 'EOF'
[Unit]
Description=Web Application Frontend
After=network.target

[Service]
Type=simple
User=webapp
WorkingDirectory=/opt/webapp/app
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=webapp

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/webapp/logs

[Install]
WantedBy=multi-user.target
EOF

# Configure log rotation
cat > /etc/logrotate.d/webapp << 'EOF'
/opt/webapp/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 webapp webapp
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# Set proper permissions
chown -R webapp:webapp /opt/webapp

# Enable and start services
systemctl daemon-reload
systemctl enable webapp
systemctl start webapp
systemctl enable nginx
systemctl restart nginx

# Configure firewall (if ufw is installed)
if command -v ufw >/dev/null 2>&1; then
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
fi

# Configure monitoring
cat > /etc/google-cloud-ops-agent/config.yaml << 'EOF'
logging:
  receivers:
    nginx_access:
      type: nginx_access
    nginx_error:
      type: nginx_error
    webapp_logs:
      type: files
      include_paths:
        - /opt/webapp/logs/*.log
  processors:
    webapp_parser:
      type: parse_json
      field: message
  service:
    pipelines:
      default_pipeline:
        receivers: [nginx_access, nginx_error, webapp_logs]
        processors: [webapp_parser]

metrics:
  receivers:
    nginx:
      type: nginx
    hostmetrics:
      type: hostmetrics
  service:
    pipelines:
      default_pipeline:
        receivers: [nginx, hostmetrics]
EOF

# Restart monitoring agent
systemctl restart google-cloud-ops-agent

# Final health check
sleep 10
curl -f http://localhost/health || {
    echo "Health check failed!"
    systemctl status webapp
    systemctl status nginx
    exit 1
}

echo "Web tier startup completed successfully!"

# Log startup completion
logger "Web tier startup script completed successfully"