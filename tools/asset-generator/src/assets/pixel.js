// Pixel-art creature style, matching the good-spider-hood jumping spider: smooth
// chunky shapes and small hand-made-looking textures sampled with nearest filtering.
// Each material gets a 5-colour ramp (shadow, dark, base, light, pale) built from its
// colour; bodies get a speckled fur texture box-projected at a fixed texel size
// (about 1/150 of the creature), legs get pale bands at the joints.
import * as THREE from 'three';
import { toCreasedNormals } from 'three/addons/utils/BufferGeometryUtils.js';

const SIZE = 32;
const TEXELS_PER_SPAN = 150;
const PALE = new THREE.Color(0xc9a77a);

function hash(x, y, s) {
  let h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(s | 0, 2147483647);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

// Tileable blocky noise: value per 4x4 cell, wrapping.
function cell(x, y, n, s) {
  return hash(Math.floor(x / n) % (SIZE / n), Math.floor(y / n) % (SIZE / n), s);
}

function ramp(color) {
  const c = new THREE.Color(color);
  const hsl = {};
  c.getHSL(hsl);
  const shade = (k, ds = 0) => new THREE.Color().setHSL(hsl.h, Math.min(1, hsl.s * (1 + ds)), Math.min(1, hsl.l * k));
  const pale = c.clone().lerp(PALE, 0.65).multiplyScalar(1.05);
  return [shade(0.45, 0.1), shade(0.72), c.clone(), shade(1.25, -0.1), pale];
}

const CLOTH_WHITE = new THREE.Color(0xeee9dc);

// Paisley motif on the 32px tile: 2 = white ink, 1 = dark outline, 0 = cloth.
function paisley(x, y) {
  for (const [cx, cy, flip] of [[9, 10, 1], [24, 24, -1]]) {
    const dx = (x - cx) * flip;
    const dy = (y - cy) * flip;
    // Teardrop: a circle with a tail curling up-right.
    const d = Math.hypot(dx, dy);
    const tail = dy < 0 && dx > 0 && Math.abs(Math.hypot(dx - 4, dy) - 4) < 0.9 && dx < 7;
    if (d < 1.5) return 1;
    if (d < 3.6 || tail) return 2;
    if (d < 4.6) return 1;
    if (Math.abs(d - 5.6) < 0.5 && Math.round(Math.atan2(dy, dx) * 3) % 2 === 0) return 2;
  }
  if ((x === 24 && y === 7) || (x === 6 && y === 26) || (x === 17 && y === 16)) return 2;
  return 0;
}

// Skull and crossbones on the 32px tile (row 0 at the top, which faces the head):
// 0 = clear, 1 = shadow, 2 = ink, 3 = highlight.
function skullPixel(x, y) {
  const px = x + 0.5;
  const py = y + 0.5;
  const inEllipse = (cx, cy, rx, ry) => ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2 <= 1;
  const cranium = inEllipse(16, 11.5, 9.5, 9);
  const jaw = px > 10.5 && px < 21.5 && py > 15 && py < 25.5 && !(py > 23.5 && (px < 11.5 || px > 20.5));
  if (cranium || jaw) {
    if (inEllipse(12, 13.5, 2.9, 3.3) || inEllipse(20, 13.5, 2.9, 3.3)) return 0;
    if (py > 17 && py < 20.5 && Math.abs(px - 16) < (py - 17) * 0.55) return 0;
    if (py > 21.5 && py < 25 && [13, 16, 19].some((tx) => Math.abs(px - tx) < 0.6)) return 0;
    if (py > 21 && py < 22) return 1;
    const edge = !(inEllipse(16, 11.5, 8.3, 7.8) || (px > 11.8 && px < 20.2 && py > 15 && py < 24.5));
    if (edge) return 1;
    if (inEllipse(13, 7, 3, 2.2)) return 3;
    if (inEllipse(12, 13.5, 4, 4.3) || inEllipse(20, 13.5, 4, 4.3)) return 1;
    return 2;
  }
  // Crossbones under the skull.
  const bone = (ax, ay, bx, by) => {
    const t = Math.max(0, Math.min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / ((bx - ax) ** 2 + (by - ay) ** 2)));
    return Math.hypot(px - (ax + t * (bx - ax)), py - (ay + t * (by - ay)));
  };
  const ends = [[3.5, 20], [28.5, 20], [3.5, 30], [28.5, 30]];
  if (ends.some(([ex, ey]) => Math.hypot(px - ex, py - ey) < 2.1)) return 2;
  if (bone(4, 20.5, 28, 29.5) < 1.3 || bone(28, 20.5, 4, 29.5) < 1.3) return py < 25 ? 2 : 1;
  return 0;
}

const data = new Map();

