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
