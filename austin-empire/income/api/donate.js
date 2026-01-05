const express = require('express');
const router = express.Router();

const ETHEREUM_ADDRESS = process.env.DONATION_WALLET || '0x0cf748F1e2bD0db313463e2D5AFF8F28AC833c3b';

router.get('/', (req, res) => {
  // Simple HTML response with wallet and Etherscan link
  const etherscan = `https://etherscan.io/address/${ETHEREUM_ADDRESS}`;
  res.set('Content-Type', 'text/html');
  res.send(`
    <html>
      <head><meta charset="utf-8"><title>Donate</title></head>
      <body style="font-family: system-ui, Arial; padding: 24px;">
        <h1>Support the Austin Empire</h1>
        <p>Send ETH to <strong>${ETHEREUM_ADDRESS}</strong></p>
        <p><a href="${etherscan}" target="_blank" rel="noopener">View on Etherscan</a></p>
        <p>Note: this address was provided by the repository owner; this project does not custody funds.</p>
      </body>
    </html>
  `);
});

module.exports = router;
