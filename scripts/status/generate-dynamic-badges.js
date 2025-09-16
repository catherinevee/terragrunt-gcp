/**
 * Dynamic Badge Generator for Terraform GCP Infrastructure
 * Generates multiple dynamic badges including health, deployment, and version info
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Badge configuration
const BADGE_CONFIG = {
  infrastructure: {
    name: 'Infrastructure Health',
    file: 'infrastructure.svg',
    statuses: {
      healthy: { color: 'brightgreen', text: 'Healthy' },
      degraded: { color: 'yellow', text: 'Degraded' },
      unhealthy: { color: 'red', text: 'Unhealthy' },
      destroyed: { color: 'red', text: 'Destroyed' }
    }
  },
  deployment: {
    name: 'Deployment Status',
    file: 'deployment.svg',
    statuses: {
      success: { color: 'brightgreen', text: 'Success' },
      failure: { color: 'red', text: 'Failed' },
      pending: { color: 'yellow', text: 'Pending' },
      destroyed: { color: 'red', text: 'Destroyed' }
    }
  },
  terraform: {
    name: 'Terraform Version',
    file: 'terraform.svg',
    statuses: {
      version: { color: 'blue', text: '1.5.0+' }
    }
  },
  gcp: {
    name: 'GCP Provider',
    file: 'gcp.svg',
    statuses: {
      version: { color: 'blue', text: '5.45.2+' }
    }
  }
};

/**
 * Generate SVG badge
 */
