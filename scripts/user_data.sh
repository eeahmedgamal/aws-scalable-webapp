#!/bin/bash
# This script runs once when each EC2 instance launches (via the Launch Template).
# It installs Node.js, deploys the sample app, and runs it as a systemd service
# so the ASG's health checks and the ALB target group have something to hit on /health.
set -euxo pipefail

# --- Install Node.js 18 (Amazon Linux 2023 ships dnf, not yum) --------------
dnf install -y nodejs npm

# --- Install and enable the CloudWatch agent for custom app metrics/logs ----
dnf install -y amazon-cloudwatch-agent

APP_DIR=/opt/app
mkdir -p "$APP_DIR"

# --- Deploy the app -----------------------------------------------------------
# In a real pipeline this would be `git clone` / `aws s3 cp` of a built artifact.
# It's inlined here so the instance can boot without extra dependencies.
cat > "$APP_DIR/package.json" << 'PKGJSON'
{
  "name": "scalable-webapp-sample",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.19.2",
    "mysql2": "^3.10.0"
  }
}
PKGJSON

cat > "$APP_DIR/server.js" << 'SERVERJS'
const express = require('express');
const mysql = require('mysql2/promise');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 80;

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'appdb',
  connectTimeout: 5000,
};

let pool;
if (dbConfig.host) {
  pool = mysql.createPool(dbConfig);
}

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', instance: os.hostname() });
});

app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Scalable web app is running',
    instance: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/db-check', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ status: 'error', message: 'DB_HOST not configured' });
  }
  try {
    const [rows] = await pool.query('SELECT 1 AS result');
    res.status(200).json({ status: 'ok', db_result: rows[0].result, instance: os.hostname() });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

app.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
SERVERJS

cd "$APP_DIR"
npm install --omit=dev

# --- Environment file consumed by the systemd unit ---------------------------
cat > /etc/app.env << ENVFILE
PORT=80
DB_HOST=${db_endpoint}
DB_NAME=${db_name}
ENVFILE
# NOTE: DB_PASSWORD is intentionally not written here in plaintext.
# In production, fetch it at boot time from Secrets Manager, e.g.:
#   aws secretsmanager get-secret-value --secret-id <name> --query SecretString --output text

# --- systemd service so the app survives reboots and crashes ----------------
cat > /etc/systemd/system/webapp.service << 'UNIT'
[Unit]
Description=Scalable web app
After=network.target

[Service]
EnvironmentFile=/etc/app.env
ExecStart=/usr/bin/node /opt/app/server.js
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable webapp
systemctl start webapp
