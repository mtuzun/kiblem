const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  await page.setViewport({ width: 512, height: 512, deviceScaleFactor: 2 });
  const filePath = 'file:///' + path.resolve(__dirname, '..', 'icon_design.html').replace(/\\/g, '/');
  await page.goto(filePath, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: path.resolve(__dirname, '..', 'icon_preview.png'), clip: { x: 0, y: 0, width: 512, height: 512 } });
  await browser.close();
  console.log('done');
})();
