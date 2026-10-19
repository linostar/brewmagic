// Smoke test for the Godot web export: serves the build locally and loads it in
// headless Chrome three times: as a desktop browser (1280x720, mouse), as an emulated
// phone (390x844 at 3x, touch, mobile) and as a keyboard-only desktop player. Each run
// fails on any failed request, page error, console error, missing engine boot log, a
// still-visible Godot status overlay, a missing canvas, a page whose touch/selection
// CSS is not applied, or a screenshot with nothing drawn (taken once the splash has
// gone to the title by itself: "[Game] Arrived at TITLE"). Then each run plays and
// serves the first day-1 customer, requiring the game's "[Shop] Served customer 1/N"
// log line. Pointer runs (CDP touch events on the phone, the mouse on desktop) tap
// "Open the shop" on the title and on the morning screen, the recipe's ingredients and Brew, stir real circles at the target
// tempo and hold the pour to the line; the game's logs must show that each gesture reached
// the game and was recognised (see checkStir/checkPour), so a broken input path fails
// however slow the renderer is. The keyboard run uses only
// Tab/Shift+Tab/arrows/Enter: it switches Assist on in the pause panel, and each
// station must finish with exactly Station.ASSIST_QUALITY.
// Usage: node tools/smoke_web.mjs [buildDir]   (default: build/web)
// Env:   SMOKE_BOOT_TIMEOUT_MS (default 30000), SMOKE_SETTLE_MS (default 3000),
//        SMOKE_STEP_TIMEOUT_MS (each step of the shop run, default 20000)
// Screenshots (next to buildDir): build/smoke-<run>.png (title) and
// build/smoke-<run>-{morning,shop,stir,pour,served}.png, <run> = desktop | mobile | keyboard.
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
  { name: 'keyboard', keyboard: true, context: { viewport: { width: 1280, height: 720 } } },
];

// Set by html/head_include in export_presets.cfg so pull-to-refresh, double-tap zoom,
// text selection and long-press menus never fire.
const TOUCH_CSS = { touchAction: 'none', overscrollBehavior: 'none', userSelect: 'none' };

// Game layout the shop run needs (base units, 270x480 base viewport, aspect expand).
const BASE = { width: 270, height: 480 };
// scenes/title.tscn OpenShopButton: centred, anchor_top 0.72 of the column.
const TITLE_BUTTON_ANCHOR_Y = 0.72;
// scenes/morning.tscn OpenShopButton: centred, anchor_top 0.72 of the column.
const MORNING_BUTTON_ANCHOR_Y = 0.72;
// Stations are 270x288 at stage y 192 (scenes/stations/*.tscn); the stir centre and
// ring are Stir.CENTRE (135, 121) and Stir.RING_RADIUS 52, so the stage point is (135, 313).
const STIR_CENTRE = { x: 135, y: 313 };
const STIR_RADIUS = 52;
// Stir.DEFAULT_TEMPO rotations per second; a little over 3 rotations (Stir.ROTATIONS) finishes it.
const STIR_TEMPO = 0.8;
const STIR_TURNS = 3.4;
const STIR_STEPS_PER_TURN = 24;
// Largest angle between two stir samples. Each move waits for a rendered frame; on a
// slow frame (the 3x phone canvas in CI renders at a few fps) the wall-clock angle can
// jump past PI, which the game rightly reads as a turn backwards. Capping the step keeps
// every circle recognisable; the stir then lags the wall clock (accuracy is not asserted).
const STIR_MAX_STEP = Math.PI / 4;
// A thumb holding low in the pour station; Pour fills the bottle in Pour.FILL_TIME seconds,
// so holding line x FILL_TIME releases on the line (the snapped line is logged at begin).
const POUR_POINT = { x: 135, y: 440 };
const POUR_FILL_MS = 1500;
// The pointer runs prove the input path, not scoring accuracy. The scripted gestures are
// timed by the wall clock, while the stations integrate game time once per rendered frame;
// headless SwiftShader renders the 3x phone canvas (1170x2532) at a few frames per second
// (frames of 50-70 ms locally, over 300 ms on a CI runner), so game time does not keep pace
// with the wall clock and no accuracy bound on a timed gesture is deterministic. The checks
// therefore require recognition:
//   stir: exactly Stir.ROTATIONS (3) rotations logged, i.e. the drag moves reached the game
//         and were recognised as circles (lost moves log none and time out);
//   pour: a logged release with 0 < fill < 1 (fill only grows while the press is held), i.e.
//         both the touch start and the touch end reached the game (a lost release only ends at overflow, 1.25).
// Accuracy (tempo, line, qualities) is printed for information; exact scoring is covered by
// the deterministic headless station tests (fixed fps) in tools/test_gameplay.gd.
const STIR_ROTATIONS = 3;
// Station.ASSIST_QUALITY: an Assist press always finishes a station with exactly this.
const ASSIST_QUALITY = 0.6;
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

