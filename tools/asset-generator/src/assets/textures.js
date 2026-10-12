// Procedural, tileable surface textures (grayscale detail that multiplies the
// material colour): stone, cardboard, wood, metal, plastic and organic skin.
// Generated once in code, so the browser preview and the .glb files share them.
import * as THREE from 'three';
import { PALETTE } from './common.js';

export const SURFACES = ['rough', 'fiber', 'wood', 'metal', 'plastic', 'organic'];
const SIZE = 256;

function hash2(x, y, s) {
  let h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(s | 0, 2147483647);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

// Value noise that wraps every px by py cells, so the texture tiles.
function tileNoise(x, y, px, py, seed = 0) {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const f = (t) => t * t * (3 - 2 * t);
  const sx = f(x - xi);
  const sy = f(y - yi);
  const c = (dx, dy) => hash2((((xi + dx) % px) + px) % px, (((yi + dy) % py) + py) % py, seed + px * 31 + py);
  const top = c(0, 0) + (c(1, 0) - c(0, 0)) * sx;
  const bottom = c(0, 1) + (c(1, 1) - c(0, 1)) * sx;
  return top + (bottom - top) * sy;
}

// Fractal noise over the unit square, `cx` x `cy` cells at the first octave.
function fbm(u, v, cx, cy, octaves = 4, seed = 0) {
  let sum = 0;
  let amp = 0.5;
  let norm = 0;
  for (let o = 0; o < octaves; o++) {
    const k = 2 ** o;
    sum += amp * tileNoise(u * cx * k, v * cy * k, cx * k, cy * k, seed + o);
    norm += amp;
    amp *= 0.5;
  }
  return sum / norm;
}

// Distance to the nearest feature point in a tiled grid of n x n cells (Worley).
function worley(u, v, n, seed) {
  const x = u * n;
  const y = v * n;
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  let d1 = 9;
  let d2 = 9;
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const cx = xi + dx;
      const cy = yi + dy;
      const wx = ((cx % n) + n) % n;
      const wy = ((cy % n) + n) % n;
      const fx = cx + hash2(wx, wy, seed);
      const fy = cy + hash2(wx, wy, seed + 1);
      const d = Math.hypot(fx - x, fy - y);
      if (d < d1) [d1, d2] = [d, d1];
      else if (d < d2) d2 = d;
    }
  }
  return [d1, d2];
}

// Draw a wrapped line of darkening into the value buffer.
function scratch(buf, x, y, angle, length, depth) {
  for (let t = 0; t < length; t++) {
    const px = ((Math.round(x + Math.cos(angle) * t) % SIZE) + SIZE) % SIZE;
    const py = ((Math.round(y + Math.sin(angle) * t) % SIZE) + SIZE) % SIZE;
    buf[py * SIZE + px] *= 1 - depth;
  }
}

