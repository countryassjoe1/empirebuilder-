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
