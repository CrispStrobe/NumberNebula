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

/** Records every response and failure the page sees, plus JS errors. */
export function watch(page) {
  const log = { responses: [], failures: [], errors: [] };
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
  page.on('pageerror', (error) => log.errors.push(String(error)));
  page.on('console', (msg) => {
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
