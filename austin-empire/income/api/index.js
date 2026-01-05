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

// Donation page (simple ETH address)
const donateRouter = require('./donate');
app.use('/donate', donateRouter);

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
