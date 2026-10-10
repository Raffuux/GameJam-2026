// Grime pass: makes the clean low-poly assets darker, grainier and dirtier.
// - palette: every material is darkened and desaturated a little,
// - grain: a shared tileable grime texture, box-projected at a fixed size
//   (GRIT.tile cm per repeat) so the grain looks the same on a fly and a tower,
// - dirt: vertex colours (glTF COLOR_0) with blotches, a dark band near the
//   ground, run-off streaks and rust patches on metal parts.
// Large faces are split a little so the dirt gradients have vertices to live on.
import * as THREE from 'three';

const GRIT = {
  darken: 0.78,
  desaturate: 0.22,
  grain: 0.1,
  blotch: 0.5,
  groundDirt: 0.55,
  streak: 0.45,
  tile: 3, // cm covered by one repeat of the grime texture
  textureSize: 256,
  rust: new THREE.Color(0.55, 0.32, 0.18),
};

function hash3(x, y, z) {
  let h = Math.imul(x | 0, 374761393) ^ Math.imul(y | 0, 668265263) ^ Math.imul(z | 0, 2147483647);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

// Smooth value noise in [0, 1].
function noise3(x, y, z) {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const zi = Math.floor(z);
  const s = (t) => t * t * (3 - 2 * t);
  const fx = s(x - xi);
  const fy = s(y - yi);
  const fz = s(z - zi);
  const lerp = (a, b, t) => a + (b - a) * t;
  const c = (dx, dy, dz) => hash3(xi + dx, yi + dy, zi + dz);
  return lerp(
    lerp(lerp(c(0, 0, 0), c(1, 0, 0), fx), lerp(c(0, 1, 0), c(1, 1, 0), fx), fy),
    lerp(lerp(c(0, 0, 1), c(1, 0, 1), fx), lerp(c(0, 1, 1), c(1, 1, 1), fx), fy),
    fz,
  );
}

// Split every triangle until no edge is longer than maxEdge.
function tessellate(geometry, maxEdge) {
  const src = geometry.attributes.position.array;
  const out = [];
  const a = new THREE.Vector3();
  const b = new THREE.Vector3();
  const c = new THREE.Vector3();
  const stack = [];
  for (let i = 0; i < src.length; i += 9) {
    stack.push([src[i], src[i + 1], src[i + 2], src[i + 3], src[i + 4], src[i + 5], src[i + 6], src[i + 7], src[i + 8]]);
    while (stack.length) {
      const t = stack.pop();
      a.fromArray(t, 0);
      b.fromArray(t, 3);
      c.fromArray(t, 6);
      const ab = a.distanceTo(b);
      const bc = b.distanceTo(c);
      const ca = c.distanceTo(a);
      const longest = Math.max(ab, bc, ca);
      if (longest <= maxEdge || out.length > 300000) {
        out.push(...t);
        continue;
      }
      // Split the longest edge at its midpoint.
      let p, q, r;
      if (longest === ab) [p, q, r] = [a, b, c];
      else if (longest === bc) [p, q, r] = [b, c, a];
      else [p, q, r] = [c, a, b];
      const m = p.clone().add(q).multiplyScalar(0.5);
      stack.push([...p.toArray(), ...m.toArray(), ...r.toArray()]);
      stack.push([...m.toArray(), ...q.toArray(), ...r.toArray()]);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(out, 3));
  g.computeVertexNormals();
  return g;
}

// Tileable grayscale grime: fine grain, specks, scratches and soft stains.
// Returns RGBA bytes, values between ~0.55 and 1 so it only darkens.
let grimeData = null;
export function grimeTextureData(size = GRIT.textureSize) {
  if (grimeData) return grimeData;
  const data = new Uint8Array(size * size * 4);
  const period = 8;
  const tileNoise = (x, y, p) => {
    // Value noise that wraps every `p` cells, so the texture tiles.
    const xi = Math.floor(x);
    const yi = Math.floor(y);
    const sx = x - xi;
    const sy = y - yi;
    const f = (t) => t * t * (3 - 2 * t);
    const c = (dx, dy) => hash3(((xi + dx) % p + p) % p, ((yi + dy) % p + p) % p, p);
    const top = c(0, 0) + (c(1, 0) - c(0, 0)) * f(sx);
    const bottom = c(0, 1) + (c(1, 1) - c(0, 1)) * f(sx);
    return top + (bottom - top) * f(sy);
  };
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const u = (x / size) * period;
      const v = (y / size) * period;
      let stain = 0;
      let amp = 0.5;
      let freq = 1;
      for (let o = 0; o < 4; o++) {
        stain += amp * tileNoise(u * freq, v * freq, period * freq);
        amp *= 0.5;
        freq *= 2;
      }
      let k = 1 - 0.28 * Math.max(0, stain - 0.35) / 0.65;
      k -= 0.16 * hash3(x, y, 7); // grain
      if (hash3(x, y, 11) > 0.992) k -= 0.25; // dark specks
      data[(y * size + x) * 4] = 0;
      data[(y * size + x) * 4 + 3] = 255;
      const value = Math.round(THREE.MathUtils.clamp(k, 0.5, 1) * 255);
      data[(y * size + x) * 4] = data[(y * size + x) * 4 + 1] = data[(y * size + x) * 4 + 2] = value;
    }
  }
  // Scratches: short bright-dark lines that wrap around the edges.
  for (let i = 0; i < 70; i++) {
    let x = hash3(i, 1, 3) * size;
    let y = hash3(i, 2, 3) * size;
    const a = hash3(i, 3, 3) * Math.PI * 2;
    const len = 6 + hash3(i, 4, 3) * 26;
    for (let t = 0; t < len; t++) {
      const px = ((Math.round(x) % size) + size) % size;
      const py = ((Math.round(y) % size) + size) % size;
      const idx = (py * size + px) * 4;
      const v = Math.max(110, data[idx] - 55);
      data[idx] = data[idx + 1] = data[idx + 2] = v;
      x += Math.cos(a);
      y += Math.sin(a);
    }
  }
  grimeData = { data, size };
  return grimeData;
}

