// Smoke test for the Godot web export: serves the build locally and loads it in
// headless Chrome twice, as a desktop browser (1280x720) and as an emulated phone
// (390x844 at 3x, touch, mobile). Each run fails on any failed request, page error,
// console error, missing engine boot log, a still-visible Godot status overlay, a
// missing canvas, a page whose touch/selection CSS is not applied, or a screenshot
// with nothing drawn. Then each run plays: taps "Open the shop", serves the first
// day-1 customer through real input (CDP touch events on the phone, the mouse on
// desktop): taps the recipe's ingredients and Brew, stirs real circles, holds and
// releases the pour, and requires the game's "[Shop] Served customer 1/N" log line.
// Usage: node tools/smoke_web.mjs [buildDir]   (default: build/web)
// Env:   SMOKE_BOOT_TIMEOUT_MS (default 30000), SMOKE_SETTLE_MS (default 3000),
//        SMOKE_STEP_TIMEOUT_MS (each step of the shop run, default 20000)
// Screenshots (next to buildDir): build/smoke-<run>.png (title) and
// build/smoke-<run>-{shop,stir,pour,served}.png, <run> = desktop | mobile.
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launchChrome, serveBuild } from './web_util.mjs';

const repoRoot = resolve(fileURLToPath(import.meta.url), '..', '..');
const buildDir = resolve(process.argv[2] ?? join(repoRoot, 'build', 'web'));
const bootTimeoutMs = Number(process.env.SMOKE_BOOT_TIMEOUT_MS ?? 30000);
const settleMs = Number(process.env.SMOKE_SETTLE_MS ?? 3000);

const RUNS = [
  { name: 'desktop', context: { viewport: { width: 1280, height: 720 } } },
  {
    name: 'mobile',
    context: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true },
  },
];

// Set by html/head_include in export_presets.cfg so pull-to-refresh, double-tap zoom,
// text selection and long-press menus never fire.
const TOUCH_CSS = { touchAction: 'none', overscrollBehavior: 'none', userSelect: 'none' };

// Game layout the shop run needs (base units, 270x480 base viewport, aspect expand).
const BASE = { width: 270, height: 480 };
// scenes/title.tscn OpenShopButton: centred, anchor_top 0.72 of the column.
const TITLE_BUTTON_ANCHOR_Y = 0.72;
// Stations are 270x288 at stage y 192 (scenes/stations/*.tscn); the stir centre and
// ring are Stir.CENTRE (135, 121) and Stir.RING_RADIUS 52, so the stage point is (135, 313).
const STIR_CENTRE = { x: 135, y: 313 };
const STIR_RADIUS = 52;
// Stir.DEFAULT_TEMPO rotations per second; a little over 3 rotations (Stir.ROTATIONS) finishes it.
const STIR_TEMPO = 0.8;
const STIR_TURNS = 3.4;
const STIR_STEPS_PER_TURN = 24;
// A thumb holding low in the pour station; Pour fills the bottle in 1.5 s, the line is at 0.75.
const POUR_POINT = { x: 135, y: 440 };
const POUR_HOLD_MS = 1100;
// The first day-1 customer asks for hearthglow_tonic (data/days.json): ember_pepper + sunpetal.
const FIRST_RECIPE = ['ember_pepper', 'sunpetal'];
const STEP_TIMEOUT_MS = Number(process.env.SMOKE_STEP_TIMEOUT_MS ?? 20000);

// Waits until a console line matches `pattern` (a RegExp) and returns its match.
async function waitForLog(page, logs, pattern, what) {
  const deadline = Date.now() + STEP_TIMEOUT_MS;
  while (Date.now() < deadline) {
    for (let i = logs.length - 1; i >= 0; i--) {
      const match = logs[i].match(pattern);
      if (match) return match;
    }
    await page.waitForTimeout(50);
  }
  throw new Error(`timed out after ${STEP_TIMEOUT_MS} ms waiting for ${what} (${pattern})`);
}

