import { test, expect, enableSemantics, openApp, openGameMenu, watch } from './helpers.mjs';

test('published package keeps its base path, version and engine assets', async ({ page, baseURL }, info) => {
  const log = watch(page);
  await openApp(page);
  const base = new URL(baseURL);
  expect(await page.evaluate(() => document.baseURI)).toBe(base.href);
  const response = await page.request.get(new URL('version.json', base).href);
  expect(response.ok()).toBe(true);
  const version = await response.json();
  expect(version.app_name).toBe('space_math_academy');
  if (process.env.EXPECTED_VERSION) expect(version.version).toBe(process.env.EXPECTED_VERSION);
  if (process.env.EXPECTED_BUILD) expect(version.build_number).toBe(process.env.EXPECTED_BUILD);
  if (process.env.PAGES_HOSTING === 'true') {
    expect(await page.evaluate(() => window.crossOriginIsolated)).toBe(false);
    const provenance = await page.request.get(new URL('pages-provenance.json', base).href);
    expect(provenance.ok()).toBe(true);
    expect((await provenance.json()).baseHref).toBe(base.pathname);
  }
  const modules = log.responses.filter(r => /\/main\.dart\.(wasm|js)$/.test(new URL(r.url).pathname));
  expect(modules.length).toBeGreaterThan(0);
  for (const module of modules) {
    expect(new URL(module.url).pathname.startsWith(base.pathname)).toBe(true);
    expect(module.status).toBe(200);
  }
  if (info.project.name === 'chromium-wasm') {
    expect(modules.some(r => r.url.endsWith('.wasm'))).toBe(true);
    expect(await page.evaluate(() => window._flutter_skwasmInstance?.skwasmSingleThreaded)).toBe(true);
  } else {
    expect(modules.some(r => r.url.endsWith('.js'))).toBe(true);
  }
  await info.attach('published-package.json', {
    contentType: 'application/json',
    body: JSON.stringify({ version, baseURL, modules,
      isolated: await page.evaluate(() => window.crossOriginIsolated) }, null, 2),
  });
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('flutter-view')).toHaveCount(1);
  await enableSemantics(page);
  await expect(page.getByRole('button', { name: /Start Your Math Adventure/i })).toBeVisible();
});

test('published practice lesson accepts an actual wrong and correct choice', async ({ page }) => {
  const log = watch(page);
  await openGameMenu(page);
  await page.getByText(/Wormhole Activator/).first().click();
  await expect(page.getByRole('button', { name: /^Skip$/ })).toBeVisible();
  await page.getByRole('button', { name: '4', exact: true }).click();
  // Feedback is a live region: Flutter web exposes the text and its
  // announcement, so match the first of the two.
  await expect(page.getByText('That choice does not fit the rule yet. Try another.').first()).toBeAttached();
  await page.getByRole('button', { name: '5', exact: true }).click();
  await expect(page.getByText(/The right side includes its corners/).first()).toBeAttached();
  await page.getByRole('button', { name: /^Got it$/ }).click();
  await expect(page.getByRole('button', { name: /^Got it$/ })).toHaveCount(0);
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
});
