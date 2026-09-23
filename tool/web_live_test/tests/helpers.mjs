import { test, expect } from '@playwright/test';

// A protected Vercel preview needs the automation bypass. It is exchanged for
// a cookie once per context rather than sent as a header on every request:
// a custom header would also go to gstatic, turning CanvasKit's cross-origin
// loads into CORS preflights that fail.
if (process.env.VERCEL_BYPASS) {
  test.beforeEach(async ({ context, baseURL }) => {
    const response = await context.request.get(baseURL, {
      headers: {
        'x-vercel-protection-bypass': process.env.VERCEL_BYPASS,
        'x-vercel-set-bypass-cookie': 'true',
      },
    });
    expect(response.ok(), 'the bypass secret was accepted').toBe(true);
  });
}

/** A deferred part: dart2js `main.dart.js_N.part.js`, or any same-origin
 * wasm module other than the main one (dart2wasm writes extra modules). */
export function isDeferredPart(url) {
  const { pathname } = new URL(url);
  return /main\.dart\.js_\d+\.part\.js$/.test(pathname) ||
    (pathname.endsWith('.wasm') && !pathname.endsWith('/main.dart.wasm'));
}

// A race in Flutter's CanvasKit startup (engine code, not this app) can throw
// "Null check operator used on a null value" when the browser has no WebGL
// and falls back to CPU-only rendering under heavy CPU load. A bisect on CI
// reproduced it in the build from before any of this app's web changes (9 of
// 80 loads with the browsers pinned to one core), so it is tolerated -- but
// only when the page announced that fallback. Any other error still fails.
const knownEngineRace = /^Null check operator used on a null value/;

/** Records every response and failure the page sees, plus JS errors. */
export function watch(page) {
  const log = { responses: [], failures: [], errors: [], cpuOnly: false };
  page.on('response', async (response) => {
    const url = response.url();
    let bytes = Number(response.headers()['content-length'] ?? NaN);
    if (Number.isNaN(bytes)) {
      bytes = await response.body().then((b) => b.length, () => 0);
    }
    log.responses.push({ url, status: response.status(), bytes });
  });
  page.on('requestfailed', (request) => {
    log.failures.push(`${request.url()} ${request.failure()?.errorText ?? ''}`);
  });
  page.on('pageerror', (error) => {
    const text = String(error.message ?? error);
    if (log.cpuOnly && knownEngineRace.test(text)) {
      log.toleratedEngineRace = (log.toleratedEngineRace ?? 0) + 1;
      return;
    }
    log.errors.push(text);
  });
  page.on('console', (msg) => {
    if (/Falling back to CPU-only rendering/.test(msg.text())) log.cpuOnly = true;
    if (msg.type() === 'error') log.errors.push(msg.text());
  });
  return log;
}

export const sameOrigin = (page, log) =>
  log.responses.filter((r) => new URL(r.url).origin === new URL(page.url()).origin);

/** Loads the app and waits for Flutter's first frame (the splash is gone). */
export async function openApp(page) {
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('#splash')).toHaveCount(0);
  await expect(page.locator('flutter-view')).toHaveCount(1);
}

/** Turns on Flutter's semantics tree so widgets can be found by role/label. */
export async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await expect(placeholder).toHaveCount(1);
  await placeholder.evaluate((el) => el.click());
  await expect(page.locator('flt-semantics').first()).toBeAttached();
}

/** From a fresh load: home → game menu. */
export async function openGameMenu(page) {
  await openApp(page);
  await enableSemantics(page);
  const start = page.getByRole('button', { name: /Start Your Math Adventure/i });
  await start.click();
  await expect(page.getByText(/Wormhole Activator/).first()).toBeVisible();
}