function generateBadge(label, status, color, message) {
  // Calculate appropriate dimensions based on label length
  let width, labelWidth, statusWidth;
  
  if (label.length > 15) {
    // For longer labels like "Infrastructure Health"
    width = 200;
    labelWidth = 140;
    statusWidth = 60;
  } else if (label.length > 10) {
    // For medium labels like "Deployment Status"
    width = 180;
    labelWidth = 120;
    statusWidth = 60;
  } else {
    // For shorter labels like "Terraform Version"
    width = 160;
    labelWidth = 100;
    statusWidth = 60;
  }
  
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="20">
    <rect width="${labelWidth}" height="20" fill="#555"/>
    <rect x="${labelWidth}" width="${statusWidth}" height="20" fill="#${color}"/>
    <text x="5" y="14" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11" fill="#fff">${label}</text>
    <text x="${labelWidth + 5}" y="14" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11" fill="#fff">${message}</text>
  </svg>`;
}

/**
 * Check infrastructure health status
 */
function checkInfrastructureHealth() {
  try {
    // Check if recent deployment was a destroy operation
    const lastDeployment = getLastDeploymentStatus();
    if (lastDeployment === 'destroyed') {
      return 'destroyed';
    }
    
    // Check if infrastructure exists
    const terraformDir = path.join(process.cwd(), 'infrastructure');
    if (!fs.existsSync(terraformDir)) {
      return 'destroyed';
    }
    
    // Check for any error files
    const errorFiles = ['error.log', 'failure.log', 'degraded.log'];
    for (const file of errorFiles) {
      if (fs.existsSync(path.join(terraformDir, file))) {
        return 'unhealthy';
      }
    }
    
    // Check if recent deployment was successful
    if (lastDeployment === 'success') {
      return 'healthy';
    } else if (lastDeployment === 'failure') {
      return 'unhealthy';
    }
    
    return 'healthy';
  } catch (error) {
    console.error('Error checking infrastructure health:', error);
    return 'unhealthy';
  }
}

/**
 * Check deployment status
 */
function checkDeploymentStatus() {
  try {
    // Check if destroy marker exists
    const destroyFile = path.join(process.cwd(), 'infrastructure/environments/dev/global/.destroy-in-progress');
    if (fs.existsSync(destroyFile)) {
      return 'destroyed';
    }
    
    // Check last deployment
    const lastDeployment = getLastDeploymentStatus();
    return lastDeployment || 'pending';
  } catch (error) {
    console.error('Error checking deployment status:', error);
    return 'failure';
  }
}

/**
 * Get last deployment status from git or workflow
 */
function getLastDeploymentStatus() {
  try {
    // Check if there's a recent destroy workflow run
    const ghRuns = execSync('gh run list --workflow="terraform-gcp-pipeline.yml" --json "databaseId,status,conclusion,event,createdAt" --limit 3', { encoding: 'utf8' });
    const runs = JSON.parse(ghRuns);
    
    // Check the most recent run
    if (runs.length > 0) {
      const latestRun = runs[0];
      const runTime = new Date(latestRun.createdAt);
      const now = new Date();
      const timeDiff = now - runTime;
      
      console.log(`Latest run: ${latestRun.event}, status: ${latestRun.status}, conclusion: ${latestRun.conclusion}, time diff: ${timeDiff}ms`);
      
      // If the run was within the last 30 minutes and was a workflow_dispatch event
      if (timeDiff < 30 * 60 * 1000 && latestRun.event === 'workflow_dispatch') {
        if (latestRun.status === 'completed' && latestRun.conclusion === 'success') {
          console.log('Detected recent successful workflow_dispatch - marking as destroyed');
          return 'destroyed';
        }
      }
    }
    
    // Check git log for recent commits
    const gitLog = execSync('git log --oneline -5', { encoding: 'utf8' });
    if (gitLog.includes('destroy') || gitLog.includes('Destroy')) {
      return 'destroyed';
    }
    if (gitLog.includes('fix') || gitLog.includes('update')) {
      return 'success';
    }
    return 'success';
  } catch (error) {
    return 'pending';
  }
}

/**
 * Get Terraform version
 */
function getTerraformVersion() {
  try {
    const version = execSync('terraform version -json', { encoding: 'utf8' });
    const parsed = JSON.parse(version);
    return parsed.terraform_version || '1.5.0+';
  } catch (error) {
    return '1.5.0+';
  }
}

/**
 * Get GCP provider version
 */
function getGCPProviderVersion() {
  try {
    // Read from terraform files
    const terraformFiles = [
      'infrastructure/modules/networking/vpc/main.tf',
      'infrastructure/modules/compute/instances/main.tf',
      'infrastructure/modules/security/iam/main.tf'
    ];
    
    for (const file of terraformFiles) {
      if (fs.existsSync(file)) {
        const content = fs.readFileSync(file, 'utf8');
        const match = content.match(/version\s*=\s*["']([^"']+)["']/);
        if (match) {
          return match[1];
        }
      }
    }
    return '5.45.2+';
  } catch (error) {
    return '5.45.2+';
  }
}

/**
 * Generate all badges
 */
function generateAllBadges() {
  console.log('🚀 Generating dynamic badges...');
  
  // Ensure output directory exists
  const outputDir = path.join(process.cwd(), 'docs/status');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  // Generate infrastructure health badge
  const infraHealth = checkInfrastructureHealth();
  const infraConfig = BADGE_CONFIG.infrastructure;
  const infraStatus = infraConfig.statuses[infraHealth] || infraConfig.statuses.unhealthy;
  const infraSvg = generateBadge(infraConfig.name, infraHealth, infraStatus.color, infraStatus.text);
  fs.writeFileSync(path.join(outputDir, infraConfig.file), infraSvg);
  console.log(`✅ Generated ${infraConfig.file}: ${infraStatus.text}`);
  
  // Generate deployment status badge
  const deployStatus = checkDeploymentStatus();
  const deployConfig = BADGE_CONFIG.deployment;
  const deployStatusInfo = deployConfig.statuses[deployStatus] || deployConfig.statuses.pending;
  const deploySvg = generateBadge(deployConfig.name, deployStatus, deployStatusInfo.color, deployStatusInfo.text);
  fs.writeFileSync(path.join(outputDir, deployConfig.file), deploySvg);
  console.log(`✅ Generated ${deployConfig.file}: ${deployStatusInfo.text}`);
  
  // Generate Terraform version badge
  const tfVersion = getTerraformVersion();
  const tfConfig = BADGE_CONFIG.terraform;
  const tfSvg = generateBadge(tfConfig.name, 'version', 'blue', tfVersion);
  fs.writeFileSync(path.join(outputDir, tfConfig.file), tfSvg);
  console.log(`✅ Generated ${tfConfig.file}: ${tfVersion}`);
  
  // Generate GCP provider version badge
  const gcpVersion = getGCPProviderVersion();
  const gcpConfig = BADGE_CONFIG.gcp;
  const gcpSvg = generateBadge(gcpConfig.name, 'version', 'blue', gcpVersion);
  fs.writeFileSync(path.join(outputDir, gcpConfig.file), gcpSvg);
  console.log(`✅ Generated ${gcpConfig.file}: ${gcpVersion}`);
  
  console.log('🎉 All dynamic badges generated successfully!');
  
  // Output badge URLs for README
  console.log('\n📋 Badge URLs for README:');
  console.log(`![${infraConfig.name}](https://catherinevee.github.io/terraform-gcp/status/${infraConfig.file})`);
  console.log(`![${deployConfig.name}](https://catherinevee.github.io/terraform-gcp/status/${deployConfig.file})`);
  console.log(`![${tfConfig.name}](https://catherinevee.github.io/terraform-gcp/status/${tfConfig.file})`);
  console.log(`![${gcpConfig.name}](https://catherinevee.github.io/terraform-gcp/status/${gcpConfig.file})`);
}

// Run the badge generation
if (require.main === module) {
  generateAllBadges();
}

module.exports = { generateAllBadges, generateBadge };