// Pointer input for one run: real touches (CDP touch events) on the phone, the mouse on desktop.
async function pointerFor(page, context, run) {
  if (!run.context.hasTouch) {
    return {
      tap: (p) => page.mouse.click(p.x, p.y),
      down: async (p) => { await page.mouse.move(p.x, p.y); await page.mouse.down(); },
      move: (p) => page.mouse.move(p.x, p.y),
      up: () => page.mouse.up(),
    };
  }
  const cdp = await context.newCDPSession(page);
  const touch = (type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points });
  return {
    tap: (p) => page.touchscreen.tap(p.x, p.y),
    down: (p) => touch('touchStart', [{ x: p.x, y: p.y }]),
    move: (p) => touch('touchMove', [{ x: p.x, y: p.y }]),
    up: () => touch('touchEnd', []),
  };
}

// Base-unit point -> page point. Godot fits the 270x480 base by the smaller ratio and
// expands the other axis; the web reports no safe-area insets, so the column is the
// visible height, centred horizontally.
function mapper(box) {
  const scale = Math.min(box.width / BASE.width, box.height / BASE.height);
  const visible = { width: box.width / scale, height: box.height / scale };
  return {
    visible,
    page: (x, y) => ({ x: box.x + x * scale, y: box.y + y * scale }),
  };
}

// Title -> shop through the real pointer, then serves the first customer: taps the
// recipe's ingredients and Brew, stirs real circles, holds and releases the pour,
// and waits for the game to log the customer as served.
async function serveFirstCustomer(page, context, run, logs) {
  const box = await page.locator('canvas').boundingBox();
  const map = mapper(box);
  const pointer = await pointerFor(page, context, run);
  const shot = async (tag) => {
    const path = join(buildDir, '..', `smoke-${run.name}-${tag}.png`);
    await page.screenshot({ path });
    console.log(`[${run.name}] screenshot: ${path}`);
  };
  await pointer.tap(map.page(map.visible.width / 2, map.visible.height * TITLE_BUTTON_ANCHOR_Y));
  await waitForLog(page, logs, /^\[Game\] goto TITLE -> SHOP/, 'the shop to open');
  const stageMatch = await waitForLog(page, logs, /^\[Shop\] Stage at \(([\d.-]+), ([\d.-]+)\)/, 'the stage layout');
  const stage = { x: Number(stageMatch[1]), y: Number(stageMatch[2]) };
  const shelfLine = (await waitForLog(page, logs, /^\[Shop\] Shelf \(stage coordinates\): (.*)$/, 'the shelf layout'))[1];
  const spot = (name) => {
    const m = shelfLine.match(new RegExp(`${name}@\\(([\\d.-]+), ([\\d.-]+)\\)`));
    if (!m) throw new Error(`'${name}' missing from the shelf layout: ${shelfLine}`);
    return map.page(stage.x + Number(m[1]), stage.y + Number(m[2]));
  };
  await waitForLog(page, logs, /^\[Shop\] Customer 1 is waiting/, 'the first customer to ask');
  await shot('shop');
  for (const id of FIRST_RECIPE) {
    await pointer.tap(spot(id));
    await waitForLog(page, logs, new RegExp(`^\\[Shop\\] Added ${id} to the pot`), `${id} in the pot`);
  }
  await pointer.tap(spot('brew'));
  await waitForLog(page, logs, /^\[Station\] Stir begin/, 'the stir station');
  const centre = { x: stage.x + STIR_CENTRE.x, y: stage.y + STIR_CENTRE.y };
  const onRing = (angle) => map.page(centre.x + Math.cos(angle) * STIR_RADIUS, centre.y + Math.sin(angle) * STIR_RADIUS);
  const steps = Math.ceil(STIR_TURNS * STIR_STEPS_PER_TURN);
  const stepMs = 1000 / (STIR_TEMPO * STIR_STEPS_PER_TURN);
  await pointer.down(onRing(0));
  for (let i = 1; i <= steps; i++) {
    await pointer.move(onRing((i / STIR_STEPS_PER_TURN) * 2 * Math.PI));
    await page.waitForTimeout(stepMs);
    if (i === STIR_STEPS_PER_TURN) await shot('stir');
  }
  await pointer.up();
  await waitForLog(page, logs, /^\[Station\] Stir finished/, 'the stir to finish');
  await waitForLog(page, logs, /^\[Station\] Pour begin/, 'the pour station');
  const pour = map.page(stage.x + POUR_POINT.x, stage.y + POUR_POINT.y);
  await pointer.down(pour);
  await page.waitForTimeout(POUR_HOLD_MS);
  await shot('pour');
  await pointer.up();
  await waitForLog(page, logs, /^\[Station\] Pour finished/, 'the pour to finish');
  const served = await waitForLog(page, logs, /^\[Shop\] Served customer 1\/\d+ .*$/, 'the first customer to be served');
  console.log(`[${run.name}] ${served[0]}`);
  await page.waitForTimeout(600);
  await shot('served');
}

