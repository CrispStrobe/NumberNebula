// Live tests against the built web app.
//
// Local build (default): serves ../../build/web through serve.mjs, which
// applies vercel.json. Deployed site: BASE_URL=https://… npx playwright test
//
// Chromium gets the dart2wasm + skwasm build; Firefox gets the dart2js +
// CanvasKit fallback (Flutter only allows wasm on Blink today), so the two
// projects cover both builds a visitor can receive.

import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.BASE_URL ?? 'http://localhost:4173';

export default defineConfig({
  testDir: './tests',
  timeout: 120_000,
  expect: { timeout: 60_000 },
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL,
    locale: 'en-US',
    viewport: { width: 1280, height: 800 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium-wasm', use: { ...devices['Desktop Chrome'], locale: 'en-US' } },
    { name: 'firefox-js', use: { ...devices['Desktop Firefox'], locale: 'en-US' } },
  ],
  webServer: process.env.BASE_URL
    ? undefined
    : {
        command: 'node serve.mjs',
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 30_000,
      },
});
