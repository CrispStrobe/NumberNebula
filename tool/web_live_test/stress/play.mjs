// Helpers for driving the real app like a player: unlock the debug menu,
// open any game (including the gated ones) from Mission Control, and read
// Flutter's semantics tree with positions.
import { expect } from '@playwright/test';
import { openApp, enableSemantics } from '../tests/helpers.mjs';

/** Every labelled semantics node with its on-screen centre. */
export async function nodes(page) {
  return page.locator('flt-semantics').evaluateAll((els) => els.map((e) => {
    const r = e.getBoundingClientRect();
    return {
      label: (e.getAttribute('aria-label') || e.textContent || '').trim(),
      role: e.getAttribute('role'),
      x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2),
      w: Math.round(r.width), h: Math.round(r.height),
    };
  }).filter((n) => n.label && n.w > 0 && n.w < 1200));
}

/** Fresh load → debug menu unlocked → Mission Control → the game titled [title]. */
export async function openGame(page, title) {
  await openApp(page);
  await enableSemantics(page);
  const start = page.getByRole('button', { name: /Start Your Math Adventure/i });
  await start.waitFor();
  const header = page.getByText('NumberNebula', { exact: true }).first();
  for (let i = 0; i < 7; i++) await header.click();
  await expect(page.getByText(/Debug Mode Enabled/).first()).toBeVisible();
  await expect(page.getByText(/Debug Mode Enabled/)).toHaveCount(0, { timeout: 15_000 });
  await start.click();
  await expect(page.getByText(/Wormhole Activator/).first()).toBeVisible();
  await page.mouse.move(640, 400);
  const card = page.getByText(title).first();
  for (let i = 0; i < 60 && !(await card.isVisible().catch(() => false)); i++) {
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(250);
  }
  await page.waitForTimeout(600);
  await card.click();
  await page.waitForTimeout(3_000);
}

/** Steps through a game's onboarding, if it shows one. */
export async function dismissTutorial(page) {
  for (let i = 0; i < 8; i++) {
    const next = page.getByRole('button', { name: /^Next$/ });
    if (await next.isVisible().catch(() => false)) {
      await next.click(); await page.waitForTimeout(500); continue;
    }
    const done = page.getByRole('button', { name: /^(Got it|Let's go|Skip)$/ }).first();
    if (await done.isVisible().catch(() => false)) { await done.click(); await page.waitForTimeout(800); }
    return;
  }
}
