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
