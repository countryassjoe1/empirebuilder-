#!/usr/bin/env bash
#  ──────────────────────────────────────────────────────────────────────────────
#  setup_empire.sh
#  Builds a fresh "Austin Codex – Empire" repo skeleton ready for
#  git‑commit, Docker, GitHub‑Actions, and immediate start‑up of the paid‑template API.
#
#  Usage:  bash setup_empire.sh my_awesome_empire
#  **************************************************************************

set -euo pipefail

# --------------------------------------------------------------------------- #
#  Parameters & sanity checks
# --------------------------------------------------------------------------- #
PROJECT="$1"

if [[ -z "${PROJECT}" ]]; then
  echo "❗️  Usage: $0 <project‑folder‑name>"
  exit 1
fi

# Prevent accidental clobber of an existing folder
if [[ -d "${PROJECT}" ]]; then
  echo "❌  ${PROJECT} already exists – pick a different name."
  exit 1
fi

# --------------------------------------------------------------------------- #
#  Step 1: Core tree & static files
# --------------------------------------------------------------------------- #
mkdir -p "${PROJECT}"
cd "${PROJECT}"

# ── Repo‑ wide files
cat > .gitignore <<'EOF'
# Node
node_modules/
npm-debug.log
package-lock.json

# Logs
logs/
*.log

# Env
.env
.env.local
EOF

cat > README.md <<'EOF'
# Austin Codex – Empire Overview

> **“A living blueprint that turns systems into fortunes – the next decade is built on architecture, not hype.”**

## What you’ll find here

* A modular API service that turns Markdown‑style templates into PDF business plans, contracts, CVs, etc.
* A CI pipeline that builds a Docker image and can send it to Render, Fly.io, or any container host.
* A tiny logger + JWT auth layer that protects the endpoint.
* A build‑log that records every architectural decision (immutable, append‑only).

Happy hacking! 🚀
EOF

# Build‑log (immutable tracking)
cat > docs/build-log.md <<'EOF'
# Build Log – Austin Codex (Version 3.0)

| Timestamp           | Step | Decision | Asset | Notes |
|---------------------|------|----------|-------|-------|
EOF

# --------------------------------------------------------------------------- #
#  Step 2: Income service – templates & API
# --------------------------------------------------------------------------- #
mkdir -p income/templates income/api/generators income/api/middleware income/docker scripts income

# -- Templates -------------------------------------------------------------
cat > income/templates/business_plan.yaml <<'EOF'
title: "Business Plan"
sections:
  - title: "Executive Summary"
    content: "Brief overview of {company_name}"
  - title: "Market Analysis"
    content: "Target audience: {target_audience}"
  - title: "Revenue Model"
    content: "Projected monthly revenue: {monthly_revenue}"
  - title: "Milestones"
    content: "Phase 1: {phase1_date}"
EOF

cat > income/templates/contract-negotiation.yaml <<'EOF'
title: "Contract Negotiation Template"
sections:
  - title: "Parties"
    content: "{party_a} ↔ {party_b}"
  - title: "Scope"
    content: "Deliverables: {deliverables}"
  - title: "Payment Terms"
    content: "Rate: {rate} per hour, payable monthly."
  - title: "Termination"
    content: "Notice period: {notice_hours} hours."
EOF

# -- Node package ---------------------------------------------------------
cat > income/package.json <<'EOF'
{
  "name": "austin-income-service",
  "version": "1.0.0",
  "description": "Automated template generator for the Austin Codex Empire.",
  "main": "api/index.js",
  "scripts": {
    "start": "node api/index.js",
    "dev": "nodemon api/index.js",
    "test": "echo \"no tests yet\""
  },
  "dependencies": {
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "handlebars": "^4.7.7",
    "js-yaml": "^4.1.0",
    "jsonwebtoken": "^9.0.0",
    "pdfkit": "^0.13.0",
    "winston": "^3.9.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# -- API entry point -------------------------------------------------------
cat > income/api/index.js <<'EOF'
const express = require('express');
const { generateBusinessPlan } = require('./generators/business_plan');
const { auth } = require('./middleware/auth');
const { logger } = require('./middleware/logger');

const app = express();
app.use(express.json());
app.use(logger);

app.post('/generate/business-plan', auth, async (req, res) => {
  try {
    const pdfBuffer = await generateBusinessPlan(req.body);
    res.set('Content-Type', 'application/pdf');
    return res.send(pdfBuffer);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Generation failed' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`💵 Income API listening on ${PORT}`));
EOF

# -- Middleware -------------------------------------------------------------
cat > income/api/middleware/auth.js <<'EOF'
const JWT = require('jsonwebtoken');
const SECRET = process.env.JWT_SECRET || 'replace-me-in-prod';

function auth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.status(401).json({ error: 'Missing token' });

  const [, token] = authHeader.split(' ');
  try {
    const payload = JWT.verify(token, SECRET);
    req.user = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
module.exports = { auth };
EOF

cat > income/api/middleware/logger.js <<'EOF'
const winston = require('winston');
const logger = winston.createLogger({
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

function log(req, res, next) {
  logger.info(`💰 ${req.method} ${req.url} (user: ${req.user?.id ?? 'guest'})`);
  next();
}
module.exports = { logger };
EOF

# -- Business‑plan generator ------------------------------------------------
cat > income/api/generators/business_plan.js <<'EOF'
const Handlebars = require('handlebars');
const fs = require('fs');
const path = require('path');
const PDFDocument = require('pdfkit');
const yaml = require('js-yaml');

const templatePath = path.join(__dirname, '..', '..', '..', 'templates', 'business_plan.yaml');
const yamlStr = fs.readFileSync(templatePath, 'utf8');
const tpl = yaml.load(yamlStr);

async function generateBusinessPlan(vars) {
  const doc = new PDFDocument({ size: 'A4', margin: 50 });

  // Title
  doc.fontSize(20).text(tpl.title, { align: 'center' }).moveDown();

  // Sections
  for (const sec of tpl.sections) {
    const content = Handlebars.compile(sec.content)(vars);
    doc.fontSize(16).fillColor('#333').text(sec.title, { underline: true }).moveDown(0.2);
    doc.fontSize(12).fillColor('#000').text(content).moveDown();
  }

  doc.end();
  return new Promise((res, rej) => {
    const buffers = [];
    doc.on('data', buffers.push.bind(buffers));
    doc.on('end', () => res(Buffer.concat(buffers)));
    doc.on('error', rej);
  });
}
module.exports = { generateBusinessPlan };
EOF

# -- Dockerfile -------------------------------------------------------------
cat > income/docker/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["node", "api/index.js"]
EOF

# -- Build‑log -- append initial entry --------------------------------------
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
echo "| $TIMESTAMP | 0 | Created project scaffold | ${PROJECT} | Initial commit" >> docs/build-log.md

# --------------------------------------------------------------------------- #
#  Step 3: CI – GitHub Actions
# --------------------------------------------------------------------------- #
mkdir -p .github/workflows

cat > .github/workflows/build.yml <<'EOF'
name: Build, Test & Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