let grimeTex = null;
function grimeTexture() {
  if (grimeTex) return grimeTex;
  const { data, size } = grimeTextureData();
  grimeTex = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  grimeTex.wrapS = grimeTex.wrapT = THREE.RepeatWrapping;
  grimeTex.colorSpace = THREE.SRGBColorSpace;
  grimeTex.magFilter = THREE.LinearFilter;
  grimeTex.minFilter = THREE.LinearMipmapLinearFilter;
  grimeTex.generateMipmaps = true;
  grimeTex.needsUpdate = true;
  return grimeTex;
}

// Box-projected UVs in the asset's own space: each triangle picks the axis its
// face normal points along. Needs a non-indexed geometry.
function boxUVs(geometry, matrix) {
  const pos = geometry.attributes.position;
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
    const ax = Math.abs(n.x);
    const ay = Math.abs(n.y);
    const az = Math.abs(n.z);
    [a, b, c].forEach((p, k) => {
      let u, v;
      if (ax >= ay && ax >= az) [u, v] = [p.z, p.y];
      else if (ay >= az) [u, v] = [p.x, p.z];
      else [u, v] = [p.x, p.y];
      uv[(i + k) * 2] = u / GRIT.tile;
      uv[(i + k) * 2 + 1] = v / GRIT.tile;
    });
  }
  return new THREE.Float32BufferAttribute(uv, 2);
}

function gritColor(material) {
  if (material.userData.gritted) return;
  material.userData.gritted = true;
  const hsl = {};
  material.color.getHSL(hsl);
  material.color.setHSL(hsl.h, hsl.s * (1 - GRIT.desaturate), hsl.l * GRIT.darken);
  material.roughness = Math.min(1, material.roughness + 0.12);
  material.vertexColors = true;
  material.userData.grime = true;
  // In the browser the texture is attached directly; the .glb exporter adds
  // it to the file itself (see scripts/export-glb.mjs).
  if (typeof document !== 'undefined') material.map = grimeTexture();
  material.needsUpdate = true;
}

// Apply the grime pass to every mesh under `root`, in place.
export function weather(root, { seed = 1 } = {}) {
  root.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(root, true);
  const size = box.getSize(new THREE.Vector3());
  const height = Math.max(size.y, 0.5);
  const span = Math.max(size.x, size.y, size.z, 0.5);
  const grainScale = 6 / Math.max(span / 10, 0.3); // noise cells per cm
  const maxEdge = span / 8;
  const off = seed * 17.3;
  const world = new THREE.Vector3();
  const col = new THREE.Color();

  root.traverse((mesh) => {
    if (!mesh.isMesh || mesh.userData.weathered) return;
    mesh.userData.weathered = true;
    const material = mesh.material;
    gritColor(material);
    // Meshes whose geometry is animated in place (the flag cloth) keep it,
    // with their own copy of the material and no vertex colours.
    if (mesh.userData.keepGeometry) {
      mesh.material = material.clone();
      mesh.material.vertexColors = false;
      return;
    }
    const glassy = material.transparent || material.emissive.getHex() !== 0;
    let g = mesh.geometry.index ? mesh.geometry.toNonIndexed() : mesh.geometry.clone();
    for (const name of Object.keys(g.attributes)) if (name !== 'position' && name !== 'normal') g.deleteAttribute(name);
    if (!glassy) g = tessellate(g, maxEdge);
    const pos = g.attributes.position;
    const colors = new Float32Array(pos.count * 3);
    const metal = material.metalness > 0.4;
    for (let i = 0; i < pos.count; i++) {
      world.fromBufferAttribute(pos, i).applyMatrix4(mesh.matrixWorld);
      const y = world.y - box.min.y;
      let k = 1;
      // Fine grain.
      k -= GRIT.grain * hash3(Math.floor((world.x + off) * grainScale * 3), Math.floor(world.y * grainScale * 3), Math.floor(world.z * grainScale * 3));
      // Dirt blotches.
      const blotch = noise3((world.x + off) * grainScale * 0.35, world.y * grainScale * 0.35, world.z * grainScale * 0.35);
      k -= GRIT.blotch * Math.max(0, blotch - 0.3) / 0.7;
      // Dark band of soil near the ground.
      k -= GRIT.groundDirt * Math.exp(-y / (height * 0.18 + 0.2));
      // Run-off streaks on tall things.
      if (height > 4) {
        const streak = noise3((world.x + off) * grainScale * 1.2, 0.3, world.z * grainScale * 1.2);
        k -= GRIT.streak * Math.max(0, streak - 0.55) * 2.2 * (1 - y / height);
      }
      if (glassy) k = 1 - (1 - k) * 0.35;
      k = THREE.MathUtils.clamp(k, 0.25, 1);
      col.setRGB(k, k, k);
      // Rust patches on metal.
      if (metal) {
        const rust = noise3((world.x + off) * grainScale * 0.6 + 40, world.y * grainScale * 0.6, world.z * grainScale * 0.6);
        const amt = THREE.MathUtils.clamp((rust - 0.5) * 3, 0, 0.85);
        col.lerp(GRIT.rust.clone().multiplyScalar(k), amt);
      }
      colors[i * 3] = col.r;
      colors[i * 3 + 1] = col.g;
      colors[i * 3 + 2] = col.b;
    }
    g.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    g.setAttribute('uv', boxUVs(g, mesh.matrixWorld));
    mesh.geometry = g;
  });
  return root;
}
