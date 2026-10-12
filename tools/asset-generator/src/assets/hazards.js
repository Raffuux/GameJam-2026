// Dirty street props for the rough areas: fires, litter, spills and stains.
// Bug scale (1 unit = 1 cm). Fires carry an animated flame rig, rising smoke,
// embers and a point light (exported as KHR_lights_punctual for Godot).
import * as THREE from 'three';
import { PALETTE, mat, rng, mesh, blob, jitter, tag } from './common.js';
import { createTrashBin, createCrumpledPaper, createCigaretteButt } from './city.js';

// Frequencies are whole multiples of 1.5 rad/s so baked loops close cleanly.
const W = 1.5;

function flameMat(color) {
  return mat(color, { emissive: color, emissiveIntensity: 2.2, roughness: 1 });
}

// A cluster of flickering flame cones plus embers and smoke, rooted at y = 0.
function fireRig({ radius = 2, height = 5, seed = 1, smoke = 5 } = {}) {
  const r = rng(seed);
  const rig = new THREE.Group();
  const flames = [];
  const layers = [
    { color: 0xd8401a, scale: 1, count: 6 },
    { color: 0xf2851f, scale: 0.75, count: 5 },
    { color: 0xffd24a, scale: 0.45, count: 3 },
  ];
  for (const layer of layers) {
    for (let i = 0; i < layer.count; i++) {
      const g = new THREE.ConeGeometry(radius * 0.45 * layer.scale, height * layer.scale * (0.7 + r() * 0.5), 5);
      g.translate(0, (height * layer.scale) / 2, 0);
      const f = mesh(g, flameMat(layer.color), { cast: false, receive: false });
      const a = r() * Math.PI * 2;
      const d = radius * 0.55 * layer.scale * r();
      f.position.set(Math.cos(a) * d, 0, Math.sin(a) * d);
      f.rotation.set((r() - 0.5) * 0.3, r() * Math.PI, (r() - 0.5) * 0.3);
      rig.add(f);
      flames.push({ f, k: 2 + Math.floor(r() * 4), phase: r() * Math.PI * 2, base: f.rotation.z });
    }
  }
  const embers = [];
  const emberMat = flameMat(0xffa23a);
  for (let i = 0; i < 10; i++) {
    const e = blob(0.12, 0.12, 0.12, emberMat, 0);
    e.castShadow = false;
    rig.add(e);
    embers.push({ e, a: r() * Math.PI * 2, d: r() * radius, phase: r(), k: 1 + Math.floor(r() * 2) });
  }
  const puffs = [];
  const smokeMat = mat(0x3d3b38, { transparent: true, opacity: 0.45, depthWrite: false, roughness: 1 });
  for (let i = 0; i < smoke; i++) {
    const p = blob(1, 1, 1, smokeMat, 1);
    p.castShadow = false;
    rig.add(p);
    puffs.push({ p, phase: i / smoke, drift: r() * Math.PI * 2 });
  }
  const light = new THREE.PointLight(0xff8a3a, 120, radius * 18, 2);
  light.position.y = height * 0.5;
  light.name = 'fire_light';
  rig.add(light);
  const loop = (4 * Math.PI) / 3;
  const update = (t) => {
    for (const { f, k, phase, base } of flames) {
      const s = 0.8 + 0.25 * Math.sin(t * W * k + phase) + 0.1 * Math.sin(t * W * (k + 3) + phase * 2);
      f.scale.set(1 - (s - 1) * 0.4, s, 1 - (s - 1) * 0.4);
      f.rotation.z = base + 0.12 * Math.sin(t * W * (k + 1) + phase);
    }
    for (const { e, a, d, phase, k } of embers) {
      const u = ((t / loop) * k + phase) % 1;
      e.position.set(Math.cos(a) * d * (1 + u), height * (0.3 + u * 1.6), Math.sin(a) * d * (1 + u));
      e.scale.setScalar(1 - u);
    }
    for (const { p, phase, drift } of puffs) {
      const u = (t / loop + phase) % 1;
      p.position.set(Math.cos(drift) * u * radius * 1.5, height * (0.9 + u * 2.6), Math.sin(drift) * u * radius * 1.5);
      p.scale.setScalar(radius * (0.4 + u * 1.2) * (u < 0.1 ? u * 10 : 1));
    }
  };
  update(0);
  return { rig, update };
}

