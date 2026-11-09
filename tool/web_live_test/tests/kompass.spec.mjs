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

function awardedPoints(score) {
  // KompassScore serializes its parts; the total is a Dart getter, not a JSON field.
  return score.parts.reduce((total, part) => total + part.awardedPoints, 0);
}

async function courseResponse(page, partId) {
  const session = (await records(page))?.session;
  const taskId = session?.taskIds?.[session.index];
  return session?.responses?.[taskId]?.[partId];
}

async function focusTextbox(page, locator, reachOptions = {}) {
  const field = await reach(page, locator, reachOptions);
  await expect(locator).toHaveCount(1);
  await field.click();
  await expect(field).toBeFocused();
  // In the pinned Flutter engine an unfocused semantics input is a proxy:
  // it can report an empty DOM value while the canvas shows restored text.
  // Activating these default-autocorrect fields changes this attribute from
  // "off" to "on" once Flutter attaches its text-editing client. Filling the
  // proxy before that handoff can have the input reset by the initial value.
  await expect(field).toHaveAttribute('autocorrect', 'on');
  return field;
}

async function fillSavedTextbox(page, locator, value, savedValue, reachOptions = {}) {
  const field = await focusTextbox(page, locator, reachOptions);
  await field.fill(value);
  await expect(field).toHaveValue(value);
  // Establish that the real Flutter callback and save completed before the
  // next field, submission, or reload; a changed DOM proxy alone is not input.
  await expect.poll(savedValue).toBe(value);
}

async function labState(page, labId) {
  return page.evaluate((id) => {
    let saved = localStorage.getItem(`flutter.kompass_lab_v1_${id}`);
    if (saved === null) return null;
    saved = JSON.parse(saved);
    return typeof saved === 'string' ? JSON.parse(saved) : saved;
  }, labId);
}

async function seedLab(page, baseURL, labId, index, response) {
  await page.addInitScript(({ appOrigin, snapshot }) => {
    if (window !== window.top || location.origin !== appOrigin) return;
    const key = `flutter.kompass_lab_v1_${snapshot.labId}`;
    // SharedPreferences stores a JSON string inside its JSON-encoded value.
    // Seed before Flutter reads its cache, and never overwrite a reload's draft.
    if (localStorage.getItem(key) === null) {
      localStorage.setItem(key, JSON.stringify(JSON.stringify(snapshot)));
    }
  }, {
    appOrigin: new URL(baseURL).origin,
    snapshot: {
      schemaVersion: 1,
      labId,
      sessionId: `browser-lab:${labId}`,
      seed: 417,
      index,
      response,
      firstResponse: {},
      activeMillis: 0,
      attempts: 0,
      hintsUsed: 0,
      completed: false,
      reported: false,
    },
  });
}

async function openLabCard(page, title) {
  await (await reach(page, page.getByRole('button', {
    name: new RegExp(`^${title}(?:\\s|$)`),
  }))).click();
}

async function reloadLab(page, title) {
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#splash')).toHaveCount(0);
  await enableSemantics(page);
  await (await reach(page, page.getByRole('button', {
    name: /^KOMPASS 4 · Mathematics$/,
  }), { x: 300 })).click();
  await expect(page.getByRole('button', { name: 'My next practice', exact: true })).toBeVisible();
  await openLabCard(page, title);
}

