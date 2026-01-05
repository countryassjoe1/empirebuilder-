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
