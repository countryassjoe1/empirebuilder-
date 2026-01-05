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

Crypto donations (optional):
- You can accept crypto donations directly. The project owner provided an Ethereum address: `0x0cf748F1e2bD0db313463e2D5AFF8F28AC833c3b`.
- A simple donation page is available at `/donate` which links to the address on Etherscan.

Notes:
- This project does not custody funds — ensure you control the private key for the address you publish.
- For on‑chain payments, consider a processor (Coinbase Commerce, Ramp, or a custodial service) if you need fiat conversion and automated payouts.