// Burning tin can brazier, ~8 cm: a rusty food can with vent holes and
// twigs blazing inside. Gang members warm their legs around it.
export function createFireCan({ seed = 31 } = {}) {
  const group = new THREE.Group();
  const tin = mat(0x8c8f93, { metalness: 0.6, roughness: 0.55 });
  const R = 3.6;
  const H = 7;
  const body = mesh(new THREE.CylinderGeometry(R, R, H, 16, 1, true), mat(0x8c8f93, { metalness: 0.6, roughness: 0.55, side: THREE.DoubleSide }));
  body.position.y = H / 2;
  group.add(body);
  const bottom = mesh(new THREE.CircleGeometry(R, 16), tin);
  bottom.rotation.x = -Math.PI / 2;
  bottom.position.y = 0.05;
  group.add(bottom);
  for (const y of [0.4, H - 0.3]) {
    const rib = mesh(new THREE.TorusGeometry(R, 0.15, 4, 18), tin);
    rib.rotation.x = Math.PI / 2;
    rib.position.y = y;
    group.add(rib);
  }
  // Punched vent holes glowing from the fire inside.
  const glow = flameMat(0xf2851f);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    const hole = mesh(new THREE.CircleGeometry(0.45, 6), glow, { cast: false });
    hole.position.set(Math.cos(a) * (R + 0.03), 1.6, Math.sin(a) * (R + 0.03));
    hole.lookAt(hole.position.clone().multiplyScalar(2));
    group.add(hole);
  }
  // Charred twigs poking out of the top.
  const char = mat(0x1e1814, { roughness: 1 });
  const r = rng(seed);
  for (let i = 0; i < 5; i++) {
    const stick = mesh(new THREE.CylinderGeometry(0.25, 0.3, 6, 5), char);
    stick.position.set((r() - 0.5) * 3, H - 1.2, (r() - 0.5) * 3);
    stick.rotation.set((r() - 0.5) * 1.2, 0, (r() - 0.5) * 1.2);
    group.add(stick);
  }
  const { rig, update } = fireRig({ radius: R * 0.8, height: 6, seed });
  rig.position.y = H - 0.6;
  group.add(rig);
  group.userData.update = update;
  return tag(group, 'fire_can', { category: 'hazard', heightCm: H + 6, animated: true });
}

// Small trash fire on the ground, ~10 cm wide: burning paper and twigs.
export function createTrashFire({ seed = 32 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const char = mat(0x1e1814, { roughness: 1 });
  const ash = mat(0x5e5a55, { roughness: 1 });
  const scorch = mesh(new THREE.CircleGeometry(7, 12), mat(0x14110e, { roughness: 1 }), { cast: false });
  scorch.rotation.x = -Math.PI / 2;
  scorch.position.y = 0.03;
  group.add(scorch);
  for (let i = 0; i < 9; i++) {
    const g = jitter(new THREE.IcosahedronGeometry(0.8 + r() * 1, 0), 0.5, seed + i);
    const lump = mesh(g, i % 3 ? char : ash);
    const a = r() * Math.PI * 2;
    const d = r() * 3.5;
    lump.position.set(Math.cos(a) * d, 0.5, Math.sin(a) * d);
    group.add(lump);
  }
  for (let i = 0; i < 6; i++) {
    const stick = mesh(new THREE.CylinderGeometry(0.2, 0.25, 6, 5), char);
    const a = (i / 6) * Math.PI * 2;
    stick.position.set(Math.cos(a) * 1.3, 1.6, Math.sin(a) * 1.3);
    stick.rotation.set(Math.sin(a) * 0.7, 0, -Math.cos(a) * 0.7);
    group.add(stick);
  }
  const { rig, update } = fireRig({ radius: 2.6, height: 7, seed, smoke: 6 });
  rig.position.y = 0.6;
  group.add(rig);
  group.userData.update = update;
  return tag(group, 'trash_fire', { category: 'hazard', heightCm: 8, animated: true });
}

// Flattened plastic wrapper.
function wrapper(r, color, size) {
  const g = new THREE.PlaneGeometry(size, size * 0.6, 4, 3);
  g.rotateX(-Math.PI / 2);
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) p.setY(i, r() * 0.4);
  g.computeVertexNormals();
  return mesh(g, mat(color, { side: THREE.DoubleSide, roughness: 0.4 }));
}

