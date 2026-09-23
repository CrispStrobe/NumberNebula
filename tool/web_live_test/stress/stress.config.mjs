import base from '../playwright.config.mjs';
import { devices } from '@playwright/test';

export default {
  ...base,
  testDir: '.',
  retries: 0,
  reporter: 'line',
  projects: [
    { name: 'firefox-js', use: { ...devices['Desktop Firefox'], locale: 'en-US' } },
    { name: 'chromium-wasm', use: { ...devices['Desktop Chrome'], locale: 'en-US' } },
  ],
  webServer: base.webServer && { ...base.webServer, command: 'node ../serve.mjs' },
};