test('KOMPASS practice preserves real first input, correction and a resumed draft', async ({ page }, info) => {
  test.setTimeout(180_000);
  const log = watch(page);
  await openCourse(page);
  await page.getByRole('button', { name: 'My next practice', exact: true }).click();
  await expect(page.getByText('Trade bundles', { exact: true })).toBeVisible();
  // Flutter includes the part prompt in the text field's accessible name.
  // Match the complete question so the disabled selectable prompt and the
  // second answer cannot be mistaken for the value being edited.
  const answer = page.getByRole('textbox', {
    name: 'What number is represented? Your answer', exact: true,
  });
  await fillSavedTextbox(page, answer, '999999', () => courseResponse(page, 'value'));
  await (await reach(page, page.getByRole('button', { name: 'Check answer', exact: true }))).click();
  await expect.poll(async () => (await records(page))?.attempts?.length).toBe(1);
  let evidence = (await records(page)).attempts[0];
  expect(evidence.firstResponses.value).toBe('999999');
  expect(awardedPoints(evidence.firstScore)).toBe(0);
  await (await reach(page, page.getByRole('button', { name: 'Hint', exact: true }))).click();
  await fillSavedTextbox(page, answer, '445', () => courseResponse(page, 'value'), { direction: -1 });
  await (await reach(page, page.getByRole('button', { name: 'Check answer', exact: true }))).click();
  await expect.poll(async () => (await records(page))?.attempts?.[0]?.responses?.value).toBe('445');
  evidence = (await records(page)).attempts[0];
  expect(evidence.firstResponses.value).toBe('999999');
  expect(evidence.hintsUsed).toBe(1);
  expect(awardedPoints(evidence.score)).toBeGreaterThan(awardedPoints(evidence.firstScore));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#splash')).toHaveCount(0);
  await enableSemantics(page);
  await (await reach(page, page.getByRole('button', { name: /^KOMPASS 4 · Mathematics$/ }), { x: 300 })).click();
  await page.getByRole('button', { name: 'Continue unfinished session', exact: true }).click();
  await expect.poll(() => courseResponse(page, 'value')).toBe('445');
  await expect(await focusTextbox(page, answer)).toHaveValue('445');
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
  await fillSavedTextbox(page, page.getByRole('textbox', {
    name: 'What number results when exactly one hundred is added to 5042? Your answer',
    exact: true,
  }), '5142', () => courseResponse(page, 'increase'));
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

test('KOMPASS chance lab restores a wrong first response and later help before correction', async ({ page, baseURL }, info) => {
  test.setTimeout(180_000);
  const log = watch(page);
  const labId = 'chance_detective';
  // Both labelled draw rows fit together, so their duplicate symbol labels can
  // be selected by the two positions deliberately authored in ChanceDetectiveView.
  await page.setViewportSize({ width: 1280, height: 1000 });
  await seedLab(page, baseURL, labId, 1, { first: '', second: '', reason: '' });
  await openCourse(page);
  await openLabCard(page, 'Chance detectives');
  // The pinned Flutter SDK exposes ChoiceChip's checked state as a web checkbox.
  const stars = page.getByRole('checkbox', { name: 'Star', exact: true });
  const circles = page.getByRole('checkbox', { name: 'Circle', exact: true });
  await expect(stars).toHaveCount(2);
  await expect(circles).toHaveCount(2);
  await (await reach(page, stars.nth(0))).click();
  await (await reach(page, circles.nth(1))).click();
  await (await reach(page, page.getByRole('button', {
    name: 'One allowed exception shows that it does not always happen.', exact: true,
  }))).click();
  const firstResponse = { first: 'star', second: 'circle', reason: 'exception' };
  await expect.poll(async () => (await labState(page, labId))?.response).toEqual(firstResponse);
  await (await reach(page, page.getByRole('button', { name: 'Check', exact: true }))).click();
  await expect.poll(async () => (await labState(page, labId))?.attempts).toBe(1);
  const first = await labState(page, labId);
  // Index 1 claims at least one star is certain. Star/circle is legal but does
  // not refute that claim; two circles are always available in this recipe.
  expect(first.firstCorrect).toBe(false);
  expect(first.firstPoints).toBe(2);
  expect(first.firstResponse).toEqual(firstResponse);
  expect(first.hintsBeforeFirstResponse).toBe(0);
  expect((await records(page))?.attempts ?? []).toHaveLength(0);
  await (await reach(page, page.getByRole('button', { name: 'Hint 1/3', exact: true }))).click();
  await expect.poll(async () => (await labState(page, labId))?.hintsUsed).toBe(1);

  await reloadLab(page, 'Chance detectives');
  await expect(circles).toHaveCount(2);
  await expect.poll(async () => (await labState(page, labId))?.roundId).toBe(first.roundId);
  const restored = await labState(page, labId);
  expect(restored.response).toEqual(firstResponse);
  expect(restored.firstResponse).toEqual(firstResponse);
  expect(restored.hintsBeforeFirstResponse).toBe(0);
  expect(restored.hintsUsed).toBe(1);
  await expect(stars.nth(0)).toBeChecked();
  await expect(circles.nth(1)).toBeChecked();
  // Change just the first draw; completing now also requires the second draw
  // and explanation selected before reload to have survived.
  await (await reach(page, circles.nth(0))).click();
  await (await reach(page, page.getByRole('button', { name: 'Check', exact: true }))).click();
  await expect.poll(async () => (await labState(page, labId))?.reported).toBe(true);
  const attempts = (await records(page)).attempts;
  expect(attempts).toHaveLength(1);
  const evidence = attempts[0];
  expect(evidence.mode).toBe('lab');
  expect(evidence.contentUse).toBe('practice');
  expect(evidence.isNovel).toBe(false);
  expect(evidence.firstResponses.lab).toEqual(firstResponse);
  expect(evidence.responses.lab).toEqual({ first: 'circle', second: 'circle', reason: 'exception' });
  expect(awardedPoints(evidence.firstScore)).toBe(2);
  expect(awardedPoints(evidence.score)).toBe(3);
  expect(evidence.hintsBeforeFirstResponse).toBe(0);
  expect(evidence.hintsUsed).toBe(1);
  await info.attach('kompass-chance-restored.png', {
    body: await page.screenshot(), contentType: 'image/png',
  });
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
});

test('KOMPASS reasoning lab restores actual numeric inputs without replacing first evidence', async ({ page, baseURL }, info) => {
  test.setTimeout(180_000);
  const log = watch(page);
  const labId = 'reasoning_workshop';
  await seedLab(page, baseURL, labId, 0, { middle: '', base: '', inverse: '' });
  await openCourse(page);
  await openLabCard(page, 'Reasoning workshop');
  // ReasoningLabView labels each numeric field through Semantics; Flutter may
  // append the input hint to that name, so match the unique authored question.
  const middle = page.getByRole('textbox', { name: /Right brick in the middle row/ });
  const base = page.getByRole('textbox', { name: /Right brick in the base row/ });
  await fillSavedTextbox(page, middle, '1234', async () => (await labState(page, labId))?.response?.middle);
  await fillSavedTextbox(page, base, '567', async () => (await labState(page, labId))?.response?.base);
  const subtraction = page.getByRole('checkbox', { name: 'Subtraction', exact: true });
  await (await reach(page, subtraction)).click();
  await (await reach(page, page.getByRole('button', { name: 'Hint 1/3', exact: true }))).click();
  await (await reach(page, page.getByRole('button', { name: 'Check', exact: true }))).click();
  await expect.poll(async () => (await labState(page, labId))?.attempts).toBe(1);
  const first = await labState(page, labId);
  const firstResponse = { middle: '1234', base: '567', inverse: 'subtract' };
  expect(first.firstResponse).toEqual(firstResponse);
  expect(first.firstCorrect).toBe(false);
  // Both numbers are outside the generated answer ranges. Only the correct
  // inverse-operation choice earns a point, and this first answer used a hint.
  expect(first.firstPoints).toBe(1);
  expect(first.hintsBeforeFirstResponse).toBe(1);

  await reloadLab(page, 'Reasoning workshop');
  await expect.poll(async () => (await labState(page, labId))?.response).toEqual(firstResponse);
  await expect(await focusTextbox(page, middle)).toHaveValue('1234');
  await expect(await focusTextbox(page, base)).toHaveValue('567');
  expect((await labState(page, labId)).roundId).toBe(first.roundId);
  expect((await labState(page, labId)).response.inverse).toBe('subtract');
  expect((await labState(page, labId)).hintsUsed).toBe(1);
  await expect(await reach(page, subtraction)).toBeChecked();
  await fillSavedTextbox(page, base, '568', async () => (await labState(page, labId))?.response?.base, { direction: -1 });
  await (await reach(page, page.getByRole('button', { name: 'Check', exact: true }))).click();
  await expect.poll(async () => (await labState(page, labId))?.attempts).toBe(2);
  const revised = await labState(page, labId);
  expect(revised.response.base).toBe('568');
  expect(revised.firstResponse).toEqual(firstResponse);
  expect(revised.firstPoints).toBe(1);
  expect(revised.hintsBeforeFirstResponse).toBe(1);
  expect(revised.completed).toBe(false);
  expect((await records(page))?.attempts ?? []).toHaveLength(0);
  await info.attach('kompass-reasoning-restored.png', {
    body: await page.screenshot(), contentType: 'image/png',
  });
  expect(log.errors).toEqual([]);
  expect(log.failures).toEqual([]);
});

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
    await expect(page.locator('article.task')).toHaveCount(72);
    await expect(page.locator('.solution, .rubric')).toHaveCount(0);
    await page.locator('#domain-filter').selectOption('geometry');
    await expect(page.locator('article.task:visible')).toHaveCount(18);
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