async function smoke(browser, url, run) {
  const failures = [];
  const logs = [];
  const context = await browser.newContext(run.context);
  try {
    const page = await context.newPage();
    page.on('pageerror', (e) => failures.push(`page error: ${e.message}`));
    page.on('requestfailed', (r) => failures.push(`request failed: ${r.url()} ${r.failure()?.errorText}`));
    page.on('response', (r) => { if (r.status() >= 400) failures.push(`HTTP ${r.status()}: ${r.url()}`); });
    page.on('console', (m) => {
      // SwiftShader emits GPU performance warnings; only real errors fail the test.
      if (m.type() === 'error') failures.push(`console error: ${m.text()}`);
      logs.push(m.text());
    });
    // Settled to a value up front so it can never become an unhandled rejection if goto throws.
    const booted = page.waitForEvent('console', {
      predicate: (m) => m.text().startsWith('Godot Engine v'),
      timeout: bootTimeoutMs,
    }).then(() => null, (err) => err);
    await page.goto(url, { timeout: bootTimeoutMs });
    const bootError = await booted;
    if (bootError !== null) throw new Error(`engine did not boot: ${bootError.message.split('\n')[0]}`);
    await page.waitForTimeout(settleMs);
    const overlayVisible = await page.evaluate(() => {
      const status = document.getElementById('status');
      return status !== null && getComputedStyle(status).display !== 'none' && getComputedStyle(status).visibility !== 'hidden';
    });
    if (overlayVisible) failures.push('Godot status overlay still visible (engine failed to start)');
    if ((await page.locator('canvas').count()) === 0) failures.push('no canvas element');
    const css = await page.evaluate((expected) => {
      const wrong = [];
      for (const selector of ['html', 'body', 'canvas']) {
        const style = getComputedStyle(document.querySelector(selector));
        for (const [prop, value] of Object.entries(expected)) {
          if (style[prop] !== value) wrong.push(`${selector} ${prop}=${style[prop]}`);
        }
      }
      return wrong;
    }, TOUCH_CSS);
    for (const w of css) failures.push(`touch CSS not applied: ${w}`);
    const screenshotPath = join(buildDir, '..', `smoke-${run.name}.png`);
    const png = await page.screenshot({ path: screenshotPath });
    console.log(`[${run.name}] screenshot: ${screenshotPath}`);
    // A booted engine that draws nothing leaves one flat colour; count distinct colours in the screenshot.
    const distinctColors = await page.evaluate(async (b64) => {
      const img = new Image();
      img.src = `data:image/png;base64,${b64}`;
      await img.decode();
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      const colors = new Set();
      for (let i = 0; i < data.length && colors.size < 16; i += 4) {
        colors.add((data[i] << 16) | (data[i + 1] << 8) | data[i + 2]);
      }
      return colors.size;
    }, png.toString('base64'));
    if (distinctColors < 2) failures.push('screenshot is a single flat colour (nothing rendered)');
    if (failures.length === 0) await serveFirstCustomer(page, context, run, logs);
  } catch (err) {
    failures.push(`smoke test aborted: ${err.message}`);
  } finally {
    await context.close();
  }
  return failures.map((f) => `[${run.name}] ${f}`);
}

const failures = [];
let browser;
let server;
try {
  const served = await serveBuild(buildDir);
  server = served.server;
  browser = await launchChrome();
  for (const run of RUNS) failures.push(...await smoke(browser, served.url, run));
} catch (err) {
  failures.push(`smoke test aborted: ${err.message}`);
} finally {
  await browser?.close();
  server?.close();
}

if (failures.length > 0) {
  for (const f of failures) console.error(`FAIL ${f}`);
  process.exit(1);
}
console.log(`PASS ${buildDir} (${RUNS.map((r) => r.name).join(', ')})`);
