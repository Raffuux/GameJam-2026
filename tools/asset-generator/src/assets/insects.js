// Low-poly bugs that live in the yard, with a procedural walk cycle.
// Every creature faces +Z, stands on y = 0 and is sized in cm (1 unit = 1 cm).
// Animated ones expose `object.userData.update(timeSeconds, speed)`; call it
// every frame (speed 0 = idle, 1 = normal walk).
import * as THREE from 'three';
import { PALETTE, mat, mesh, blob, segment, tube, wingMat, tag } from './common.js';

// Adds jointed legs to `root` and returns an update(t, speed) for a tripod gait.
// Each spec: { y, z, x, reach, spread } where spread > 0 points the leg forward.
// Leg thickness multiplier for the chunky pixel-art style.
const LEG_CHUNK = 1.8;

function addLegs(root, specs, { radius, material, lift = 0.35, swing = 0.35 }) {
  const legs = [];
  specs.forEach((spec, index) => {
    for (const side of [1, -1]) {
      const hip = new THREE.Group();
      hip.position.set(side * (spec.x ?? 0), spec.y, spec.z);
      const baseYaw = -side * spec.spread;
      hip.rotation.y = baseYaw;
      const knee = [side * spec.reach * 0.45, spec.reach * 0.35, 0];
      const foot = [side * spec.reach, -spec.y, 0];
      // Chunky legs like the jumping spider: thick round segments with knobbly joints.
      const r = radius * LEG_CHUNK;
      const upper = segment([0, 0, 0], knee, r, material, 10);
      const lower = segment(knee, foot, r * 0.8, material, 10);
      upper.userData.limb = lower.userData.limb = true;
      const joint = blob(r * 0.95, r * 0.95, r * 0.95, material, 2);
      joint.position.set(...knee);
      const toe = blob(r * 0.7, r * 0.7, r * 0.7, material, 2);
      toe.position.set(...foot);
      hip.add(upper, lower, joint, toe);
      root.add(hip);
      legs.push({ hip, side, baseYaw, phase: ((index + (side > 0 ? 1 : 0)) % 2) * Math.PI });
    }
  });
  return (t, speed) => {
    for (const leg of legs) {
      const p = t * 9 * speed + leg.phase;
      leg.hip.rotation.y = leg.baseYaw + Math.sin(p) * swing * speed * leg.side;
      leg.hip.rotation.z = leg.side * Math.max(0, Math.cos(p)) * lift * speed;
    }
  };
}

function addEyes(root, { x, y, z, r, color = PALETTE.black }) {
  const eyeMat = mat(color, { roughness: 0.2 });
  for (const side of [1, -1]) {
    const eye = blob(r, r, r, eyeMat);
    eye.position.set(side * x, y, z);
    root.add(eye);
  }
}

function addAntennae(root, { x, y, z, length, elbow = false, material }) {
  const parts = [];
  for (const side of [1, -1]) {
    const pts = elbow
      ? [[side * x, y, z], [side * (x + length * 0.15), y + length * 0.45, z + length * 0.1], [side * (x + length * 0.35), y + length * 0.5, z + length * 0.6]]
      : [[side * x, y, z], [side * (x + length * 0.2), y + length * 0.5, z + length * 0.4], [side * (x + length * 0.45), y + length * 0.7, z + length * 0.8]];
    const a = tube(pts, length * 0.025, material, 6, 3);
    root.add(a);
    parts.push(a);
  }
  return parts;
}

function wing(length, width) {
  const s = new THREE.Shape();
  s.moveTo(0, 0);
  s.bezierCurveTo(width, length * 0.2, width * 0.9, length, 0, length);
  s.bezierCurveTo(-width * 0.4, length * 0.8, -width * 0.3, length * 0.2, 0, 0);
  const g = new THREE.ShapeGeometry(s, 6);
  g.rotateX(-Math.PI / 2);
  return mesh(g, wingMat(), { cast: false, receive: false });
}

