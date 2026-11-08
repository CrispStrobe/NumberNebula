import { test, expect, openApp, enableSemantics, watch } from './helpers.mjs';

async function reach(page, locator, { x = 900, direction = 1 } = {}) {
  for (let step = 0; step < 24; step++) {
    if (await locator.count() && await locator.first().isVisible()) return locator.first();
    await page.mouse.move(x, 620);
    await page.mouse.wheel(0, direction * 420);
    await page.waitForTimeout(100);
  }
  await expect(locator.first()).toBeVisible();
  return locator.first();
}

async function openCourse(page) {
  await openApp(page);
  await enableSemantics(page);
  const entry = await reach(page, page.getByRole('button', { name: /^KOMPASS 4 · Mathematics$/ }), { x: 300 });
  await entry.click();
  await expect(page.getByRole('button', { name: 'My next practice', exact: true })).toBeVisible();
}

async function records(page) {
  return page.evaluate(() => {
    let saved = localStorage.getItem('flutter.kompass_learning_v1');
    if (saved === null) return null;
    saved = JSON.parse(saved);
    return typeof saved === 'string' ? JSON.parse(saved) : saved;
  });
}

test('KOMPASS practice preserves real first input, correction and a resumed draft', async ({ page }, info) => {
  test.setTimeout(180_000);
  const log = watch(page);
  await openCourse(page);
  await page.getByRole('button', { name: 'My next practice', exact: true }).click();
  await expect(page.getByText('Trade bundles', { exact: true })).toBeVisible();
  const answer = page.getByRole('textbox', { name: 'Your answer', exact: true }).first();
  await answer.fill('999999');
  await (await reach(page, page.getByRole('button', { name: 'Check answer', exact: true }))).click();
  await expect.poll(async () => (await records(page))?.attempts?.length).toBe(1);
  let evidence = (await records(page)).attempts[0];
  expect(evidence.firstResponses.value).toBe('999999');
  expect(evidence.firstScore.awardedPoints).toBe(0);
  await (await reach(page, page.getByRole('button', { name: 'Hint', exact: true }))).click();
  await (await reach(page, answer, { direction: -1 })).fill('445');
  await (await reach(page, page.getByRole('button', { name: 'Check answer', exact: true }))).click();
  await expect.poll(async () => (await records(page))?.attempts?.[0]?.responses?.value).toBe('445');
  evidence = (await records(page)).attempts[0];
  expect(evidence.firstResponses.value).toBe('999999');
  expect(evidence.hintsUsed).toBe(1);
  expect(evidence.score.awardedPoints).toBeGreaterThan(evidence.firstScore.awardedPoints);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#splash')).toHaveCount(0);
  await enableSemantics(page);
  await (await reach(page, page.getByRole('button', { name: /^KOMPASS 4 · Mathematics$/ }), { x: 300 })).click();
  await page.getByRole('button', { name: 'Continue unfinished session', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Your answer', exact: true }).first()).toHaveValue('445');
  await info.attach('kompass-practice.png', { body: await page.screenshot(), contentType: 'image/png' });
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
});

test('KOMPASS independent work defers feedback and rehearsal keeps its 45-minute deadline', async ({ page }) => {
  test.setTimeout(180_000);
  const log = watch(page);
  await openCourse(page);
  await page.getByRole('button', { name: 'Independent check', exact: true }).click();
  await expect(page.getByText('Recognise the same number', { exact: true })).toBeVisible();
  expect(await page.getByRole('button', { name: 'Hint', exact: true }).count()).toBe(0);
  expect(await page.getByRole('button', { name: 'Check answer', exact: true }).count()).toBe(0);
  await (await reach(page, page.getByRole('textbox', { name: 'Your answer', exact: true }).first())).fill('5142');
  await (await reach(page, page.getByRole('button', { name: 'Finish session', exact: true }))).click();
  await page.getByRole('button', { name: 'Finish', exact: true }).click();
  await expect.poll(async () => (await records(page))?.session).toBeNull();
  expect((await records(page)).attempts[0].mode).toBe('check');
  await (await reach(page, page.getByRole('button', { name: 'Back to learning overview', exact: true }))).click();
  await page.getByRole('button', { name: '45-minute rehearsal', exact: true }).click();
  await page.getByRole('button', { name: 'Start', exact: true }).click();
  await expect.poll(async () => (await records(page))?.session?.deadline).toBeTruthy();
  const deadline = (await records(page)).session.deadline;
  expect(Date.parse(deadline) - Date.now()).toBeGreaterThan(44 * 60_000);
  expect(Date.parse(deadline) - Date.now()).toBeLessThanOrEqual(45 * 60_000);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#splash')).toHaveCount(0);
  await enableSemantics(page);
  await (await reach(page, page.getByRole('button', { name: /^KOMPASS 4 · Mathematics$/ }), { x: 300 })).click();
  await page.getByRole('button', { name: 'Continue unfinished session', exact: true }).click();
  expect((await records(page)).session.deadline).toBe(deadline);
  expect(await page.getByRole('button', { name: 'Check answer', exact: true }).count()).toBe(0);
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
});

for (const title of ['Number dock', 'Supply station', 'Data observatory', 'Geometry workshop']) {
  test(`KOMPASS lab opens and responds: ${title}`, async ({ page }, info) => {
    test.setTimeout(180_000);
    const log = watch(page);
    await openCourse(page);
    const card = page.getByRole('button', { name: new RegExp(`^${title}`) });
    await (await reach(page, card)).click();
    await (await reach(page, page.getByRole('button', { name: 'Check', exact: true }))).click();
    await expect(page.getByText(/^Try again(?:\s|$)/).first()).toBeVisible();
    await (await reach(page, page.getByRole('button', { name: 'Hint 1/3', exact: true }))).click();
    await expect(page.getByRole('button', { name: 'Hint 2/3', exact: true })).toBeVisible();
    await info.attach(`kompass-${title.replaceAll(' ', '-')}.png`, {
      body: await page.screenshot(), contentType: 'image/png',
    });
    expect(log.errors).toEqual([]);
    expect(log.failures).toEqual([]);
  });
}

test('KOMPASS downloads the matching offline paper worksheet and separate solutions', async ({ page }) => {
  test.setTimeout(180_000);
  const log = watch(page);
  await openCourse(page);
  await page.getByRole('button', { name: 'Practise on paper', exact: true }).click();
  await (await reach(page, page.getByRole('button', { name: 'Open practice booklet', exact: true }))).click();
  const downloadEvent = page.waitForEvent('download');
  await (await reach(page, page.getByRole('button', { name: 'Download tasks', exact: true }))).click();
  const download = await downloadEvent;
  expect(download.suggestedFilename()).toBe('practice_en.html');
  const solutionEvent = page.waitForEvent('download');
  await (await reach(page, page.getByRole('button', { name: 'Download solutions', exact: true }))).click();
  expect((await solutionEvent).suggestedFilename()).toBe('practice_en_solutions.html');
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
});

for (const language of ['de', 'en']) {
  test(`KOMPASS printable ${language} has complete diagrams and clean paper layout`, async ({ page }, info) => {
    const log = watch(page);
    await page.setViewportSize({ width: 800, height: 1100 });
    await page.goto(`./assets/assets/kompass/print/practice_${language}.html`);
    await expect(page.locator('article.task')).toHaveCount(64);
    await expect(page.locator('.solution, .rubric')).toHaveCount(0);
    await page.locator('#domain-filter').selectOption('geometry');
    await expect(page.locator('article.task:visible')).toHaveCount(16);
    await page.locator('#domain-filter').selectOption('all');
    await page.emulateMedia({ media: 'print' });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    for (const id of ['mz04_inverse_wall', 'mr06_front_view_heights', 'md03_read_two_step_chart']) {
      const task = page.locator(`article[data-task-id="${id}"]`);
      await expect(task.locator('svg').first()).toBeVisible();
      await info.attach(`${language}-${id}.png`, {
        body: await task.screenshot(), contentType: 'image/png',
      });
    }
    if (info.project.name === 'chromium-wasm') {
      await info.attach(`kompass-practice-${language}.pdf`, {
        body: await page.pdf({ preferCSSPageSize: true, printBackground: true }),
        contentType: 'application/pdf',
      });
    }
    await page.goto(`./assets/assets/kompass/print/rehearsal_${language}.html`);
    await expect(page.locator('article.task')).toHaveCount(20);
    await expect(page.locator('.solution, .rubric')).toHaveCount(0);
    if (info.project.name === 'chromium-wasm') {
      await info.attach(`kompass-rehearsal-${language}.pdf`, {
        body: await page.pdf({ preferCSSPageSize: true, printBackground: true }),
        contentType: 'application/pdf',
      });
    }
    expect(log.errors).toEqual([]);
    expect(log.failures).toEqual([]);
  });
}