const generators = {
  // Concrete, stone, soil: soft mottling, pores and a few hairline cracks.
  rough(buf) {
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) {
        const u = x / SIZE;
        const v = y / SIZE;
        let k = 0.72 + 0.28 * fbm(u, v, 6, 6, 5, 1);
        const pore = fbm(u, v, 48, 48, 1, 9);
        if (pore > 0.82) k *= 0.82;
        buf[y * SIZE + x] = k;
      }
    }
    for (let i = 0; i < 6; i++) {
      let x = hash2(i, 1, 5) * SIZE;
      let y = hash2(i, 2, 5) * SIZE;
      let a = hash2(i, 3, 5) * Math.PI * 2;
      for (let s = 0; s < 12; s++) {
        const len = 6 + hash2(i, s, 6) * 10;
        scratch(buf, x, y, a, len, 0.3);
        x += Math.cos(a) * len;
        y += Math.sin(a) * len;
        a += (hash2(i, s, 7) - 0.5) * 1.2;
      }
    }
  },
  // Cardboard and paper: long fibres, corrugation ridges and a few creases.
  fiber(buf) {
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) {
        const u = x / SIZE;
        const v = y / SIZE;
        const fibres = fbm(u, v, 2, 64, 3, 2);
        const ridges = 0.5 + 0.5 * Math.sin(v * Math.PI * 2 * 16);
        const stain = fbm(u, v, 3, 3, 4, 3);
        buf[y * SIZE + x] = 0.8 + 0.12 * fibres + 0.06 * ridges - 0.18 * Math.max(0, stain - 0.55);
      }
    }
    for (let i = 0; i < 4; i++) scratch(buf, hash2(i, 1, 8) * SIZE, hash2(i, 2, 8) * SIZE, hash2(i, 3, 8) * Math.PI, 120, 0.22);
  },
  // Wood: wavy grain lines along u, with a couple of knots.
  wood(buf) {
    const knots = [[0.3, 0.25], [0.75, 0.7]];
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) {
        const u = x / SIZE;
        const v = y / SIZE;
        let warp = fbm(u, v, 2, 4, 3, 4) * 3;
        for (const [kx, ky] of knots) {
          const dx = ((u - kx + 1.5) % 1) - 0.5;
          const dy = ((v - ky + 1.5) % 1) - 0.5;
          warp += 0.6 / (1 + (dx * dx * 40 + dy * dy * 300) * 20);
        }
        const rings = 0.5 + 0.5 * Math.sin((v * 24 + warp) * Math.PI * 2);
        const fine = fbm(u, v, 1, 96, 2, 5);
        buf[y * SIZE + x] = 0.86 - 0.2 * rings ** 3 + 0.12 * fine;
      }
    }
  },
  // Metal: brushed streaks, dents and scratches.
  metal(buf) {
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) {
        const u = x / SIZE;
        const v = y / SIZE;
        const brushed = fbm(u, v, 1, 128, 2, 6);
        const dents = fbm(u, v, 5, 5, 3, 7);
        buf[y * SIZE + x] = 0.86 + 0.1 * brushed - 0.12 * Math.max(0, dents - 0.5);
      }
    }
    for (let i = 0; i < 40; i++) scratch(buf, hash2(i, 1, 9) * SIZE, hash2(i, 2, 9) * SIZE, hash2(i, 3, 9) * Math.PI * 2, 8 + hash2(i, 4, 9) * 40, 0.25);
  },
  // Plastic: almost smooth, with scuffs.
  plastic(buf) {
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) {
        const u = x / SIZE;
        const v = y / SIZE;
        buf[y * SIZE + x] = 0.95 - 0.12 * Math.max(0, fbm(u, v, 4, 4, 4, 10) - 0.55);
      }
    }
    for (let i = 0; i < 18; i++) scratch(buf, hash2(i, 1, 11) * SIZE, hash2(i, 2, 11) * SIZE, hash2(i, 3, 11) * Math.PI * 2, 6 + hash2(i, 4, 11) * 20, 0.15);
  },
  // Leaves, chitin, skin: a mesh of cells with darker borders.
  organic(buf) {
    for (let y = 0; y < SIZE; y++) {
      for (let x = 0; x < SIZE; x++) {
        const u = x / SIZE;
        const v = y / SIZE;
        const [d1, d2] = worley(u, v, 10, 12);
        const edge = Math.min(1, (d2 - d1) * 6);
        const tone = fbm(u, v, 3, 3, 3, 13);
        buf[y * SIZE + x] = 0.7 + 0.22 * edge + 0.1 * tone;
      }
    }
  },
};

const cache = new Map();

// RGBA bytes for one surface.
export function surfaceTextureData(name) {
  if (cache.has(name)) return cache.get(name);
  const buf = new Float32Array(SIZE * SIZE);
  generators[name](buf);
  const data = new Uint8Array(SIZE * SIZE * 4);
  for (let i = 0; i < SIZE * SIZE; i++) {
    const v = Math.round(THREE.MathUtils.clamp(buf[i], 0.35, 1) * 255);
    data[i * 4] = data[i * 4 + 1] = data[i * 4 + 2] = v;
    data[i * 4 + 3] = 255;
  }
  const out = { data, size: SIZE };
  cache.set(name, out);
  return out;
}

const textures = new Map();
export function surfaceTexture(name) {
  if (!textures.has(name)) {
    const { data, size } = surfaceTextureData(name);
    const t = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.colorSpace = THREE.SRGBColorSpace;
    t.magFilter = THREE.LinearFilter;
    t.minFilter = THREE.LinearMipmapLinearFilter;
    t.generateMipmaps = true;
    t.anisotropy = 4;
    t.needsUpdate = true;
    textures.set(name, t);
  }
  return textures.get(name);
}

const WOOD = new Set([PALETTE.bark, PALETTE.wood, PALETTE.acorn, PALETTE.acornCap, PALETTE.leafDryDark, 0xe3c38f, 0x5b4636, 0x5a3a22, 0x3a2a22, 0xd8c08a]);
const FIBER = new Set([0xc49a6c, 0x9d7547, 0xefece4, 0xf3f1ea, 0xe24b2c, 0xf6c932, 0xd8d0b8, 0x3f7fc4, 0x2a5d9c, 0xe9e4d6, 0xd99a4a, 0xf1e2b4, 0xe0a64a, 0xb9772e, 0xd8c49a, 0xbca476, 0xe9e6dc, PALETTE.leafDry]);

// Pick a surface for a material from its look. Returns null for glass,
// water, silk and glowing parts, which stay untextured.
export function classifySurface(material) {
  if (material.transparent || material.emissive.getHex() !== 0) return null;
  const hex = material.color.getHex();
  if (material.metalness >= 0.4) return 'metal';
  if (WOOD.has(hex)) return 'wood';
  if (FIBER.has(hex)) return 'fiber';
  if (material.roughness <= 0.45) return 'plastic';
  const hsl = {};
  material.color.getHSL(hsl);
  if (hsl.s > 0.25 && hsl.h > 0.15 && hsl.h < 0.45) return 'organic';
  return 'rough';
}
