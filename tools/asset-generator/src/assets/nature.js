// Backyard vegetation and ground clutter, at spider scale (1 unit = 1 cm).
import * as THREE from 'three';
import { PALETTE, mat, rng, mesh, jitter, blob, tube, tag } from './common.js';

// One folded blade of grass: a tapering strip with a centre crease, bent forward.
function grassBladeGeometry(height, width, bend, segments = 6) {
  const positions = [];
  const level = (t) => {
    const y = height * t;
    const z = bend * t * t;
    const w = width * (1 - t * 0.92) * 0.5;
    const crease = w * 0.35;
    return [
      [-w, y, z],
      [0, y, z - crease],
      [w, y, z],
    ];
  };
  for (let i = 0; i < segments; i++) {
    const a = level(i / segments);
    const b = level((i + 1) / segments);
    for (let s = 0; s < 2; s++) {
      positions.push(...a[s], ...a[s + 1], ...b[s + 1]);
      positions.push(...a[s], ...b[s + 1], ...b[s]);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  g.computeVertexNormals();
  return g;
}

export function createGrassClump({ seed = 1, blades = 9, height = 22 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const colors = [PALETTE.grass, PALETTE.grassDark, PALETTE.grass, PALETTE.grassDry];
  for (let i = 0; i < blades; i++) {
    const h = height * (0.55 + r() * 0.6);
    const g = grassBladeGeometry(h, 1.2 + r() * 0.8, h * (0.15 + r() * 0.35));
    const blade = mesh(g, mat(colors[Math.floor(r() * colors.length)], { side: THREE.DoubleSide }));
    const angle = r() * Math.PI * 2;
    const dist = r() * 2.5;
    blade.position.set(Math.cos(angle) * dist, 0, Math.sin(angle) * dist);
    blade.rotation.y = r() * Math.PI * 2;
    group.add(blade);
  }
  return tag(group, 'grass_clump', { category: 'nature', heightCm: height });
}

function heartLeafShape(size) {
  const s = new THREE.Shape();
  s.moveTo(0, 0);
  s.bezierCurveTo(size * 0.6, size * 0.2, size * 0.9, size * 0.9, size * 0.45, size * 1.05);
  s.bezierCurveTo(size * 0.2, size * 1.1, 0, size * 0.9, 0, size * 0.75);
  s.bezierCurveTo(0, size * 0.9, -size * 0.2, size * 1.1, -size * 0.45, size * 1.05);
  s.bezierCurveTo(-size * 0.9, size * 0.9, -size * 0.6, size * 0.2, 0, 0);
  return s;
}

export function createClover({ seed = 2, height = 7 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const stemMat = mat(PALETTE.stem);
  const leafMat = mat(PALETTE.clover, { side: THREE.DoubleSide });
  const lean = (r() - 0.5) * 1.5;
  group.add(tube([[0, 0, 0], [lean * 0.5, height * 0.5, 0.3], [lean, height, 0]], 0.18, stemMat, 6, 4));
  const shape = heartLeafShape(2.4);
  for (let i = 0; i < 3; i++) {
    const g = new THREE.ShapeGeometry(shape, 4);
    g.rotateX(-Math.PI / 2 + 0.25);
    const leaf = mesh(g, leafMat);
    leaf.position.set(lean, height, 0);
    leaf.rotation.y = (i / 3) * Math.PI * 2 + r() * 0.2;
    group.add(leaf);
  }
  return tag(group, 'clover', { category: 'nature', heightCm: height });
}

export function createDandelion({ seed = 3, height = 26 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const bend = 1 + r() * 2;
  const top = [bend, height, 0];
  group.add(tube([[0, 0, 0], [bend * 0.2, height * 0.5, 0], top], 0.35, mat(PALETTE.stem), 10, 5));
  // Green sepals cup, then rings of yellow petals.
  const cup = mesh(new THREE.ConeGeometry(1.1, 1.4, 7), mat(PALETTE.grassDark));
  cup.rotation.x = Math.PI;
  cup.position.set(top[0], height + 0.4, 0);
  group.add(cup);
  const petalMat = mat(PALETTE.dandelion);
  for (let ring = 0; ring < 3; ring++) {
    const count = 14 - ring * 3;
    const len = 2.6 - ring * 0.6;
    for (let i = 0; i < count; i++) {
      const g = new THREE.BoxGeometry(0.45, 0.12, len);
      g.translate(0, 0, len / 2);
      const petal = mesh(g, petalMat);
      petal.position.set(top[0], height + 1 + ring * 0.25, 0);
      petal.rotation.y = (i / count) * Math.PI * 2 + ring * 0.3;
      petal.rotation.x = -0.25 - ring * 0.35;
      group.add(petal);
    }
  }
  // A few long jagged leaves at the base.
  for (let i = 0; i < 5; i++) {
    const g = grassBladeGeometry(9 + r() * 4, 2.2, 2, 5);
    const leaf = mesh(g, mat(PALETTE.grassDark, { side: THREE.DoubleSide }));
    leaf.rotation.order = 'YXZ';
    leaf.rotation.y = (i / 5) * Math.PI * 2;
    leaf.rotation.x = 1.2;
    group.add(leaf);
  }
  return tag(group, 'dandelion', { category: 'nature', heightCm: height + 2 });
}

export function createMushroom({ seed = 4, height = 9 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const profile = [
    [1.3, 0], [1.0, 0.6], [0.85, height * 0.5], [0.8, height * 0.95], [0, height],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  group.add(mesh(new THREE.LatheGeometry(profile, 9), mat(PALETTE.mushroomStem)));
  const capR = height * 0.55;
  const capG = new THREE.SphereGeometry(capR, 12, 6, 0, Math.PI * 2, 0, Math.PI / 2);
  capG.scale(1, 0.6, 1);
  const cap = mesh(capG, mat(PALETTE.mushroomCap));
  cap.position.y = height * 0.9;
  group.add(cap);
  const gills = mesh(new THREE.CircleGeometry(capR, 12), mat(PALETTE.mushroomStem, { side: THREE.DoubleSide }));
  gills.rotation.x = Math.PI / 2;
  gills.position.y = height * 0.9;
  group.add(gills);
  // White warts on the cap.
  const dotMat = mat(PALETTE.white);
  for (let i = 0; i < 9; i++) {
    const theta = r() * Math.PI * 2;
    const phi = 0.2 + r() * 1.1;
    const dot = blob(0.45 + r() * 0.3, 0.15, 0.45 + r() * 0.3, dotMat, 0);
    const n = new THREE.Vector3(Math.sin(phi) * Math.cos(theta), Math.cos(phi) * 0.6, Math.sin(phi) * Math.sin(theta));
    dot.position.set(n.x * capR, height * 0.9 + n.y * capR, n.z * capR);
    dot.lookAt(dot.position.clone().add(n));
    dot.rotateX(Math.PI / 2);
    group.add(dot);
  }
  return tag(group, 'mushroom', { category: 'nature', heightCm: height * 1.25 });
}

export function createPebble({ seed = 5, size } = {}) {
  const r = rng(seed);
  size ??= 1.5 + r() * 2.5;
  const g = new THREE.IcosahedronGeometry(size, 1);
  g.scale(1 + r() * 0.4, 0.55 + r() * 0.2, 0.9 + r() * 0.3);
  jitter(g, size * 0.3, seed);
  const pebble = mesh(g, mat(r() > 0.5 ? PALETTE.rock : PALETTE.rockDark));
  g.computeBoundingBox();
  pebble.position.y = -g.boundingBox.min.y * 0.8; // sunk a little into the soil
  pebble.rotation.y = r() * Math.PI;
  const group = new THREE.Group().add(pebble);
  return tag(group, 'pebble', { category: 'nature', heightCm: size * 1.2 });
}

export function createTwig({ seed = 6, length = 30 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const barkMat = mat(PALETTE.bark);
  const pts = [];
  for (let i = 0; i <= 5; i++) {
    pts.push([-length / 2 + (length * i) / 5, 0.8 + r() * 0.6, (r() - 0.5) * 2]);
  }
  group.add(tube(pts, 0.8, barkMat, 16, 6));
  // Two side branches.
  for (let i = 0; i < 2; i++) {
    const base = pts[1 + i * 2];
    const dir = i === 0 ? 1 : -1;
    const tip = [base[0] + 5 + r() * 3, base[1] + 0.5, base[2] + dir * (5 + r() * 3)];
    group.add(tube([base, [(base[0] + tip[0]) / 2, base[1] + 0.6, (base[2] + tip[2]) / 2], tip], 0.4, barkMat, 6, 5));
  }
  return tag(group, 'twig', { category: 'nature', heightCm: 2 });
}

export function createFallenLeaf({ seed = 7, length = 14 } = {}) {
  const r = rng(seed);
  const s = new THREE.Shape();
  const w = length * 0.42;
  s.moveTo(0, 0);
  s.bezierCurveTo(w, length * 0.15, w * 0.9, length * 0.75, 0, length);
  s.bezierCurveTo(-w * 0.9, length * 0.75, -w, length * 0.15, 0, 0);
  const g = new THREE.ShapeGeometry(s, 8);
  g.rotateX(-Math.PI / 2);
  // Curl the edges up and add some wave so it reads as dry.
  const pos = g.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    pos.setY(i, (x * x) / (w * 2.2) + Math.sin(z * 0.6 + seed) * 0.35 + 0.3);
  }
  g.computeVertexNormals();
  const group = new THREE.Group();
  group.add(mesh(g, mat(r() > 0.5 ? PALETTE.leafDry : PALETTE.leafDryDark, { side: THREE.DoubleSide })));
  group.add(tube([[0, 0.3, 0.5], [0, 0.4, -length * 0.5], [0, 0.6, -length * 1.02]], 0.18, mat(PALETTE.leafDryDark), 6, 4));
  group.rotation.y = r() * Math.PI * 2;
  return tag(new THREE.Group().add(group), 'fallen_leaf', { category: 'nature', heightCm: 2 });
}

export function createAcorn({ seed = 8, size = 2.5 } = {}) {
  const group = new THREE.Group();
  const nutProfile = [
    [0, 0], [size * 0.55, size * 0.25], [size * 0.85, size * 0.9], [size * 0.9, size * 1.5],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  const nut = mesh(new THREE.LatheGeometry(nutProfile, 10), mat(PALETTE.acorn, { roughness: 0.4 }));
  group.add(nut);
  const capG = new THREE.SphereGeometry(size * 0.98, 10, 5, 0, Math.PI * 2, 0, Math.PI / 2);
  capG.scale(1, 0.6, 1);
  const cap = mesh(jitter(capG.toNonIndexed(), size * 0.08, seed), mat(PALETTE.acornCap));
  cap.position.y = size * 1.4;
  group.add(cap);
  const stalk = mesh(new THREE.CylinderGeometry(0.12 * size, 0.15 * size, size * 0.5, 5), mat(PALETTE.bark));
  stalk.position.y = size * 2.1;
  group.add(stalk);
  // Lying on its side, like it fell from the oak.
  group.rotation.z = Math.PI / 2 - 0.15;
  group.position.y = size * 0.85;
  return tag(new THREE.Group().add(group), 'acorn', { category: 'nature', heightCm: size * 1.8 });
}
