const assert = require('assert');
const donateRouter = require('../api/donate');

(async () => {
  assert.ok(donateRouter, 'donate router should be exported');
  console.log('✔ donate router loaded');
})();