// The quality a station logged when it finished ("[Station] <name> finished, quality q").
async function stationQuality(page, logs, name) {
  const match = await waitForLog(page, logs, new RegExp(`^\\[Station\\] ${name} finished, quality ([\\d.]+)`), `the ${name.toLowerCase()} to finish`);
  return Number(match[1]);
}

// Prints the run's station logs and the served line; returns failures for qualities out of range.
function checkQualities(run, logs, qualities, served, accept, expected) {
  for (const line of logs.filter((l) => /^\[(Stir|Pour|Station)\]/.test(l))) console.log(`[${run.name}] ${line}`);
  console.log(`[${run.name}] ${served}`);
  return Object.entries(qualities)
    .filter(([, quality]) => !accept(quality))
    .map(([station, quality]) => `${station} quality ${quality.toFixed(3)}, expected ${expected}`);
}

// Keyboard only, as a player without a pointer: Enter on the focused "Open the shop" of the
// title, then Enter on the focused "Open the shop" of the morning,
// Shift+Tab from the first shelf item (focused when the customer asks) wraps to the pause
// button, Enter pauses, Down + Enter switches Assist on, Up + Enter resumes (focus returns
// to the pause button), Tab wraps to the first shelf item and Enter adds ember_pepper, Right Right + Enter adds sunpetal,
// Down (shelf item -> Brew) + Enter brews, and Enter presses each station's focused Assist button.
async function serveFirstCustomerByKeyboard(page, run, logs, shot) {
  const key = (name) => page.keyboard.press(name);
  await key('Enter');
  await waitForLog(page, logs, /^\[Game\] Arrived at MORNING/, 'the morning of day 1 (Enter on "Open the shop")');
  await shot('morning');
  await key('Enter');
  await waitForLog(page, logs, /^\[Game\] goto MORNING -> SHOP/, 'the shop to open (Enter on the morning\'s "Open the shop")');
  await waitForLog(page, logs, /^\[Shop\] Customer 1 is waiting/, 'the first customer to ask');
  await shot('shop');
  await key('Shift+Tab');
  await key('Enter');
  await waitForLog(page, logs, /^\[Shop\] Paused/, 'the pause panel (Shift+Tab to the pause button, Enter)');
  await key('ArrowDown');
  await key('Enter');
  await waitForLog(page, logs, /^\[Shop\] Assist mode on/, 'Assist on (Down to the Assist toggle, Enter)');
  await key('ArrowUp');
  await key('Enter');
  await waitForLog(page, logs, /^\[Shop\] Resumed/, 'the shop to resume (Up to Resume, Enter)');
  await key('Tab');
  await key('Enter');
  await waitForLog(page, logs, /^\[Shop\] Added ember_pepper to the pot/, 'ember_pepper in the pot (Tab to the first shelf item, Enter)');
  await key('ArrowRight');
  await key('ArrowRight');
  await key('Enter');
  await waitForLog(page, logs, /^\[Shop\] Added sunpetal to the pot/, 'sunpetal in the pot (Right Right, Enter)');
  await key('ArrowDown');
  await key('Enter');
  await waitForLog(page, logs, /^\[Station\] Stir begin .*\(assist true/, 'the stir station in Assist mode (Down to Brew, Enter)');
  await shot('stir');
  await key('Enter');
  const stir = await stationQuality(page, logs, 'Stir');
  await waitForLog(page, logs, /^\[Station\] Pour begin .*\(assist true/, 'the pour station in Assist mode');
  await key('Enter');
  const pour = await stationQuality(page, logs, 'Pour');
  await shot('pour');
  const served = await waitForLog(page, logs, /^\[Shop\] Served customer 1\/\d+ .*$/, 'the first customer to be served');
  return checkQualities(run, logs, { stir, pour }, served[0], (q) => q === ASSIST_QUALITY, `exactly ${ASSIST_QUALITY} (Assist)`);
}

// Title -> shop through the real pointer, then serves the first customer: taps the
// recipe's ingredients and Brew, stirs real circles, holds and releases the pour,
// and waits for the game to log the customer as served. Returns quality failures.
async function serveFirstCustomer(page, context, run, logs) {
  const box = await page.locator('canvas').boundingBox();
  const map = mapper(box);
  const pointer = await pointerFor(page, context, run);
  const shot = async (tag) => {
    const path = join(buildDir, '..', `smoke-${run.name}-${tag}.png`);
    await page.screenshot({ path });
    console.log(`[${run.name}] screenshot: ${path}`);
  };
  if (run.keyboard) {
    const failures = await serveFirstCustomerByKeyboard(page, run, logs, shot);
    await page.waitForTimeout(600);
    await shot('served');
    return failures;
  }
  await pointer.tap(map.page(map.visible.width / 2, map.visible.height * TITLE_BUTTON_ANCHOR_Y));
  await waitForLog(page, logs, /^\[Game\] Arrived at MORNING/, 'the morning of day 1 (tap on "Open the shop")');
  await shot('morning');
  await pointer.tap(map.page(map.visible.width / 2, map.visible.height * MORNING_BUTTON_ANCHOR_Y));
  await waitForLog(page, logs, /^\[Game\] goto MORNING -> SHOP/, 'the shop to open (tap on the morning\'s "Open the shop")');
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
  // Screenshots stall the page for a while, so they are only taken outside a gesture.
  await shot('stir');
  const centre = { x: stage.x + STIR_CENTRE.x, y: stage.y + STIR_CENTRE.y };
  const onRing = (angle) => map.page(centre.x + Math.cos(angle) * STIR_RADIUS, centre.y + Math.sin(angle) * STIR_RADIUS);
  // The angle follows the wall clock, so the tempo stays right however long each
  // input dispatch takes (CDP touch events wait for a rendered frame).
  const stepMs = 1000 / (STIR_TEMPO * STIR_STEPS_PER_TURN);
  const start = Date.now();
  await pointer.down(onRing(0));
  for (let angle = 0; angle < STIR_TURNS * 2 * Math.PI;) {
    const wait = stepMs - ((Date.now() - start) % stepMs);
    await page.waitForTimeout(wait);
    angle = Math.min(((Date.now() - start) / 1000) * STIR_TEMPO * 2 * Math.PI, angle + STIR_MAX_STEP);
    await pointer.move(onRing(angle));
  }
  await pointer.up();
  const stir = await stationQuality(page, logs, 'Stir');
  await waitForLog(page, logs, /^\[Station\] Pour begin/, 'the pour station');
  const line = Number((await waitForLog(page, logs, /^\[Pour\] \w+ bottle, .*line ([\d.]+)$/, 'the pour line'))[1]);
  const pour = map.page(stage.x + POUR_POINT.x, stage.y + POUR_POINT.y);
  // Timed from the press dispatch: press and release then wait for the same frame latency.
  const pressed = Date.now();
  await pointer.down(pour);
  await page.waitForTimeout(line * POUR_FILL_MS - (Date.now() - pressed));
  await pointer.up();
  const pourQuality = await stationQuality(page, logs, 'Pour');
  await shot('pour');
  const served = await waitForLog(page, logs, /^\[Shop\] Served customer 1\/\d+ .*$/, 'the first customer to be served');
  await page.waitForTimeout(600);
  await shot('served');
  checkQualities(run, logs, { stir, pour: pourQuality }, served[0], () => true, '');
  return [...checkStir(run, logs), ...checkPour(run, logs)];
}

// The drag must be recognised as exactly Stir.ROTATIONS circles (durations printed for information).
function checkStir(run, logs) {
  const durations = logs.map((l) => l.match(/^\[Stir\] rotation \d+: ([\d.]+)s/)).filter(Boolean).map((m) => Number(m[1]));
  console.log(`[${run.name}] stir: ${durations.length} rotations recognised (${durations.map((d) => d.toFixed(2)).join(', ')} s, target ${(1 / STIR_TEMPO).toFixed(2)} s)`);
  if (durations.length !== STIR_ROTATIONS) return [`stir recognised ${durations.length} rotations, expected ${STIR_ROTATIONS} (Stir.ROTATIONS)`];
  return [];
}

// The press and the release must both reach the game: the logged release has 0 < fill < 1
// (fill only grows while the press is held; a lost release only ends at overflow). The
// distance to the line is printed.
function checkPour(run, logs) {
  const match = logs.map((l) => l.match(/^\[Pour\] released at ([\d.]+), line ([\d.]+)/)).find(Boolean);
  if (!match) return ['pour logged no release'];
  const [released, line] = [Number(match[1]), Number(match[2])];
  console.log(`[${run.name}] pour: press and release recognised, released at ${released.toFixed(3)}, line ${line.toFixed(3)} (error ${Math.abs(released - line).toFixed(3)})`);
  if (released <= 0) return [`pour released at ${released.toFixed(3)}: no fill between press and release`];
  if (released >= 1) return [`pour released at ${released.toFixed(3)}, at or past the brim (the release was not seen)`];
  return [];
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
    // The game opens on the splash (1.5 s, the main scene), which goes to the title by itself.
    await waitForLog(page, logs, /^\[Game\] Arrived at TITLE/, 'the title after the splash');
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
    if (failures.length === 0) failures.push(...await serveFirstCustomer(page, context, run, logs));
  } catch (err) {
    failures.push(`smoke test aborted: ${err.message}`);
    // The game's last log lines show where the run got stuck.
    for (const line of logs.slice(-12)) failures.push(`  log: ${line}`);
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
