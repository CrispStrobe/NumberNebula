// Repeats the fast path from a fresh load to the game menu and records any
// uncaught page error, with the step it landed after. Used to bisect an
// intermittent startup null-check seen in Firefox under CPU load.
import { test, expect } from '@playwright/test';
import { appendFileSync } from 'node:fs';
import { enableSemantics } from '../tests/helpers.mjs';

const out = process.env.RACE_LOG ?? 'race.log';

for (let i = 0; i < 10; i++) {
  test(`load ${i}`, async ({ page }, testInfo) => {
    const ev = [];
    const errors = [];
    const t0 = Date.now();
    const mark = (s) => ev.push(`${s}@${Date.now() - t0}`);
    page.on('pageerror', (e) => { mark('ERR'); errors.push(`${e.message}\n${e.stack}`); });
    await page.goto('/', { waitUntil: 'domcontentloaded' }); mark('dom');
    await expect(page.locator('flutter-view')).toHaveCount(1); mark('view');
    await enableSemantics(page); mark('sem');
    const start = page.getByRole('button', { name: /Start Your Math Adventure/i });
    await start.waitFor(); mark('home');
    await start.click();
    await expect(page.getByText(/Wormhole Activator/).first()).toBeVisible(); mark('menu');
    await page.waitForTimeout(1500);
    appendFileSync(out, `${errors.length ? 'ERROR' : 'clean'} r${testInfo.repeatEachIndex}-${i}: ${ev.join(' ')}\n`);
    if (errors.length) appendFileSync(out + '.stacks', errors.join('\n====\n') + '\n\n');
  });
}
