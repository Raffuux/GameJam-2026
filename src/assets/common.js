// Shared helpers for the procedural low-poly assets.
// Scale convention: 1 unit = 1 cm. The player spider is about 1 unit long.
import * as THREE from 'three';

// Saturated "backyard" palette, Grounded style.
export const PALETTE = {
  grass: 0x5fa83a,
  grassDark: 0x3f7f2a,
  grassDry: 0xa9a24a,
  clover: 0x4f9a3c,
  stem: 0x6b9a3a,
  dandelion: 0xf5c518,
  mushroomCap: 0xc8372d,
  mushroomStem: 0xf1e6cf,
  rock: 0x8d8a83,
  rockDark: 0x6c6964,
  bark: 0x6b4a2f,
  leafDry: 0xc07a2c,
  leafDryDark: 0x8f5420,
  acorn: 0xa86a32,
  acornCap: 0x7a5a36,
  canRed: 0xd8262f,
  metal: 0xc9ccd1,
  pencil: 0xf2b705,
  wood: 0xe8c48e,
  graphite: 0x3a3a3f,
  eraser: 0xee8fa0,
  copper: 0xc27a42,
  toyRed: 0xe0322b,
  clip: 0xb8bfc8,
  black: 0x1d1b1a,
  chitinDark: 0x2a2622,
  flyBody: 0x3b3f36,
  flyEye: 0xa3241d,
  mantis: 0x8cc63f,
  mantisDark: 0x5f9a2c,
  ant: 0x3a1f17,
  ladybug: 0xd42b22,
  beetle: 0x2f4a6b,
  beeYellow: 0xf2b21b,
  caterpillar: 0x7cc242,
  caterpillarBand: 0xf4d23c,
  spider: 0x4a3426,
  white: 0xf4f1ea,
  wing: 0xdfeff7,
};

const matCache = new Map();

// Flat-shaded standard material, cached by color + options.
export function mat(color, opts = {}) {
  const key = color + JSON.stringify(opts);
  if (!matCache.has(key)) {
    const m = new THREE.MeshStandardMaterial({
      color,
      flatShading: true,
      roughness: 0.75,
      metalness: 0,
      ...opts,
    });
    matCache.set(key, m);
  }
  return matCache.get(key);
}

export function wingMat() {
  return mat(PALETTE.wing, {
    transparent: true,
    opacity: 0.45,
    side: THREE.DoubleSide,
    roughness: 0.2,
    depthWrite: false,
  });
}

// Deterministic RNG so every asset variant is reproducible from a seed.
export function rng(seed = 1) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function mesh(geometry, material, { cast = true, receive = true } = {}) {
  const m = new THREE.Mesh(geometry, material);
  m.castShadow = cast;
  m.receiveShadow = receive;
  return m;
}

// Push every vertex of a non-indexed geometry by a noise value keyed on its
// position, so shared corners move together and the surface stays closed.
export function jitter(geometry, amount, seed = 1) {
  const pos = geometry.attributes.position;
  const offsets = new Map();
  const r = rng(seed);
  for (let i = 0; i < pos.count; i++) {
    const key = `${pos.getX(i).toFixed(3)},${pos.getY(i).toFixed(3)},${pos.getZ(i).toFixed(3)}`;
    if (!offsets.has(key)) {
      offsets.set(key, [(r() - 0.5) * amount, (r() - 0.5) * amount, (r() - 0.5) * amount]);
    }
    const [dx, dy, dz] = offsets.get(key);
    pos.setXYZ(i, pos.getX(i) + dx, pos.getY(i) + dy, pos.getZ(i) + dz);
  }
  pos.needsUpdate = true;
  geometry.computeVertexNormals();
  return geometry;
}

// Low-poly ellipsoid.
export function blob(rx, ry, rz, material, detail = 1) {
  const g = new THREE.IcosahedronGeometry(1, detail);
  g.scale(rx, ry, rz);
  return mesh(g, material);
}

// Tube following a list of [x, y, z] points.
export function tube(points, radius, material, segments = 8, radial = 5) {
  const curve = new THREE.CatmullRomCurve3(points.map((p) => new THREE.Vector3(...p)));
  return mesh(new THREE.TubeGeometry(curve, segments, radius, radial, false), material);
}

// Cylinder between two points.
export function segment(a, b, radius, material, radial = 5) {
  const va = new THREE.Vector3(...a);
  const vb = new THREE.Vector3(...b);
  const len = va.distanceTo(vb);
  const g = new THREE.CylinderGeometry(radius * 0.8, radius, len, radial, 1);
  g.translate(0, len / 2, 0);
  const m = mesh(g, material);
  m.position.copy(va);
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), vb.clone().sub(va).normalize());
  return m;
}

// Set a name and metadata every asset carries.
export function tag(object, id, { category, heightCm, animated = false } = {}) {
  object.name = id;
  object.userData.assetId = id;
  object.userData.category = category;
  object.userData.heightCm = heightCm;
  object.userData.animated = animated;
  return object;
}
