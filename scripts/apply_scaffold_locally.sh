#!/usr/bin/env bash
set -euo pipefail

# apply_scaffold_locally.sh
# Creates the Austin Empire scaffold files in the current repository,
# commits them on branch `scaffold/austin-empire`, and attempts to push
# and open a PR with `gh`.

BRANCH="scaffold/austin-empire"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required. Install git and run this from your repository root."
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Please run this script from the root of your local repository clone."
  exit 1
fi

set -x

git checkout -b "$BRANCH"

# Create directories
mkdir -p austin-empire/income/api/generators austin-empire/income/api/middleware austin-empire/income/docker austin-empire/income/templates austin-empire/income/test austin-empire/.github/workflows austin-empire/docs assets/logo assets/avatar assets/ui src/digital src/physical src/money src/protocol src/future scripts

# Files
cat > austin-empire/.gitignore <<'EOF'
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

cat > austin-empire/README.md <<'EOF'
# Austin Codex – Empire Overview

> **“A living blueprint that turns systems into fortunes – the next decade is built on architecture, not hype.”**

## What you’ll find here

* A modular API service that turns Markdown‑style templates into PDF business plans, contracts, CVs, etc.
* A CI pipeline that builds a Docker image and can send it to Render, Fly.io, or any container host.
* A tiny logger + JWT auth layer that protects the endpoint.
* A build‑log that records every architectural decision (immutable, append‑only).

Happy hacking! 🚀
EOF

cat > austin-empire/docs/build-log.md <<'EOF'
# Build Log – Austin Codex (Version 3.0

| Timestamp           | Step | Decision | Asset | Notes |
|---------------------|------|----------|-------|-------|
EOF

cat > austin-empire/income/package.json <<'EOF'
{
  "name": "austin-income-service",
  "version": "1.0.0",
  "description": "Automated template generator for the Austin Codex Empire.",
  "main": "api/index.js",
  "scripts": {
    "start": "node api/index.js",
    "dev": "nodemon api/index.js",
    "lint": "npx eslint . --ext .js",
    "test": "node test/generate.test.js && node test/stripe.test.js"
  },
  "dependencies": {
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "handlebars": "^4.7.7",
    "js-yaml": "^4.1.0",
    "jsonwebtoken": "^9.0.0",
    "pdfkit": "^0.13.0",
    "winston": "^3.9.0",
    "stripe": "^12.13.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "eslint": "^8.40.0",
    "sinon": "^15.2.0",
    "proxyquire": "^2.1.3"
  }
}
EOF

cat > austin-empire/income/api/index.js <<'EOF'
const express = require('express');
const { generateBusinessPlan } = require('./generators/business_plan');
const { auth } = require('./middleware/auth');
const { logger } = require('./middleware/logger');
const stripeRouter = require('./stripe');

const app = express();
app.use(express.json());
app.use(logger);

// Mount Stripe routes
app.use('/stripe', stripeRouter);

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

cat > austin-empire/income/api/generators/business_plan.js <<'EOF'
const Handlebars = require('handlebars');
const fs = require('fs');
const path = require('path');
const PDFDocument = require('pdfkit');
const yaml = require('js-yaml');

const templatePath = path.join(__dirname, '..', '..', 'templates', 'business_plan.yaml');
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

cat > austin-empire/income/api/middleware/auth.js <<'EOF'
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

cat > austin-empire/income/api/middleware/logger.js <<'EOF'
const winston = require('winston');
const winstonLogger = winston.createLogger({
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

function logger(req, res, next) {
  winstonLogger.info(`💰 ${req.method} ${req.url} (user: ${req.user?.id ?? 'guest'})`);
  next();
}
module.exports = { logger };

// Expose the winston instance in case other modules need it
module.exports.winston = winstonLogger;
EOF

cat > austin-empire/income/api/stripe.js <<'EOF'
let StripeLib;
try {
  StripeLib = require('stripe');
} catch (e) {
  StripeLib = null;
}
const { generateBusinessPlan } = require('./generators/business_plan');

const StripeCtor = StripeLib && (StripeLib.default || StripeLib);
const stripe = StripeCtor ? new StripeCtor(process.env.STRIPE_SECRET_KEY || '', { apiVersion: '2022-11-15' }) : null;

const express = require('express');
const router = express.Router();

// Create a checkout session for a one-time business plan purchase
router.post('/create-checkout-session', async (req, res) => {
  const { price = 5000, currency = 'usd', success_url, cancel_url, metadata = {} } = req.body;
  try {
    if (!stripe) throw new Error('Stripe not configured');
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{ price_data: { currency, product_data: { name: 'Business Plan PDF' }, unit_amount: price }, quantity: 1 }],
      mode: 'payment',
      success_url: success_url || (req.headers.origin + '/success'),
      cancel_url: cancel_url || (req.headers.origin + '/cancel'),
      metadata,
    });
    return res.json({ id: session.id, url: session.url });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Stripe session creation failed' });
  }
});