// Broken bottle glass shards.
function shard(r) {
  const g = new THREE.TetrahedronGeometry(0.5 + r() * 0.8, 0);
  g.scale(1, 0.25, 1.4);
  return mesh(g, mat(0x3e7d4a, { transparent: true, opacity: 0.7, roughness: 0.1, metalness: 0.1 }));
}

function stain(radius, color, r) {
  const shape = new THREE.Shape();
  const n = 12;
  for (let i = 0; i <= n; i++) {
    const a = (i / n) * Math.PI * 2;
    const d = radius * (0.65 + r() * 0.35);
    if (i === 0) shape.moveTo(Math.cos(a) * d, Math.sin(a) * d);
    else shape.lineTo(Math.cos(a) * d, Math.sin(a) * d);
  }
  const g = new THREE.ShapeGeometry(shape);
  g.rotateX(-Math.PI / 2);
  return mesh(g, mat(color, { roughness: 0.2, metalness: 0.15 }), { cast: false });
}

// A litter pile, ~25 cm across: wrappers, paper, butts, glass, caps, gum.
export function createLitterPile({ seed = 33 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const spot = () => {
    const a = r() * Math.PI * 2;
    const d = Math.sqrt(r()) * 12;
    return [Math.cos(a) * d, Math.sin(a) * d];
  };
  for (let i = 0; i < 4; i++) {
    const s = stain(2 + r() * 3, 0x2c241b, r);
    const [x, z] = spot();
    s.position.set(x, 0.02 + i * 0.002, z);
    group.add(s);
  }
  const wrapperColors = [0xc23b2e, 0x2f6fbf, 0xe0b23a, 0x6a2f8a, 0xf0efe8];
  for (let i = 0; i < 7; i++) {
    const w = wrapper(r, wrapperColors[i % wrapperColors.length], 3 + r() * 3);
    const [x, z] = spot();
    w.position.set(x, 0.05, z);
    w.rotation.y = r() * Math.PI;
    group.add(w);
  }
  for (let i = 0; i < 4; i++) {
    const p = createCrumpledPaper({ seed: seed + i });
    const [x, z] = spot();
    p.position.set(x, 0, z);
    p.scale.setScalar(0.6 + r() * 0.5);
    group.add(p);
  }
  for (let i = 0; i < 5; i++) {
    const c = createCigaretteButt();
    const [x, z] = spot();
    c.position.set(x, 0, z);
    c.rotation.y = r() * Math.PI * 2;
    group.add(c);
  }
  for (let i = 0; i < 6; i++) {
    const s = shard(r);
    const [x, z] = spot();
    s.position.set(x, 0.15, z);
    s.rotation.y = r() * Math.PI * 2;
    group.add(s);
  }
  for (let i = 0; i < 2; i++) {
    const gum = blob(0.9, 0.25, 0.8, mat(0xd77fa0, { roughness: 0.5 }), 1);
    const [x, z] = spot();
    gum.position.set(x, 0.15, z);
    group.add(gum);
  }
  return tag(group, 'litter_pile', { category: 'hazard', heightCm: 2.5 });
}

// Street bin knocked over, its garbage spilling across the sidewalk.
export function createSpilledBin({ seed = 34 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const bin = createTrashBin();
  bin.rotation.z = Math.PI / 2;
  bin.position.set(-1.2, 1.15, 0);
  group.add(bin);
  const juice = stain(4, 0x3b3216, r);
  juice.scale.set(1.6, 1, 1);
  juice.position.set(3.5, 0.03, 0);
  group.add(juice);
  for (let i = 0; i < 6; i++) {
    const p = createCrumpledPaper({ seed: seed + i });
    p.scale.setScalar(0.35 + r() * 0.3);
    p.position.set(1.5 + r() * 6, 0, (r() - 0.5) * 4);
    group.add(p);
  }
  for (let i = 0; i < 4; i++) {
    const w = wrapper(r, [0xc23b2e, 0xe0b23a, 0xf0efe8][i % 3], 1.5 + r());
    w.position.set(2 + r() * 6, 0.05, (r() - 0.5) * 5);
    w.rotation.y = r() * Math.PI;
    group.add(w);
  }
  // Rotting peel and a fish bone.
  const peel = blob(1, 0.2, 0.5, mat(0x6b5a1e, { roughness: 0.8 }), 1);
  peel.position.set(5, 0.2, 1.4);
  group.add(peel);
  const bone = mat(0xe8e2d0);
  const spine = mesh(new THREE.CylinderGeometry(0.06, 0.06, 3, 4), bone);
  spine.rotation.z = Math.PI / 2;
  spine.position.set(6.5, 0.1, -1.2);
  group.add(spine);
  for (let i = 0; i < 6; i++) {
    const rib = mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.9, 3), bone);
    rib.rotation.x = Math.PI / 2;
    rib.position.set(5.4 + i * 0.4, 0.1, -1.2);
    group.add(rib);
  }
  return tag(group, 'spilled_bin', { category: 'hazard', heightCm: 2.6 });
}

