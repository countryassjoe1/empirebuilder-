const assert = require('assert');
const { generateBusinessPlan } = require('../api/generators/business_plan');

(async () => {
  const buf = await generateBusinessPlan({ company_name: 'TestCo', target_audience: 'Testers', monthly_revenue: '$0', phase1_date: '2026-01-01' });
  assert.ok(Buffer.isBuffer(buf), 'Expected a Buffer');
  console.log('✔ generateBusinessPlan returned a Buffer (size:', buf.length, ')');
})();
