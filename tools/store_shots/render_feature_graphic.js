// Play Store özellik grafiğini (1024x500) feature_graphic.html'den PNG olarak üretir.
// Kullanım: node tools/store_shots/render_feature_graphic.js
const path = require('path');
const puppeteer = require(path.resolve(__dirname, '..', '..', 'icon_tool', 'node_modules', 'puppeteer'));

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  await page.setViewport({ width: 1024, height: 500, deviceScaleFactor: 1 });
  const url = 'file:///' + path.resolve(__dirname, 'feature_graphic.html').replace(/\\/g, '/');
  await page.goto(url, { waitUntil: 'networkidle0' });
  const out = path.resolve(__dirname, '..', '..', 'assets', 'feature_graphic_1024x500.png');
  await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 1024, height: 500 } });
  await browser.close();
  console.log('yazıldı:', out);
})();
