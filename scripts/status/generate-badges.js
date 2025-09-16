#!/usr/bin/env node

/**
 * Badge Generator for Terraform Deployment Status
 * Generates SVG badges for different deployment states
 */

const fs = require('fs');
const path = require('path');

// Badge configuration
const BADGE_CONFIG = {
    live: {
        color: '#28a745',
        text: 'LIVE',
        label: 'Deployment'
    },
    partial: {
        color: '#ffc107',
        text: 'PARTIAL',
        label: 'Deployment',
        textColor: '#000000'
    },
    unalive: {
        color: '#dc3545',
        text: 'UNALIVE',
        label: 'Deployment'
    },
    unknown: {
        color: '#6c757d',
        text: 'UNKNOWN',
        label: 'Deployment'
    }
};

/**
 * Generate SVG badge
 */
function generateBadge(config) {
    const { color, text, label, textColor = '#ffffff' } = config;
    
    // Calculate text width (approximate)
    const textWidth = text.length * 6 + 10;
    const labelWidth = label.length * 6 + 10;
    const totalWidth = labelWidth + textWidth;
    
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="20">
    <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <mask id="a">
        <rect width="${totalWidth}" height="20" rx="3" fill="#fff"/>
    </mask>
    <g mask="url(#a)">
        <path fill="#555" d="M0 0h${labelWidth}v20H0z"/>
        <path fill="${color}" d="M${labelWidth} 0h${textWidth}v20H${labelWidth}z"/>
        <path fill="url(#b)" d="M0 0h${totalWidth}v20H0z"/>
    </g>
    <g fill="${textColor}" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="${labelWidth / 2}" y="15" fill="#010101" fill-opacity=".3">${label}</text>
        <text x="${labelWidth / 2}" y="14">${label}</text>
        <text x="${labelWidth + textWidth / 2}" y="15" fill="#010101" fill-opacity=".3">${text}</text>
        <text x="${labelWidth + textWidth / 2}" y="14">${text}</text>
    </g>
</svg>`;
}

/**
 * Generate all badges
 */
function generateAllBadges() {
    const outputDir = path.join(__dirname, '..', '..', 'docs', 'status');
    
    // Create output directory if it doesn't exist
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }
    
    // Generate badges for each status
    Object.entries(BADGE_CONFIG).forEach(([status, config]) => {
        const svg = generateBadge(config);
        const filePath = path.join(outputDir, `${status}.svg`);
        
        fs.writeFileSync(filePath, svg);
        console.log(`✅ Generated badge: ${filePath}`);
    });
    
    // Generate dynamic badge that reads from status file
    const dynamicBadgeScript = `#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Read status from deployment-status.json
let status = 'unknown';
try {
    const statusFile = path.join(__dirname, '..', '..', 'deployment-status.json');
    if (fs.existsSync(statusFile)) {
        const data = JSON.parse(fs.readFileSync(statusFile, 'utf8'));
        status = data.status.toLowerCase();
    }
} catch (error) {
    console.error('Error reading status file:', error);
}

// Badge configuration
const BADGE_CONFIG = {
    live: { color: '#28a745', text: 'LIVE', label: 'Deployment' },
    partial: { color: '#ffc107', text: 'PARTIAL', label: 'Deployment', textColor: '#000000' },
    unalive: { color: '#dc3545', text: 'UNALIVE', label: 'Deployment' },
    unknown: { color: '#6c757d', text: 'UNKNOWN', label: 'Deployment' }
};

function generateBadge(config) {
    const { color, text, label, textColor = '#ffffff' } = config;
    const textWidth = text.length * 6 + 10;
    const labelWidth = label.length * 6 + 10;
    const totalWidth = labelWidth + textWidth;
    
    return \`<svg xmlns="http://www.w3.org/2000/svg" width="\${totalWidth}" height="20">
    <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <mask id="a">
        <rect width="\${totalWidth}" height="20" rx="3" fill="#fff"/>
    </mask>
    <g mask="url(#a)">
        <path fill="#555" d="M0 0h\${labelWidth}v20H0z"/>
        <path fill="\${color}" d="M\${labelWidth} 0h\${textWidth}v20H\${labelWidth}z"/>
        <path fill="url(#b)" d="M0 0h\${totalWidth}v20H0z"/>
    </g>
    <g fill="\${textColor}" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="\${labelWidth / 2}" y="15" fill="#010101" fill-opacity=".3">\${label}</text>
        <text x="\${labelWidth / 2}" y="14">\${label}</text>
        <text x="\${labelWidth + textWidth / 2}" y="15" fill="#010101" fill-opacity=".3">\${text}</text>
        <text x="\${labelWidth + textWidth / 2}" y="14">\${text}</text>
    </g>
</svg>\`;
}

const config = BADGE_CONFIG[status] || BADGE_CONFIG.unknown;
const svg = generateBadge(config);

console.log(svg);
`;
    
    const dynamicBadgePath = path.join(outputDir, 'badge.js');
    fs.writeFileSync(dynamicBadgePath, dynamicBadgeScript);
    console.log(`✅ Generated dynamic badge script: ${dynamicBadgePath}`);
    
    console.log('\n🎉 All badges generated successfully!');
    console.log('\nUsage:');
    console.log('  - Static badges: docs/status/{live,partial,unalive,unknown}.svg');
    console.log('  - Dynamic badge: node docs/status/badge.js > docs/status/badge.svg');
}

// Run if called directly
if (require.main === module) {
    generateAllBadges();
}

module.exports = { generateBadge, generateAllBadges };