// Webhook endpoint: verify the signature and trigger generation on checkout completion
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  let event;
  try {
    if (webhookSecret && stripe) {
      event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
    } else {
      // Fallback for local testing without signature verification
      event = req.body;
    }
  } catch (err) {
    console.error('Webhook signature verification failed.', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    try {
      const vars = {
        company_name: session.metadata?.company_name || 'Customer Inc',
        target_audience: session.metadata?.target || 'General',
        monthly_revenue: session.metadata?.monthly_revenue || '$0',
        phase1_date: session.metadata?.phase1_date || 'TBD',
      };
      await generateBusinessPlan(vars);
    } catch (e) {
      console.error('Failed to generate business plan from webhook', e);
    }
  }

  res.json({ received: true });
});

module.exports = router;
EOF

cat > austin-empire/income/docker/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["node", "api/index.js"]
EOF

cat > austin-empire/income/templates/business_plan.yaml <<'EOF'
title: "Business Plan"
sections:
  - title: "Executive Summary"
    content: "Brief overview of {company_name}"
  - title: "Market Analysis"
    content: "Target audience: {target_audience}"
  - title: "Revenue Model"
    content: "Projected monthly revenue: {monthly_revenue}"
  - title: "Milestones"
    content: "Phase 1: {phase1_date}"
EOF

cat > austin-empire/income/templates/contract-negotiation.yaml <<'EOF'
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

cat > austin-empire/income/test/generate.test.js <<'EOF'
const assert = require('assert');
const { generateBusinessPlan } = require('../api/generators/business_plan');

(async () => {
  const buf = await generateBusinessPlan({ company_name: 'TestCo', target_audience: 'Testers', monthly_revenue: '$0', phase1_date: '2026-01-01' });
  assert.ok(Buffer.isBuffer(buf), 'Expected a Buffer');
  console.log('✔ generateBusinessPlan returned a Buffer (size:', buf.length, ')');
})();
EOF

cat > austin-empire/income/test/stripe.test.js <<'EOF'
const assert = require('assert');
const sinon = require('sinon');
const proxyquire = require('proxyquire');

// Stub stripe client
const fakeStripe = {
  checkout: { sessions: { create: sinon.stub().resolves({ id: 'sess_123', url: 'https://checkout' }) } },
  webhooks: { constructEvent: sinon.stub() },
};

// Provide a fake constructor function for stripe so requiring works
const stripeCtorStub = function() { return fakeStripe; };

const stripeRouter = proxyquire('../api/stripe', { 'stripe': stripeCtorStub });

(async () => {
  // The router is an express Router; ensure the module loads
  assert.ok(stripeRouter, 'stripe router is exported');
  console.log('✔ stripe router loaded with stubbed stripe');
})();
EOF

cat > austin-empire/.env.example <<'EOF'
# Example environment variables
JWT_SECRET=replace-me
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
NODE_ENV=production
PORT=3000
EOF

cat > austin-empire/docs/payments.md <<'EOF'
# Payments & Payouts

This project includes a simple Stripe integration (see `income/api/stripe.js`) for creating checkout sessions and handling webhooks.

Required environment variables:

- `STRIPE_SECRET_KEY` — your Stripe secret API key (test or live)
- `STRIPE_WEBHOOK_SECRET` — webhook signing secret for verifying webhooks
- `JWT_SECRET` — JWT secret used by the API

Local testing:

1. Add `.env` containing the above keys (use test keys during development).
2. Run the income service: `cd austin-empire/income && npm install && node api/index.js`
3. Create a checkout session (POST to `/stripe/create-checkout-session`) with JSON payload describing price and metadata.

Webhooks:
- Stripe will POST to `/stripe/webhook`. The handler verifies the signature and currently triggers a business-plan generation when `checkout.session.completed` is received.

Payouts:
- Stripe pays out to the bank account configured in your Stripe dashboard. For marketplace scenarios, consider using Stripe Connect.
EOF

cat > austin-empire/docs/deployment.md <<'EOF'
# Deployment

This repo includes a Dockerfile for the income service at `income/docker/Dockerfile`.

Recommended hosts:
- Render (easy Docker deploys, can set secrets in the dashboard)
- Fly.io (support for Docker images and global edge)
- AWS / ECS / DigitalOcean App Platform

Example Render service (render.yaml)

```
services:
  - type: web
    name: income
    env: docker
    dockerfilePath: income/docker/Dockerfile
    plan: starter
    envVars:
      - key: STRIPE_SECRET_KEY
        sync: false
      - key: STRIPE_WEBHOOK_SECRET
        sync: false
      - key: JWT_SECRET
        sync: false
```

Set the environment variables in the host's secret UI and configure Stripe webhooks to point to `https://<your-host>/stripe/webhook`.
EOF

cat > austin-empire/.github/workflows/build.yml <<'EOF'
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
        run: npm ci

      - name: Run lint
        run: npm run lint --if-present

      - name: Run tests
        run: npm test --if-present

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main' && secrets.RENDER_API_KEY != ''

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Render (Docker)
        env:
          RENDER_API_KEY: ${{ secrets.RENDER_API_KEY }}
        run: |
          echo "Render deploy isn't automated here; set up a service in Render and deploy via their dashboard or use their API with RENDER_API_KEY."
EOF

# Add placeholder assets
cat > assets/logo/logo.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="60" viewBox="0 0 240 60">
  <rect width="240" height="60" fill="#1f2937" rx="6"/>
  <text x="20" y="38" font-family="sans-serif" font-size="28" fill="#fff">Austin Empire</text>
</svg>
EOF

cat > assets/avatar/avatar.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <circle cx="64" cy="42" r="28" fill="#4f46e5" />
  <rect x="16" y="80" width="96" height="28" rx="6" fill="#a78bfa" />
</svg>
EOF

cat > assets/ui/styles.css <<'EOF'
:root {
  --color-bg: #0f172a;
  --color-fg: #e6eef8;
  --color-accent: #7c3aed;
}

html, body {
  background: var(--color-bg);
  color: var(--color-fg);
  font-family: Inter, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial;
}

.container { max-width: 980px; margin: 0 auto; padding: 24px; }
EOF

# Add basic scripts
cat > scripts/append-log.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

MSG="$*"
if [ -z "$MSG" ]; then
  echo "Usage: $0 \"message\""
  exit 1
fi

author="$(git config user.name || echo unknown)"
now="$(date --utc +"%Y-%m-%dT%H:%M:%SZ")"

echo "- $now: $MSG (by $author)" >> "$(dirname "$0")/../austin-empire/docs/build-log.md"

echo "Appended to austin-empire/docs/build-log.md"
EOF
chmod +x scripts/append-log.sh || true

# Commit
git add -A austin-empire assets scripts || true
git commit -m "Add Austin Empire scaffold and income service; tests + CI" || true

# Try to push
if git push -u origin "$BRANCH"; then
  echo "Branch pushed to origin/$BRANCH"
  if command -v gh >/dev/null 2>&1; then
    echo "Creating PR using gh..."
    gh pr create --fill --title "Add Austin Empire scaffold" --body "Adds scaffold, income service, tests, and CI updates." || echo "gh pr create failed; you can run the command locally"
  else
    echo "gh CLI not found; run: gh pr create --fill --title 'Add Austin Empire scaffold' --body 'Adds scaffold, income service, tests, and CI updates.'"
  fi
else
  echo "Push failed — please authenticate (gh auth login or add a PAT) and run: git push -u origin $BRANCH"
fi

set +x

echo "Done. If push failed, fix auth locally and re-run the last push + gh command as shown above."