// House fly, ~1 cm. Wings buzz, legs walk.
export function createFly() {
  const root = new THREE.Group();
  const body = mat(PALETTE.flyBody, { roughness: 0.4, metalness: 0.2 });
  const thorax = blob(0.22, 0.2, 0.24, body);
  thorax.position.set(0, 0.45, 0.08);
  const abdomen = blob(0.2, 0.17, 0.32, body);
  abdomen.position.set(0, 0.42, -0.32);
  const head = blob(0.17, 0.15, 0.13, body);
  head.position.set(0, 0.48, 0.36);
  root.add(thorax, abdomen, head);
  addEyes(root, { x: 0.11, y: 0.52, z: 0.4, r: 0.11, color: PALETTE.flyEye });
  const wings = [];
  for (const side of [1, -1]) {
    const w = wing(0.75, 0.3 * side);
    const pivot = new THREE.Group();
    pivot.position.set(side * 0.08, 0.64, 0.12);
    w.rotation.y = Math.PI + side * 0.35;
    pivot.add(w);
    root.add(pivot);
    wings.push({ pivot, side });
  }
  const walk = addLegs(root, [
    { y: 0.38, z: 0.18, x: 0.1, reach: 0.45, spread: 0.6 },
    { y: 0.38, z: 0.08, x: 0.12, reach: 0.5, spread: 0 },
    { y: 0.38, z: -0.02, x: 0.1, reach: 0.5, spread: -0.6 },
  ], { radius: 0.02, material: mat(PALETTE.black) });
  root.userData.update = (t, speed = 1) => {
    walk(t, speed);
    for (const { pivot, side } of wings) pivot.rotation.z = side * Math.sin(t * 60) * 0.35 * (speed > 0 ? 1 : 0.15);
  };
  root.userData.anchors = {
    neck: { position: [0, 0.47, 0.25], radius: 0.17 },
    head: { position: [0, 0.54, 0.33], radii: [0.15, 0.11, 0.14] },
    back: { position: [0, 0.6, -0.32], size: 0.2 },
  };
  return tag(root, 'fly', { category: 'insect', heightCm: 0.7, animated: true });
}

// Praying mantis, ~7 cm. The big predator of the garden.
export function createMantis() {
  const root = new THREE.Group();
  const green = mat(PALETTE.mantis);
  const dark = mat(PALETTE.mantisDark);
  const abdomen = blob(0.55, 0.42, 2.1, green);
  abdomen.position.set(0, 1.35, -1.4);
  abdomen.rotation.x = -0.12;
  const wings = blob(0.5, 0.18, 1.9, dark);
  wings.position.set(0, 1.75, -1.3);
  wings.rotation.x = -0.12;
  const pronotumPivot = new THREE.Group();
  pronotumPivot.position.set(0, 1.5, 0.4);
  pronotumPivot.rotation.x = -0.75;
  const pronotum = segment([0, 0, 0], [0, 0, 2.2], 0.22, green, 6);
  pronotumPivot.add(pronotum);
  // Triangular head, swivels.
  const head = new THREE.Group();
  head.position.set(0, 0, 2.35);
  const skull = mesh(new THREE.ConeGeometry(0.42, 0.7, 3), green);
  skull.rotation.x = Math.PI / 2 + 0.75;
  skull.rotation.y = Math.PI;
  head.add(skull);
  addEyes(head, { x: 0.36, y: 0.12, z: 0.05, r: 0.18, color: PALETTE.mantisDark });
  addAntennae(head, { x: 0.08, y: 0.2, z: 0.1, length: 2, material: dark });
  pronotumPivot.name = 'mantis_pronotum';
  head.name = 'mantis_head';
  pronotumPivot.add(head);
  // Raptorial forelegs, folded in prayer.
  const arms = [];
  for (const side of [1, -1]) {
    const arm = new THREE.Group();
    arm.position.set(side * 0.18, 0, 1.9);
    arm.add(segment([0, 0, 0], [side * 0.15, -0.6, 0.5], 0.12, green));
    arm.add(segment([side * 0.15, -0.6, 0.5], [side * 0.18, 0.4, 1.0], 0.14, green));
    arm.add(segment([side * 0.18, 0.4, 1.0], [side * 0.15, -0.5, 0.95], 0.08, dark));
    pronotumPivot.add(arm);
    arms.push({ arm, side });
  }
  root.add(abdomen, wings, pronotumPivot);
  const walk = addLegs(root, [
    { y: 1.45, z: 0.25, x: 0.2, reach: 2.6, spread: 0.35 },
    { y: 1.4, z: -0.15, x: 0.2, reach: 3.0, spread: -0.55 },
  ], { radius: 0.07, material: green, lift: 0.25, swing: 0.25 });
  root.userData.update = (t, speed = 1) => {
    walk(t, speed * 0.6);
    head.rotation.y = Math.sin(t * 0.7) * 0.5;
    pronotumPivot.rotation.z = Math.sin(t * 1.3) * 0.06;
    for (const { arm, side } of arms) arm.rotation.x = Math.sin(t * 2 + side) * 0.05;
  };
  root.userData.anchors = {
    neck: { parent: 'mantis_pronotum', position: [0, 0, 2.0], radius: 0.3 },
    head: { parent: 'mantis_head', position: [0, 0.2, 0.05], radii: [0.36, 0.2, 0.3], tilt: 0.75 },
    back: { position: [0, 1.95, -0.9], size: 0.55, tilt: -0.12 },
  };
  return tag(root, 'mantis', { category: 'insect', heightCm: 3.8, animated: true });
}

