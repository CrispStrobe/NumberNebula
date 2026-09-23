// Loads a plain `flutter create` counter app repeatedly and records uncaught
// page errors, to check whether the CanvasKit startup race reproduces
// outside this app. Only the first frame matters, so no navigation.
import { test, expect } from '@playwright/test';
import { appendFileSync } from 'node:fs';

const out = process.env.RACE_LOG ?? 'race.log';

for (let i = 0; i < 10; i++) {
  test(`counter load ${i}`, async ({ page }, info) => {
    const errors = [];
    let cpuOnly = false;
    page.on('pageerror', (e) => errors.push(`${e.message}\n${e.stack}`));
    page.on('console', (m) => { if (/CPU-only/.test(m.text())) cpuOnly = true; });
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await expect(page.locator('flutter-view')).toHaveCount(1);
    await page.waitForTimeout(4_000);
    appendFileSync(out, `${errors.length ? 'ERROR' : 'clean'} r${info.repeatEachIndex}-${i} cpuOnly=${cpuOnly}\n`);
    if (errors.length) appendFileSync(`${out}.stacks`, errors.join('\n====\n') + '\n\n');
  });
}
