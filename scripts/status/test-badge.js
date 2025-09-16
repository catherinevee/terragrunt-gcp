#!/usr/bin/env node

/**
 * Test script for deployment status badge
 */

const fs = require('fs');
const path = require('path');

console.log('🧪 Testing deployment status badge functionality...\n');

// Test 1: Check if status checking script exists and is executable
console.log('1️⃣ Testing status checking script...');
const statusScript = path.join(__dirname, 'check-deployment-status.sh');
if (fs.existsSync(statusScript)) {
    console.log('   ✅ Status checking script exists');
    
    // Check if it's executable (on Unix systems)
    try {
        const stats = fs.statSync(statusScript);
        if (stats.mode & parseInt('111', 8)) {
            console.log('   ✅ Status checking script is executable');
        } else {
            console.log('   ⚠️  Status checking script is not executable (run: chmod +x check-deployment-status.sh)');
        }
    } catch (error) {
        console.log('   ⚠️  Could not check executable permissions');
    }
} else {
    console.log('   ❌ Status checking script not found');
}

// Test 2: Check if PowerShell script exists
console.log('\n2️⃣ Testing PowerShell status script...');
const psScript = path.join(__dirname, 'check-deployment-status.ps1');
if (fs.existsSync(psScript)) {
    console.log('   ✅ PowerShell status script exists');
} else {
    console.log('   ❌ PowerShell status script not found');
}

// Test 3: Test badge generation
console.log('\n3️⃣ Testing badge generation...');
try {
    const { generateBadge } = require('./generate-badges.js');
    
    const testConfigs = [
        { color: '#28a745', text: 'LIVE', label: 'Deployment' },
        { color: '#dc3545', text: 'UNALIVE', label: 'Deployment' },
        { color: '#ffc107', text: 'PARTIAL', label: 'Deployment', textColor: '#000000' }
    ];
    
    testConfigs.forEach((config, index) => {
        const svg = generateBadge(config);
        if (svg.includes('<svg') && svg.includes('</svg>')) {
            console.log(`   ✅ Badge ${index + 1} generated successfully`);
        } else {
            console.log(`   ❌ Badge ${index + 1} generation failed`);
        }
    });
} catch (error) {
    console.log('   ❌ Badge generation failed:', error.message);
}

// Test 4: Check if GitHub workflow exists
console.log('\n4️⃣ Testing GitHub workflow...');
const workflowPath = path.join(__dirname, '..', '..', '.github', 'workflows', 'update-deployment-status.yml');
if (fs.existsSync(workflowPath)) {
    console.log('   ✅ GitHub workflow exists');
    
    // Check workflow content
    const workflowContent = fs.readFileSync(workflowPath, 'utf8');
    if (workflowContent.includes('update-deployment-status') && workflowContent.includes('cron')) {
        console.log('   ✅ GitHub workflow appears to be properly configured');
    } else {
        console.log('   ⚠️  GitHub workflow may not be properly configured');
    }
} else {
    console.log('   ❌ GitHub workflow not found');
}

// Test 5: Check if docs directory structure exists
console.log('\n5️⃣ Testing documentation structure...');
const docsDir = path.join(__dirname, '..', '..', 'docs', 'status');
if (fs.existsSync(docsDir)) {
    console.log('   ✅ Docs directory exists');
} else {
    console.log('   ⚠️  Docs directory does not exist (will be created by workflow)');
}

// Test 6: Test status simulation
console.log('\n6️⃣ Testing status simulation...');
const testStatuses = ['LIVE', 'UNALIVE', 'PARTIAL', 'UNKNOWN'];

testStatuses.forEach(status => {
    const statusData = {
        status: status,
        timestamp: new Date().toISOString(),
        project_id: 'cataziza-platform-dev',
        region: 'europe-west1',
        last_checked: new Date().toUTCString()
    };
    
    const statusFile = path.join(__dirname, `test-${status.toLowerCase()}.json`);
    fs.writeFileSync(statusFile, JSON.stringify(statusData, null, 2));
    console.log(`   ✅ Created test status file: ${statusFile}`);
});

console.log('\n🎉 Badge functionality test completed!');
console.log('\nNext steps:');
console.log('1. Run the status checking script manually to test GCP connectivity');
console.log('2. Commit and push changes to trigger the GitHub workflow');
console.log('3. Check the status badge in the README after the workflow runs');
console.log('4. Visit the status dashboard at: https://catherinevee.github.io/terraform-gcp/status/');

// Cleanup test files
console.log('\n🧹 Cleaning up test files...');
testStatuses.forEach(status => {
    const statusFile = path.join(__dirname, `test-${status.toLowerCase()}.json`);
    if (fs.existsSync(statusFile)) {
        fs.unlinkSync(statusFile);
        console.log(`   ✅ Cleaned up ${statusFile}`);
    }
});