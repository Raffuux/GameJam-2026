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
      if (kind === 'limb') {
        // Pale bands at both joints with ragged edges; the band runs around the leg (v along it).
        const v = y / SIZE;
        const edge = 0.2 + 0.06 * hash(x, 0, seed + 3);
        if (v < edge || v > 1 - edge * 0.7) t = r > 0.75 ? 2.6 : 4;
      }
      const c = colors[Math.max(0, Math.min(4, Math.round(t)))];
      const i = (y * SIZE + x) * 4;
      out[i] = Math.round(THREE.MathUtils.clamp(c.r, 0, 1) ** (1 / 2.2) * 255);
      out[i + 1] = Math.round(THREE.MathUtils.clamp(c.g, 0, 1) ** (1 / 2.2) * 255);
      out[i + 2] = Math.round(THREE.MathUtils.clamp(c.b, 0, 1) ** (1 / 2.2) * 255);
      out[i + 3] = 255;
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
    let g = mesh.geometry.index ? mesh.geometry.toNonIndexed() : mesh.geometry.clone();
    if (!limb) {
      for (const name of Object.keys(g.attributes)) if (name !== 'position' && name !== 'normal') g.deleteAttribute(name);
      g = toCreasedNormals(g, THREE.MathUtils.degToRad(70));
      g.setAttribute('uv', boxUVs(g, mesh.matrixWorld, tile));
    }
    mesh.geometry = g;
    mesh.material = pixelMaterial(m, limb ? 'limb' : 'body');
  });
  return root;
}
