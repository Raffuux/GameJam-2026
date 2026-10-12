// Renders every design sheet (sheet.html) to a PNG with a headless Chromium.
// Start `npx vite --port 4176` first, then:
//   node scripts/design-sheets.mjs <out-dir> [chromium-path]
// Needs playwright-core (npx playwright-core works too).
import { mkdir } from 'node:fs/promises';
import { chromium } from 'playwright-core';

const out = process.argv[2] ?? '../../assets/designs';
const executablePath = process.argv[3] ?? process.env.CHROMIUM_PATH;
const base = process.env.SHEET_URL ?? 'http://localhost:4176/sheet.html';
const pages = [
  ...['spider', 'mantis', 'fly', 'ant', 'ladybug', 'beetle', 'bee', 'caterpillar'].map((id) => [`animal_${id}`, `?id=${id}`]),
  ...['spider_tisseuses', 'mantis_prieurs', 'fly_nuee', 'ant_colonie'].map((id) => [`member_${id}`, `?id=${id}`]),
  ...['tisseuses', 'prieurs', 'nuee', 'colonie'].map((g) => [`gang_${g}`, `?gang=${g}`]),
  ['gang_lineup', '?lineup'],
];

await mkdir(out, { recursive: true });
const browser = await chromium.launch({ executablePath, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1800, height: 1100 } });
page.on('pageerror', (e) => console.error('page error', e.message));
for (const [name, query] of pages) {
  await page.goto(base + query);
  await page.waitForSelector('body[data-ready]', { timeout: 120000 });
  await page.waitForTimeout(300);
  await page.locator('#sheet').screenshot({ path: `${out}/${name}.png` });
  console.log(`${name}.png`);
}
await browser.close();
