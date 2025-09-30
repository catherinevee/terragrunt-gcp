#!/usr/bin/env node
/**
 * Simple badge server for security status
 */

const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static badge files
app.get('/badge/:name', (req, res) => {
  const badgeName = req.params.name;
  const badgePath = path.join(__dirname, '../../badges', `${badgeName}.json`);

  if (fs.existsSync(badgePath)) {
    res.setHeader('Content-Type', 'application/json');
    res.sendFile(badgePath);
  } else {
    res.status(404).json({
      schemaVersion: 1,
      label: badgeName,
      message: 'unknown',
      color: 'lightgrey'
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Terragrunt GCP Security Badge Server',
    version: '1.0.0',
    endpoints: {
      badges: '/badge/:name',
      health: '/health'
    }
  });
});

app.listen(PORT, () => {
  console.log(`✅ Badge server running on port ${PORT}`);
  console.log(`🔗 http://localhost:${PORT}`);
});

module.exports = app;