// Worker ant, ~1 cm. Ants come in columns, great for traffic.
export function createAnt({ color = PALETTE.ant } = {}) {
  const root = new THREE.Group();
  const body = mat(color, { roughness: 0.65 });
  const gaster = blob(0.22, 0.2, 0.3, body);
  gaster.position.set(0, 0.32, -0.42);
  const petiole = blob(0.06, 0.08, 0.06, body, 0);
  petiole.position.set(0, 0.32, -0.12);
  const thorax = blob(0.1, 0.1, 0.22, body);
  thorax.position.set(0, 0.33, 0.06);
  const head = blob(0.15, 0.13, 0.15, body);
  head.position.set(0, 0.37, 0.36);
  root.add(gaster, petiole, thorax, head);
  addEyes(root, { x: 0.12, y: 0.41, z: 0.4, r: 0.04 });
  const mandMat = mat(PALETTE.black);
  for (const side of [1, -1]) {
    const m = segment([side * 0.05, 0.31, 0.48], [side * 0.01, 0.3, 0.6], 0.025, mandMat, 4);
    root.add(m);
  }
  addAntennae(root, { x: 0.05, y: 0.45, z: 0.44, length: 0.55, elbow: true, material: body });
  const walk = addLegs(root, [
    { y: 0.3, z: 0.14, x: 0.06, reach: 0.5, spread: 0.6 },
    { y: 0.3, z: 0.06, x: 0.07, reach: 0.55, spread: 0 },
    { y: 0.3, z: -0.02, x: 0.06, reach: 0.6, spread: -0.6 },
  ], { radius: 0.025, material: body });
  root.userData.update = (t, speed = 1) => walk(t, speed * 1.4);
  root.userData.anchors = {
    neck: { position: [0, 0.36, 0.23], radius: 0.1 },
    head: { position: [0, 0.42, 0.34], radii: [0.14, 0.09, 0.14] },
    back: { position: [0, 0.53, -0.42], size: 0.16 },
  };
  return tag(root, 'ant', { category: 'insect', heightCm: 0.5, animated: true });
}

// Ladybug, ~0.8 cm. A cute little "car" of the garden.
export function createLadybug() {
  const root = new THREE.Group();
  const shellG = new THREE.SphereGeometry(0.45, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2);
  shellG.scale(0.9, 0.8, 1.05);
  const shell = mesh(shellG, mat(PALETTE.ladybug, { roughness: 0.25 }));
  shell.position.y = 0.15;
  root.add(shell);
  const spotMat = mat(PALETTE.black, { roughness: 0.8 });
  const spots = [[0, 0.35, 0.2], [0.2, 0.25, 0.25], [-0.2, 0.25, 0.25], [0.22, 0.28, -0.12], [-0.22, 0.28, -0.12], [0.1, 0.2, -0.35], [-0.1, 0.2, -0.35]];
  for (const [x, y, z] of spots) {
    const n = new THREE.Vector3(x / 0.9, y / 0.8, z / 1.05).normalize();
    const spot = blob(0.07, 0.02, 0.07, spotMat, 0);
    spot.position.set(n.x * 0.405, 0.15 + n.y * 0.36, n.z * 0.4725);
    spot.lookAt(spot.position.clone().add(n));
    spot.rotateX(Math.PI / 2);
    root.add(spot);
  }
  const line = mesh(new THREE.BoxGeometry(0.015, 0.02, 0.9), spotMat);
  line.position.set(0, 0.51, 0);
  root.add(line);
  const head = blob(0.2, 0.14, 0.13, spotMat);
  head.position.set(0, 0.2, 0.47);
  root.add(head);
  const cheekMat = mat(PALETTE.white);
  for (const side of [1, -1]) {
    const cheek = blob(0.06, 0.04, 0.04, cheekMat, 0);
    cheek.position.set(side * 0.11, 0.26, 0.54);
    root.add(cheek);
  }
  const walk = addLegs(root, [
    { y: 0.15, z: 0.2, x: 0.15, reach: 0.3, spread: 0.6 },
    { y: 0.15, z: 0.02, x: 0.17, reach: 0.32, spread: 0 },
    { y: 0.15, z: -0.16, x: 0.15, reach: 0.32, spread: -0.6 },
  ], { radius: 0.025, material: spotMat, lift: 0.25 });
  root.userData.update = (t, speed = 1) => walk(t, speed);
  return tag(root, 'ladybug', { category: 'insect', heightCm: 0.55, animated: true });
}

