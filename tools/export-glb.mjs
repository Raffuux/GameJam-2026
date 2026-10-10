// Exporte chaque créature du bestiaire en .glb (pose de repos, facettes conservées).
// Usage : node tools/export-glb.mjs   (nécessite playwright + chromium ; three.js est servi depuis node_modules si présent)
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const page = path.join(here, '../assets/bestiaire/index.html');
const out = path.join(here, '../assets/models');
const localThree = process.env.THREE_DIR; // ex. node_modules/three, pour travailler hors ligne

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const tab = await browser.newPage();
tab.on('pageerror', e => console.error('pageerror:', e.message));
if (localThree) {
  await tab.route('**/three@0.128.0/**', r => r.fulfill({ path: path.join(localThree, r.request().url().split('three@0.128.0/')[1]), contentType: 'application/javascript' }));
}
await tab.goto('file://' + page);
await tab.waitForFunction(() => window.exportGLB && window.Bestiaire);
fs.mkdirSync(out, { recursive: true });
const ids = await tab.evaluate(() => window.Bestiaire.list.map(c => c.id));
for (const id of ids) {
  const b64 = await tab.evaluate(async id => {
    const buf = new Uint8Array(await window.exportGLB(id));
    let s = ''; for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
    return btoa(s);
  }, id);
  const file = path.join(out, id + '.glb');
  fs.writeFileSync(file, Buffer.from(b64, 'base64'));
  console.log(file, Math.round(fs.statSync(file).size / 1024) + ' Ko');
}
await browser.close();
