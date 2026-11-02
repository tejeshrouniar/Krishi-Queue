// Run after: npm install --prefix .test-tools --no-save playwright
// Install test browser with the Playwright CLI, chromium --only-shell.
'use strict';
const {chromium} = require('../.test-tools/node_modules/playwright');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(process.env.KRISHI_WEB_ROOT || 'build/web');
const mime = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf'};
const server = http.createServer(async (request, response) => {
  try {
    const relative = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = path.resolve(root, `.${relative === '/' ? '/index.html' : relative}`);
    if (!file.startsWith(`${root}${path.sep}`)) { response.writeHead(403).end(); return; }
    response.writeHead(200, {'Content-Type': mime[path.extname(file)] || 'application/octet-stream'});
    response.end(await fs.readFile(file));
  } catch { response.writeHead(404).end(); }
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({headless: true});
  try {
    await fs.mkdir('test-results', {recursive: true});
    if (process.env.KRISHI_ONLY_FULL !== '1') {
    const context = await browser.newContext({viewport: {width: 375, height: 812}});
    const page = await context.newPage();
    const errors = [];
    const downloads = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => downloads.push(request.url()));
    const cdp = await context.newCDPSession(page);
    await cdp.send('Network.enable');
    await cdp.send('Network.emulateNetworkConditions', {offline: false, latency: 800, downloadThroughput: 8000, uploadThroughput: 4000});
    await page.goto(base, {waitUntil: 'networkidle'});
    assert(!downloads.some(url => /flutter_bootstrap|main\.dart|canvaskit/.test(url)), 'Landing must not download Flutter automatically');
    await page.getByRole('link', {name: /Light version/}).click();
    await page.waitForFunction(() => !!navigator.serviceWorker.controller);
    await page.getByRole('button', {name: 'English', exact: true}).click();
    await page.getByLabel('Registered society / centre').fill('Test society');
    await page.getByLabel('Village / district (optional)').fill('Raipur');
    await page.getByLabel('Quantity (quintals; 1 quintal = 100 kg)', {exact: true}).fill('12.5');
    await page.getByLabel('Planned date (not a reservation)').fill('2026-11-20');
    await page.getByLabel('Documents requested by my society are ready').check();
    await page.getByRole('button', {name: 'Save in this browser'}).click();
    await page.getByText('Saved in this browser. No slot has been booked.').waitFor();
    await cdp.send('Network.emulateNetworkConditions', {offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0});
    await context.setOffline(true);
    await page.reload();
    assert.equal(await page.locator('#centre').inputValue(), 'Test society');
    assert.equal(await page.locator('#quantity').inputValue(), '12.5');
    assert.equal(await page.locator('[name=documents]').isChecked(), true);
    await page.getByLabel('Your question').fill('payment delayed');
    await page.getByRole('button', {name: 'Get help', exact: true}).click();
    assert((await page.locator('#answer').innerText()).includes('bank reference'));
    await page.screenshot({path: 'test-results/lite-mobile.png', fullPage: true});
    await page.setViewportSize({width: 320, height: 740});
    await page.addStyleTag({content: ':root { font-size: 34px; }'});
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'Light UI overflows at 320px / 2x text');
    page.once('dialog', dialog => dialog.accept());
    await page.getByRole('button', {name: 'Delete plan', exact: true}).click();
    await page.reload();
    assert.equal(await page.locator('#centre').inputValue(), '');
    assert.equal(errors.length, 0, errors.join('\n'));
    const bytes = (await Promise.all(['lite.html', 'lite.js', 'lite-sw.js', 'offline.css'].map(async file => (await fs.stat(path.join(root, file))).size))).reduce((sum, value) => sum + value, 0);
    assert(bytes < 50000, 'Light assets must remain under 50 KB uncompressed');
    console.log(`PASS: simulated 64 kbit/s download, offline reload, saved plan/checklist, local help, delete, 320px/2x layout; light assets ${bytes} bytes; no page errors.`);
    await context.close();
    }
    if (process.env.KRISHI_CHECK_FULL === '1') {
      const full = await browser.newContext({viewport: {width: 390, height: 844}});
      const app = await full.newPage();
      app.on('pageerror', error => console.log('Full-app error:', error.message));
      app.on('requestfailed', request => console.log('Full-app download failed:', new URL(request.url()).hostname, request.failure()?.errorText));
      await app.goto(`${base}/index.html?full=1`);
      await app.locator('flutter-view').waitFor({state: 'attached', timeout: 60000});
      await app.waitForTimeout(12000);
      await app.screenshot({path: 'test-results/full-app-mobile.png'});
      const semantics = app.locator('flt-semantics-placeholder');
      if (await semantics.count()) await semantics.evaluate(element => element.click());
      await app.getByRole('button', {name: 'बिना साइन इन किए आगे बढ़ें', exact: true}).click({timeout: 15000});
      await app.waitForTimeout(700);
      await app.screenshot({path: 'test-results/farmer-home-mobile.png'});
      await app.getByRole('button', {name: 'English', exact: true}).click();
      await app.mouse.wheel(0, 550);
      await app.waitForTimeout(400);
      await app.getByRole('button', {name: /My follow-ups/}).click();
      await app.getByRole('button', {name: 'Record a problem', exact: true}).waitFor();
      await app.screenshot({path: 'test-results/follow-up-notebook-mobile.png'});
      await full.setOffline(true);
      await app.getByRole('button', {name: 'Record a problem', exact: true}).click();
      await app.getByRole('textbox', {name: /Centre \/ office/}).click();
      await app.waitForTimeout(250);
      await app.keyboard.type('Offline test society', {delay: 10});
      await app.getByRole('textbox', {name: /What happened/}).click();
      await app.waitForTimeout(250);
      await app.keyboard.type('Asked for a payment update', {delay: 10});
      await app.waitForTimeout(250);
      await app.mouse.wheel(0, 1700);
      await app.waitForTimeout(400);
      await app.getByRole('button', {name: 'Save personal note', exact: true}).click();
      await app.waitForTimeout(800);
      await app.screenshot({path: 'test-results/follow-up-after-save.png'});
      await app.getByRole('button', {name: /Offline test society/}).waitFor();
      await app.screenshot({path: 'test-results/follow-up-saved-mobile.png'});
      console.log('PASS: full app entered as guest and saved a follow-up note while offline.');
      await app.getByRole('button', {name: 'Back', exact: true}).click();
      await app.mouse.wheel(0, -1800);
      await app.waitForTimeout(400);
      await app.getByRole('button', {name: 'Plan my visit', exact: true}).click();
      await app.getByRole('button', {name: 'Prepare a visit', exact: true}).click();
      await app.getByRole('textbox', {name: /Your registered society/}).click();
      await app.waitForTimeout(250);
      await app.keyboard.type('Offline visit society', {delay: 10});
      await app.getByRole('textbox', {name: /Quantity in quintals/}).click();
      await app.waitForTimeout(250);
      await app.keyboard.type('12.5', {delay: 10});
      await app.mouse.wheel(0, 1800);
      await app.waitForTimeout(400);
      await app.getByRole('button', {name: 'Save on this device', exact: true}).click();
      await app.getByRole('button', {name: /Offline visit society/}).waitFor();
      console.log('PASS: full app visit plan also saves offline after scrolling the focused quantity field.');
      console.log('Full Flutter app rendered; screenshot saved for visual inspection.');
      await full.close();
    }
  } finally { await browser.close(); server.close(); }
})().catch(error => { console.error(error); server.close(); process.exitCode = 1; });
