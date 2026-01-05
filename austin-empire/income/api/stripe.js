const express = require('express');
const router = express.Router();
let StripeLib;
try {
  StripeLib = require('stripe');
} catch (e) {
  StripeLib = null;
}
const { generateBusinessPlan } = require('./generators/business_plan');

const StripeCtor = StripeLib && (StripeLib.default || StripeLib);
const stripe = StripeCtor ? new StripeCtor(process.env.STRIPE_SECRET_KEY || '', { apiVersion: '2022-11-15' }) : null;

// Create a checkout session for a one-time business plan purchase
router.post('/create-checkout-session', async (req, res) => {
  const { price = 5000, currency = 'usd', success_url, cancel_url, metadata = {} } = req.body;
  try {
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
    if (webhookSecret) {
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
    // Optionally: use session.customer, session.metadata to generate & store PDFs
    try {
      // Example: generate a PDF and store/send it to customer (implementation placeholder)
      const vars = {
        company_name: session.metadata?.company_name || 'Customer Inc',
        target_audience: session.metadata?.target || 'General',
        monthly_revenue: session.metadata?.monthly_revenue || '$0',
        phase1_date: session.metadata?.phase1_date || 'TBD',
      };
      await generateBusinessPlan(vars);
      // In a real implementation you'd upload to storage and notify the customer
    } catch (e) {
      console.error('Failed to generate business plan from webhook', e);
    }
  }

  res.json({ received: true });
});

module.exports = router;