// Oil stain on the asphalt, ~15 cm: a glossy black puddle with drips.
export function createOilStain({ seed = 35 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const main = stain(7, 0x0e0d0c, r);
  main.material = mat(0x0e0d0c, { roughness: 0.08, metalness: 0.4 });
  main.position.y = 0.02;
  group.add(main);
  for (let i = 0; i < 6; i++) {
    const d = stain(0.6 + r() * 1.2, 0x0e0d0c, r);
    d.material = main.material;
    const a = r() * Math.PI * 2;
    d.position.set(Math.cos(a) * (7 + r() * 4), 0.02, Math.sin(a) * (7 + r() * 4));
    group.add(d);
  }
  return tag(group, 'oil_stain', { category: 'hazard', heightCm: 0.05 });
}

// What's left after a fire: charred lumps, ash and a few dying embers.
export function createBurntTrash({ seed = 36 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const scorch = stain(9, 0x15110d, r);
  scorch.material = mat(0x15110d, { roughness: 1 });
  scorch.position.y = 0.02;
  group.add(scorch);
  const char = mat(0x1c1714, { roughness: 1 });
  const ash = mat(0x77716a, { roughness: 1 });
  for (let i = 0; i < 14; i++) {
    const g = jitter(new THREE.IcosahedronGeometry(0.6 + r() * 1.4, 0), 0.6, seed + i);
    g.scale(1, 0.6, 1);
    const lump = mesh(g, r() > 0.35 ? char : ash);
    const a = r() * Math.PI * 2;
    const d = Math.sqrt(r()) * 6;
    lump.position.set(Math.cos(a) * d, 0.4, Math.sin(a) * d);
    group.add(lump);
  }
  const ember = flameMat(0xe0561c);
  for (let i = 0; i < 7; i++) {
    const e = blob(0.25, 0.15, 0.25, ember, 0);
    const a = r() * Math.PI * 2;
    const d = Math.sqrt(r()) * 4;
    e.position.set(Math.cos(a) * d, 0.5, Math.sin(a) * d);
    e.castShadow = false;
    group.add(e);
  }
  // A half-burnt can lying in the ashes.
  const can = mesh(new THREE.CylinderGeometry(1.6, 1.6, 5, 12, 1, true), mat(0x4a4038, { metalness: 0.5, roughness: 0.7, side: THREE.DoubleSide }));
  can.rotation.z = Math.PI / 2;
  can.position.set(3, 1.6, -2);
  group.add(can);
  return tag(group, 'burnt_trash', { category: 'hazard', heightCm: 3 });
}