// Rhinoceros beetle, ~5 cm. Heavy, slow: a ride or a truck.
export function createBeetle() {
  const root = new THREE.Group();
  const shell = mat(PALETTE.beetle, { roughness: 0.2, metalness: 0.5 });
  const dark = mat(PALETTE.chitinDark, { roughness: 0.35 });
  const elytraG = new THREE.SphereGeometry(1.3, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2);
  elytraG.scale(0.95, 0.75, 1.45);
  const elytra = mesh(elytraG, shell);
  elytra.position.set(0, 0.55, -0.5);
  root.add(elytra);
  const under = blob(1.15, 0.35, 1.7, dark);
  under.position.set(0, 0.6, -0.5);
  root.add(under);
  const pronotum = blob(1.0, 0.7, 0.75, shell);
  pronotum.position.set(0, 0.9, 1.2);
  root.add(pronotum);
  const head = blob(0.45, 0.35, 0.4, dark);
  head.position.set(0, 0.7, 1.95);
  root.add(head);
  root.add(tube([[0, 0.8, 2.1], [0, 1.4, 2.6], [0, 2.3, 2.7], [0, 2.7, 2.4]], 0.13, dark, 10, 5));
  root.add(tube([[0, 1.4, 1.5], [0, 1.6, 1.9], [0, 1.55, 2.2]], 0.1, dark, 6, 5));
  addEyes(root, { x: 0.35, y: 0.78, z: 2.05, r: 0.08 });
  const walk = addLegs(root, [
    { y: 0.6, z: 1.3, x: 0.5, reach: 1.4, spread: 0.6 },
    { y: 0.55, z: 0.3, x: 0.7, reach: 1.5, spread: -0.1 },
    { y: 0.55, z: -0.6, x: 0.7, reach: 1.6, spread: -0.7 },
  ], { radius: 0.12, material: dark, lift: 0.25, swing: 0.25 });
  root.userData.update = (t, speed = 1) => walk(t, speed * 0.5);
  return tag(root, 'beetle', { category: 'insect', heightCm: 2.7, animated: true });
}

// Honey bee, ~1.3 cm. Hovers between flowers.
export function createBee() {
  const root = new THREE.Group();
  const body = new THREE.Group();
  body.position.y = 0.55;
  root.add(body);
  const yellow = mat(PALETTE.beeYellow, { roughness: 0.6 });
  const black = mat(PALETTE.black, { roughness: 0.6 });
  const thorax = blob(0.26, 0.25, 0.26, mat(0x8a5a1f, { roughness: 0.9 }));
  thorax.position.z = 0.1;
  body.add(thorax);
  // Striped abdomen built from alternating rings.
  const bands = 6;
  for (let i = 0; i < bands; i++) {
    const t = i / (bands - 1);
    const r = 0.3 * Math.sin(Math.PI * (0.15 + t * 0.75)) + 0.04;
    const ring = mesh(new THREE.CylinderGeometry(r, r, 0.13, 10), i % 2 ? black : yellow);
    ring.rotation.x = Math.PI / 2;
    ring.position.z = -0.2 - i * 0.12;
    body.add(ring);
  }
  const sting = mesh(new THREE.ConeGeometry(0.03, 0.12, 4), black);
  sting.rotation.x = -Math.PI / 2;
  sting.position.z = -0.95;
  body.add(sting);
  const head = blob(0.19, 0.18, 0.13, black);
  head.position.z = 0.42;
  body.add(head);
  addEyes(body, { x: 0.14, y: 0.04, z: 0.43, r: 0.08 });
  addAntennae(body, { x: 0.04, y: 0.1, z: 0.52, length: 0.4, elbow: true, material: black });
  const wings = [];
  for (const side of [1, -1]) {
    const w = wing(0.8, 0.28 * side);
    const pivot = new THREE.Group();
    pivot.position.set(side * 0.12, 0.22, 0.15);
    w.rotation.y = Math.PI + side * 0.6;
    pivot.add(w);
    body.add(pivot);
    wings.push({ pivot, side });
  }
  addLegs(body, [
    { y: -0.12, z: 0.18, x: 0.1, reach: 0.35, spread: 0.4 },
    { y: -0.12, z: 0.08, x: 0.12, reach: 0.4, spread: 0 },
    { y: -0.12, z: -0.02, x: 0.1, reach: 0.45, spread: -0.5 },
  ], { radius: 0.03, material: black });
  root.userData.update = (t) => {
    body.position.y = 0.9 + Math.sin(t * 2.2) * 0.15;
    body.rotation.x = Math.sin(t * 1.4) * 0.08;
    for (const { pivot, side } of wings) pivot.rotation.z = side * Math.sin(t * 70) * 0.5;
  };
  return tag(root, 'bee', { category: 'insect', heightCm: 1.2, animated: true });
}