// RGBA bytes of a pixel texture: kind is 'body' or 'limb'.
export function pixelTextureData(key) {
  if (data.has(key)) return data.get(key);
  const [kind, hex] = key.replace(/^pix_/, '').split('_');
  const colors = ramp(parseInt(hex, 16));
  const seed = parseInt(hex, 16) % 9973;
  const out = new Uint8Array(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      // Fur: a blocky base tone with fine speckles, like the spider's atlas.
      let t = 0.7 + 1.3 * cell(x, y, 8, seed) + 0.8 * cell(x, y, 4, seed + 1);
      const r = hash(x, y, seed + 2);
      if (r > 0.9) t = 3.6;
      else if (r > 0.78) t += 1.2;
      else if (r < 0.12) t -= 1.2;
      if (kind === 'paisley') {
        // Bandana print: cloth colour with white teardrops, dotted rings and specks.
        t = 2 + (r > 0.85 ? -1 : 0);
        const motif = paisley(x, y);
        if (motif === 2) t = 5;
        else if (motif === 1) t = 1;
      }
      let alpha = 255;
      if (kind === 'skull') {
        const s = skullPixel(x, y);
        alpha = s ? 255 : 0;
        t = [2, 1, 2, 3][s];
      }
      if (kind === 'limb') {
        // Pale bands at both joints with ragged edges; the band runs around the leg (v along it).
        const v = y / SIZE;
        const edge = 0.2 + 0.06 * hash(x, 0, seed + 3);
        if (v < edge || v > 1 - edge * 0.7) t = r > 0.75 ? 2.6 : 4;
      }
      const c = t === 5 ? CLOTH_WHITE : colors[Math.max(0, Math.min(4, Math.round(t)))];
      const i = (y * SIZE + x) * 4;
      out[i] = Math.round(THREE.MathUtils.clamp(c.r, 0, 1) ** (1 / 2.2) * 255);
      out[i + 1] = Math.round(THREE.MathUtils.clamp(c.g, 0, 1) ** (1 / 2.2) * 255);
      out[i + 2] = Math.round(THREE.MathUtils.clamp(c.b, 0, 1) ** (1 / 2.2) * 255);
      out[i + 3] = alpha;
    }
  }
  const res = { data: out, size: SIZE };
  data.set(key, res);
  return res;
}

const textures = new Map();
function pixelTexture(key) {
  if (!textures.has(key)) {
    const { data: d, size } = pixelTextureData(key);
    const t = new THREE.DataTexture(d, size, size, THREE.RGBAFormat);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.colorSpace = THREE.SRGBColorSpace;
    t.magFilter = THREE.NearestFilter;
    t.minFilter = THREE.NearestFilter;
    t.needsUpdate = true;
    textures.set(key, t);
  }
  return textures.get(key);
}

const materials = new Map();
function pixelMaterial(material, kind) {
  const hex = material.color.getHexString();
  const key = `${material.uuid}_${kind}`;
  if (!materials.has(key)) {
    const m = material.clone();
    m.name = `pix_${kind}_${hex}`;
    m.color.set(0xffffff);
    m.roughness = Math.min(1, material.roughness + 0.1);
    m.flatShading = false;
    if (typeof document !== 'undefined') m.map = pixelTexture(m.name);
    m.userData.pixel = m.name;
    m.userData.baseColor = material.color.getHex();
    materials.set(key, m);
  }
  return materials.get(key);
}

// Box-projected UVs (non-indexed geometry), `tile` units per texture repeat.
function boxUVs(g, matrix, tile) {
  const pos = g.attributes.position;
  const uv = new Float32Array(pos.count * 2);
  const a = new THREE.Vector3();
  const b = new THREE.Vector3();
  const c = new THREE.Vector3();
  const n = new THREE.Vector3();
  for (let i = 0; i < pos.count; i += 3) {
    a.fromBufferAttribute(pos, i).applyMatrix4(matrix);
    b.fromBufferAttribute(pos, i + 1).applyMatrix4(matrix);
    c.fromBufferAttribute(pos, i + 2).applyMatrix4(matrix);
    n.subVectors(b, a).cross(c.clone().sub(a));
    const [ax, ay, az] = [Math.abs(n.x), Math.abs(n.y), Math.abs(n.z)];
    [a, b, c].forEach((p, k) => {
      const [u, v] = ax >= ay && ax >= az ? [p.z, p.y] : ay >= az ? [p.x, p.z] : [p.x, p.y];
      uv[(i + k) * 2] = u / tile;
      uv[(i + k) * 2 + 1] = v / tile;
    });
  }
  return new THREE.Float32BufferAttribute(uv, 2);
}

// Apply the pixel style to every mesh under `root`, in place. Glass (wings) and
// glossy eyes stay as they are, like the spider's glossy eyes.
export function pixelize(root) {
  root.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(root, true);
  const span = Math.max(...box.getSize(new THREE.Vector3()).toArray(), 0.5);
  const tile = (span / TEXELS_PER_SPAN) * SIZE;
  root.traverse((mesh) => {
    if (!mesh.isMesh || mesh.userData.pixelized) return;
    mesh.userData.pixelized = true;
    const m = mesh.material;
    if (m.transparent || m.emissive.getHex() !== 0 || (m.roughness <= 0.25 && m.metalness < 0.5)) return;
    if (mesh.userData.keepGeometry) return;
    const limb = !!mesh.userData.limb;
    const kind = mesh.userData.pixKind ?? (limb ? 'limb' : 'body');
    let g = mesh.geometry.index ? mesh.geometry.toNonIndexed() : mesh.geometry.clone();
    if (!limb && !mesh.userData.keepUV) {
      for (const name of Object.keys(g.attributes)) if (name !== 'position' && name !== 'normal') g.deleteAttribute(name);
      g = toCreasedNormals(g, THREE.MathUtils.degToRad(70));
      // The bandana print repeats more often so its motifs show on small heads.
      g.setAttribute('uv', boxUVs(g, mesh.matrixWorld, kind === 'paisley' ? tile * 0.4 : tile));
    }
    mesh.geometry = g;
    mesh.material = pixelMaterial(m, kind);
  });
  return root;
}
