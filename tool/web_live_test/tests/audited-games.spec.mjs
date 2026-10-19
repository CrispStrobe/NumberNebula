import { test, expect, openGameMenu, watch } from './helpers.mjs';

// Exercise the audited screens in both shipped
// engines. Widget tests provide the detailed input/restore/outcome contracts;
// these cases catch deferred-module, release-build and browser-only failures.
const games = [
  { title: 'Hull Plating', role: 'button', ready: /^Rotate/ },
  { title: 'Constellation Puzzles', role: 'button', ready: /^Unplaced puzzle piece/ },
  { title: 'Codebreaker', role: 'button', ready: /^Number \d+, drag to a slot/ },
  { title: 'Wormhole Activator', role: 'button', ready: /^Resonator \d+, drag to a triangle node/ },
  { title: 'Quantum Pyramid Builder', role: 'button', ready: /^Number brick \d+, drag to a slot/ },
  { title: 'Arithmetic Square', role: 'button', ready: /^Number \d+, drag to a cell/ },
  { title: 'Arithmancer Crosswords', role: 'button', ready: /^Number \d+, drag to a slot/ },
  { title: 'KenKen', role: 'button', ready: /^Number \d+, drag to a cell/ },
  { title: 'Alien Tribunal', role: 'button', ready: /^Submit Verdict$/ },
  { title: 'Star Forge', role: 'button', ready: /^Arm total:/ },
  { title: 'Orbital Towers', text: 'Orbital Towers' },
  { title: 'Hive Station', role: 'button', ready: /^Correct$/ },
  { title: 'Xenobiology Lab', role: 'button', ready: /^Submit Census$/ },
  { title: 'Chrono Repair', role: 'button', ready: /^Submit$/ },
];

for (const game of games) {
  test(`audited screen: ${game.title} loads its actual board`, async ({ page }) => {
    test.setTimeout(180_000);
    const log = watch(page);
    await openGameMenu(page);
    const escaped = game.title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const card = page.getByRole('button', { name: new RegExp(`^${escaped} `) }).first();
    for (let step = 0; step < 20 && await card.count() === 0; step++) {
      await page.mouse.move(900, 650);
      await page.mouse.wheel(0, 500);
      await page.waitForTimeout(150);
    }
    await expect(card).toBeVisible();
    await card.click();
    const skip = page.getByRole('button', { name: /^Skip$/ });
    await expect(skip).toBeVisible();
    // A game may have its own worked example after the shared introduction.
    for (let step = 0; step < 4 && await skip.isVisible(); step++) {
      // A closing tutorial can stay visible during its route transition.
      // Wait for this exact control to detach before looking for another one;
      // otherwise a second click can wait forever for an already-dismissed Skip.
      const clickedSkip = await skip.elementHandle();
      expect(clickedSkip).not.toBeNull();
      await skip.click({ timeout: 10_000 });
      await page.waitForFunction((element) => !element.isConnected,
        clickedSkip, { timeout: 10_000 });
      await clickedSkip.dispose();
      await page.waitForTimeout(250);
    }
    await expect(skip).toHaveCount(0);
    const board = game.role
      ? page.getByRole(game.role, { name: game.ready }).first()
      : page.getByText(game.text, { exact: true }).first();
    await expect(board).toBeVisible();
    expect(log.errors).toEqual([]);
    expect(log.failures).toEqual([]);
  });
}