// Caterpillar, ~5 cm. Slow crawler; a living bus line.
export function createCaterpillar({ segments = 11 } = {}) {
  const root = new THREE.Group();
  const green = mat(PALETTE.caterpillar, { roughness: 0.6 });
  const band = mat(PALETTE.caterpillarBand, { roughness: 0.6 });
  const black = mat(PALETTE.black);
  const parts = [];
  for (let i = 0; i < segments; i++) {
    const r = i === 0 ? 0.42 : 0.36 + Math.sin((i / segments) * Math.PI) * 0.08;
    const seg = blob(r, r, r * 0.9, i % 3 === 1 ? band : green);
    seg.position.set(0, r, 2.5 - i * 0.55);
    root.add(seg);
    // Stubby prolegs on most segments.
    if (i > 2 && i < segments - 1) {
      for (const side of [1, -1]) {
        const leg = blob(0.08, 0.1, 0.08, green, 0);
        leg.position.set(side * r * 0.6, -r * 0.85, 0);
        seg.add(leg);
      }
    }
    parts.push({ seg, r });
  }
  const head = parts[0].seg;
  addEyes(head, { x: 0.2, y: 0.12, z: 0.3, r: 0.07 });
  for (const side of [1, -1]) {
    head.add(segment([side * 0.15, 0.3, 0.1], [side * 0.25, 0.65, 0.25], 0.03, black, 3));
  }
  root.userData.update = (t, speed = 1) => {
    parts.forEach(({ seg, r }, i) => {
      const wave = Math.max(0, Math.sin(t * 3 * speed - i * 0.7));
      seg.position.y = r + wave * 0.25 * speed;
    });
  };
  return tag(root, 'caterpillar', { category: 'insect', heightCm: 0.9, animated: true });
}

// Garden spider, ~1.3 cm body. NPC spiders (and a base for the player model).
export function createSpider({ color = PALETTE.spider } = {}) {
  const root = new THREE.Group();
  const body = mat(color, { roughness: 0.7 });
  const dark = mat(PALETTE.black, { roughness: 0.4 });
  const cephalo = blob(0.33, 0.24, 0.38, body);
  cephalo.position.set(0, 0.42, 0.22);
  const abdomen = blob(0.5, 0.42, 0.6, body);
  abdomen.position.set(0, 0.58, -0.55);
  abdomen.rotation.x = 0.2;
  root.add(cephalo, abdomen);
  // Eight eyes: two big front ones, six small around.
  const eyes = [[0.08, 0.55, 0.55, 0.06], [-0.08, 0.55, 0.55, 0.06], [0.17, 0.56, 0.47, 0.035], [-0.17, 0.56, 0.47, 0.035],
    [0.1, 0.62, 0.45, 0.03], [-0.1, 0.62, 0.45, 0.03], [0.2, 0.52, 0.42, 0.03], [-0.2, 0.52, 0.42, 0.03]];
  for (const [x, y, z, r] of eyes) {
    const eye = blob(r, r, r, dark, 0);
    eye.position.set(x, y, z);
    root.add(eye);
  }
  for (const side of [1, -1]) {
    root.add(segment([side * 0.07, 0.36, 0.52], [side * 0.06, 0.18, 0.62], 0.05, body, 4));
    root.add(segment([side * 0.15, 0.38, 0.5], [side * 0.25, 0.25, 0.8], 0.04, body, 4));
  }
  const walk = addLegs(root, [
    { y: 0.4, z: 0.42, x: 0.2, reach: 1.25, spread: 0.9 },
    { y: 0.4, z: 0.28, x: 0.26, reach: 1.15, spread: 0.3 },
    { y: 0.4, z: 0.12, x: 0.26, reach: 1.05, spread: -0.25 },
    { y: 0.4, z: 0.0, x: 0.22, reach: 1.2, spread: -0.8 },
  ], { radius: 0.045, material: body, lift: 0.3, swing: 0.25 });
  root.userData.update = (t, speed = 1) => walk(t, speed);
  root.userData.anchors = {
    neck: { position: [0, 0.48, -0.08], radius: 0.26 },
    head: { position: [0, 0.54, 0.14], radii: [0.3, 0.16, 0.3] },
    back: { position: [0, 0.98, -0.5], size: 0.42, tilt: 0.2 },
  };
  return tag(root, 'spider', { category: 'insect', heightCm: 1, animated: true });
}
