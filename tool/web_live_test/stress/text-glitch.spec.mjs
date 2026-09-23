// Repeatedly renders two pieces of text that were once seen corrupted on
// production in Chrome -- the Relic Assembly title ("Relic" drawn as "Blic")
// and Star Forge's second tutorial page (wrapped mid-word) -- and saves a
// crop of each. compare_crops.py then flags crops that differ from the rest.
import { test } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { openGame } from './play.mjs';

const dir = process.env.CROPS ?? 'crops';
mkdirSync(dir, { recursive: true });

for (let i = 0; i < 10; i++) {
  test(`relic title ${i}`, async ({ page }, info) => {
    await openGame(page, 'Relic Assembly');
    await page.screenshot({
      path: `${dir}/relic-${info.repeatEachIndex}-${i}.png`,
      clip: { x: 60, y: 10, width: 240, height: 40 },
    });
  });

  test(`star forge page 2 ${i}`, async ({ page }, info) => {
    await openGame(page, 'Star Forge');
    await page.getByRole('button', { name: /^Next$/ }).click();
    await page.waitForTimeout(1_200);
    await page.screenshot({
      path: `${dir}/forge-${info.repeatEachIndex}-${i}.png`,
      clip: { x: 470, y: 390, width: 340, height: 110 },
    });
  });
}
