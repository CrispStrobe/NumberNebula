import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { test, expect, openGameMenu, watch } from './helpers.mjs';

// Browser measurements, not a substitute for native device frame/battery tests.
// CI artifacts retain raw values; shared runners use generous startup gates.
test('startup, idle rendering and autosave overhead', async ({ page, browserName, baseURL, vercelProtection }, testInfo) => {
  const reducedMotion = process.env.PERF_REDUCE_MOTION === 'true';
  // Three navigations plus two sampling windows need more than a smoke test.
  // The separate cold-start budget below remains 30 seconds.
  test.setTimeout(180_000);
  // Measure this runner without Flutter before attributing slow RAF to the app.
  // A wall-clock timeout also completes when a background tab receives no RAF.
  await page.goto('about:blank');
  const browserBaseline = await page.evaluate(() => new Promise((resolve) => {
    const frames = [];
    let previous;
    let frameId;
    function frame(now) {
      if (previous !== undefined) frames.push(now - previous);
      previous = now;
      frameId = requestAnimationFrame(frame);
    }
    frameId = requestAnimationFrame(frame);
    setTimeout(() => {
      cancelAnimationFrame(frameId);
      frames.sort((a, b) => a - b);
      resolve({
        sampleMs: 1500,
        frameCount: frames.length,
        browserRafP95Ms: frames.length ? frames[Math.floor((frames.length - 1) * 0.95)] : null,
        browserRafMaxMs: frames.length ? frames.at(-1) : null,
        visibilityState: document.visibilityState,
        hardwareConcurrency: navigator.hardwareConcurrency,
      });
    }, 1500);
  }));
  await page.addInitScript(({ reduceMotion, appOrigin }) => {
    // Preview toolbars create sandboxed frames without storage access.
    // Instrument only the app document; app storage failures remain fatal.
    if (window !== window.top || location.origin !== appOrigin) return;
    window.__appPerf = { writes: [], longTasks: [], frames: [],
      longTasksSupported: typeof PerformanceObserver !== 'undefined' &&
        (PerformanceObserver.supportedEntryTypes ?? []).includes('longtask') };
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      const start = performance.now();
      const result = original.call(this, key, value);
      if (key.includes('puzzle_session')) window.__appPerf.writes.push({
        key, bytes: new TextEncoder().encode(value).length,
        durationMs: performance.now() - start, at: performance.now(),
      });
      return result;
    };
    try {
      new PerformanceObserver((list) => {
        for (const e of list.getEntries()) window.__appPerf.longTasks.push({
          start: e.startTime, durationMs: e.duration,
        });
      }).observe({ type: 'longtask', buffered: true });
    } catch { /* Firefox does not expose the Long Tasks API. */ }
    let previous;
    function frame(now) {
      if (previous !== undefined) window.__appPerf.frames.push({ at: now, durationMs: now - previous });
      previous = now;
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
    // Keep the measurement about gameplay rather than first-run practice.
    for (const key of ['magic_triangles', 'asteroid_math']) {
      localStorage.setItem(`flutter.onboarding_seen_${key}_all_games_guided_v1`, 'true');
      localStorage.setItem(`flutter.onboarding_seen_${key}`, 'true');
    }
    localStorage.setItem('flutter.reduce_motion', JSON.stringify(reduceMotion));
  }, { reduceMotion: reducedMotion, appOrigin: new URL(baseURL).origin });
  const log = watch(page);
  const start = Date.now();
  await openGameMenu(page);
  const coldReadyMs = Date.now() - start;
  // A sandboxed preview frame must not receive app storage/RAF instrumentation.
  // Keep this regression outside the timed gameplay sampling windows.
  await page.evaluate(() => {
    const frame = document.createElement('iframe');
    frame.id = 'instrumentation-sandbox-probe';
    frame.sandbox = 'allow-scripts';
    frame.srcdoc = '<body>instrumentation sandbox probe</body>';
    document.body.appendChild(frame);
  });
  const sandbox = await page.locator('#instrumentation-sandbox-probe').elementHandle();
  const sandboxFrame = await sandbox.contentFrame();
  await expect(sandboxFrame.locator('body')).toHaveText('instrumentation sandbox probe');
  expect(await sandboxFrame.evaluate(() => typeof window.__appPerf)).toBe('undefined');
  expect(await page.evaluate(() => typeof window.__appPerf)).toBe('object');
  await page.locator('#instrumentation-sandbox-probe').evaluate((frame) => frame.remove());
  const sampleMs = Number(process.env.PERF_SAMPLE_MS ?? 10000);
  await page.getByText(/Wormhole Activator/).first().click();
  await expect(page.getByRole('button', { name: /Practice/i }).first()).toBeVisible();
  // Give puzzle generation and the first batched checkpoint time to finish.
  await page.waitForTimeout(1500);
  const sampleStart = await page.evaluate(() => performance.now());
  await page.waitForTimeout(sampleMs);
  const metrics = await page.evaluate((from) => {
    const p = window.__appPerf;
    const frames = p.frames.filter((v) => v.at >= from).map((v) => v.durationMs).sort((a,b) => a-b);
    const tasks = p.longTasks.filter((v) => v.start >= from);
    return {
      idleSessionWrites: p.writes.filter((v) => v.at >= from),
      idleLongTasks: tasks,
      longTasksSupported: p.longTasksSupported,
      visibilityState: document.visibilityState,
      browserRafSamples: frames.length,
      browserRafP95Ms: frames.length ? frames[Math.floor((frames.length-1)*0.95)] : null,
      browserRafMaxMs: frames.length ? frames.at(-1) : null,
      resourceBytes: performance.getEntriesByType('resource').reduce((n,r) => n+r.transferSize,0),
      crossOriginIsolated: window.crossOriginIsolated,
      jsHeapBytes: performance.memory?.usedJSHeapSize ?? null,
    };
  }, sampleStart);
  // A moving game exercises checkpoint writes while physics keeps running.
  await openGameMenu(page);
  await page.getByText(/Asteroid Hunter/).first().click();
  await expect(page.getByRole('button', { name: /Practice/i }).first()).toBeVisible();
  await page.waitForTimeout(1500);
  const movingStart = await page.evaluate(() => performance.now());
  await page.waitForTimeout(sampleMs);
  const moving = await page.evaluate((from) => {
    const p = window.__appPerf;
    const frames = p.frames.filter((v) => v.at >= from).map((v) => v.durationMs).sort((a,b) => a-b);
    return {
      sessionWrites: p.writes.filter((v) => v.at >= from),
      longTasks: p.longTasks.filter((v) => v.start >= from),
      visibilityState: document.visibilityState,
      browserRafSamples: frames.length,
      browserRafP95Ms: frames.length ? frames[Math.floor((frames.length-1)*0.95)] : null,
    };
  }, movingStart);
  const warmStart = Date.now();
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#splash')).toHaveCount(0);
  const warmFrameMs = Date.now() - warmStart;
  const report = { browserName, browserBaseline, reducedMotion,
    previewToolbarSuppressed: vercelProtection, httpCacheDisabled: vercelProtection,
    cpuOnlyRendering: log.cpuOnly, site: page.url(), coldMenuReadyMs: coldReadyMs,
    warmFirstFrameMs: warmFrameMs, sampleMs, ...metrics, movingGame: moving,
    notes: ['RAF measures browser scheduling, not Flutter raster frame time.',
      'Resource transfer size may be zero for cache hits or cross-origin resources without Timing-Allow-Origin.',
      'No physical battery measurement is claimed.'], errors: log.errors };
  const output = testInfo.outputPath('browser-performance.json');
  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, JSON.stringify(report, null, 2));
  await testInfo.attach('browser-performance.json', {
    contentType: 'application/json', path: output,
  });
  expect(log.errors).toEqual([]);
  expect(metrics.idleSessionWrites.length, 'an idle puzzle must not serialize on every glow frame').toBeLessThanOrEqual(2);
  expect(moving.sessionWrites.length, 'moving games checkpoint rather than saving on every physics frame')
    .toBeLessThanOrEqual(Math.ceil(sampleMs / 5000) + 2);
  if (process.env.PERFORMANCE_GATES === 'true') {
    expect(coldReadyMs).toBeLessThan(Number(process.env.PERF_STARTUP_BUDGET_MS ?? 30000));
  }
});
