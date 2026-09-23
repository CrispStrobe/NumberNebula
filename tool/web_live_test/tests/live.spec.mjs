import { test, expect } from '@playwright/test';
import {
  enableSemantics, isDeferredPart, openApp, openGameMenu, sameOrigin, watch,
} from './helpers.mjs';

test.describe('first visit', () => {
  test('shows the splash at once, then the app, with no errors', async ({ page }) => {
    const log = watch(page);
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    // Painted from inline CSS before any script has loaded.
    await expect(page.locator('#splash')).toBeVisible({ timeout: 5_000 });
    await expect(page.locator('#splash')).toHaveCount(0);
    await expect(page.locator('flutter-view')).toHaveCount(1);
    await enableSemantics(page);
    await expect(page.getByRole('button', { name: /Start Your Math Adventure/i })).toBeVisible();

    expect(log.errors).toEqual([]);
    expect(log.failures).toEqual([]);
  });

  test('downloads no game code before a game is opened', async ({ page }, testInfo) => {
    const log = watch(page);
    await openApp(page);
    await enableSemantics(page);
    await expect(page.getByRole('button', { name: /Start Your Math Adventure/i })).toBeVisible();

    const own = sameOrigin(page, log);
    const main = own.filter((r) => /\/main\.dart\.(wasm|js)$/.test(new URL(r.url).pathname));
    expect(main.length, 'the main app module was loaded').toBeGreaterThan(0);
    expect(own.filter((r) => isDeferredPart(r.url)).map((r) => r.url)).toEqual([]);

    const total = log.responses.reduce((sum, r) => sum + r.bytes, 0);
    await testInfo.attach('first-visit-downloads.json', {
      contentType: 'application/json',
      body: JSON.stringify({
        totalBytes: total,
        files: log.responses.map((r) => ({ url: r.url, bytes: r.bytes })),
      }, null, 2),
    });
  });

  test('is cross-origin isolated, and every cross-origin file still loads', async ({ page }) => {
    const log = watch(page);
    const response = await page.goto('/', { waitUntil: 'domcontentloaded' });
    expect(response.headers()['cross-origin-opener-policy']).toBe('same-origin');
    expect(response.headers()['cross-origin-embedder-policy']).toBe('credentialless');
    await expect(page.locator('#splash')).toHaveCount(0);

    expect(await page.evaluate(() => window.crossOriginIsolated)).toBe(true);
    // CanvasKit / skwasm come from gstatic; COEP must not block them.
    const renderer = log.responses.filter((r) => /flutter-canvaskit\/.+\.wasm$/.test(r.url));
    expect(renderer.length).toBeGreaterThan(0);
    expect(renderer.every((r) => r.status === 200)).toBe(true);
    expect(log.failures).toEqual([]);
  });
});

test.describe('opening a game', () => {
  test('downloads that game and shows it', async ({ page }, testInfo) => {
    const log = watch(page);
    await openGameMenu(page);
    const before = log.responses.length;

    await page.getByText(/Wormhole Activator/).first().click();
    // The game is up once its first-run tutorial offers to be skipped.
    await expect(page.getByRole('button', { name: /^Skip$/ })).toBeVisible();

    const parts = log.responses.slice(before).filter((r) => isDeferredPart(r.url));
    await testInfo.attach('game-downloads.json', {
      contentType: 'application/json',
      body: JSON.stringify(parts, null, 2),
    });
    if (testInfo.project.name === 'firefox-js') {
      // dart2js always splits deferred libraries into parts.
      expect(parts.length, 'the game arrived as a deferred part').toBeGreaterThan(0);
    } else if (parts.length === 0) {
      testInfo.annotations.push({
        type: 'note',
        description: 'dart2wasm emitted no deferred modules; the game is inside main.dart.wasm',
      });
    }
    expect(log.errors).toEqual([]);
  });

  test('a failed download offers a retry that recovers', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'firefox-js',
      'needs deferred parts, which only the dart2js build is guaranteed to have');
    const log = watch(page);
    await openGameMenu(page);

    // Simulate losing the connection just as the child taps a game.
    await page.route(isDeferredPart, (route) => route.abort('internetdisconnected'));
    await page.getByText(/Wormhole Activator/).first().click();
    await expect(page.getByText(/Game didn.t load/)).toBeVisible();

    await page.unroute(isDeferredPart);
    await page.getByRole('button', { name: /Try Again/i }).click();
    await expect(page.getByText(/Game didn.t load/)).toHaveCount(0);
    await expect(page.getByRole('button', { name: /^Skip$/ })).toBeVisible();

    const unexpected = log.errors.filter((e) => !/part|deferred|load/i.test(e));
    expect(unexpected).toEqual([]);
  });
});
