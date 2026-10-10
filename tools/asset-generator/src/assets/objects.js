// Everyday human objects dropped in the yard, at real size (1 unit = 1 cm).
// To a spider these are buildings, bridges and landmarks.
import * as THREE from 'three';
import { PALETTE, mat, mesh, tube, tag } from './common.js';

// 33 cl can: 11.5 cm tall, 6.6 cm wide. Lying on its side it is a tunnel-house.
export function createSodaCan({ lying = false } = {}) {
  const group = new THREE.Group();
  const r = 3.3;
  const h = 11.5;
  const body = mesh(new THREE.CylinderGeometry(r * 1.01, r * 1.01, h * 0.76, 18), mat(PALETTE.canRed, { roughness: 0.4 }));
  body.position.y = h * 0.5;
  group.add(body);
  const band = mesh(new THREE.CylinderGeometry(r * 1.02, r * 1.02, 1.4, 18), mat(PALETTE.white, { roughness: 0.4 }));
  band.position.y = h * 0.55;
  group.add(band);
  const metal = mat(PALETTE.metal, { roughness: 0.25, metalness: 0.8 });
  const neckProfile = [
    [r * 0.82, 0], [r * 0.95, 0.4], [r, h * 0.11], [r, h * 0.89], [r * 0.82, h * 0.98], [r * 0.82, h], [0, h * 0.985],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  group.add(mesh(new THREE.LatheGeometry(neckProfile, 18), metal));
  const tab = mesh(new THREE.TorusGeometry(0.7, 0.18, 4, 10), metal);
  tab.rotation.x = Math.PI / 2;
  tab.scale.set(1, 1.6, 1);
  tab.position.set(0, h + 0.05, 0.9);
  group.add(tab);
  if (lying) {
    group.rotation.z = Math.PI / 2;
    group.position.set(h / 2, r, 0);
    return tag(new THREE.Group().add(group), 'soda_can_lying', { category: 'object', heightCm: r * 2 });
  }
  return tag(group, 'soda_can', { category: 'object', heightCm: h });
}

// Crown bottle cap, upside down: a small pool or a shield.
export function createBottleCap() {
  const group = new THREE.Group();
  const r = 1.6;
  const capMat = mat(PALETTE.canRed, { roughness: 0.35, metalness: 0.4 });
  const top = mesh(new THREE.CylinderGeometry(r, r, 0.15, 21), mat(PALETTE.metal, { metalness: 0.7, roughness: 0.3 }));
  top.position.y = 0.08;
  group.add(top);
  const skirt = mesh(
    new THREE.CylinderGeometry(r * 1.12, r, 0.65, 21, 1, true),
    mat(PALETTE.canRed, { roughness: 0.35, metalness: 0.4, side: THREE.DoubleSide }),
  );
  skirt.position.y = 0.45;
  group.add(skirt);
  for (let i = 0; i < 21; i++) {
    const a = (i / 21) * Math.PI * 2;
    const flute = mesh(new THREE.BoxGeometry(0.28, 0.62, 0.14), capMat);
    flute.position.set(Math.cos(a) * r * 1.08, 0.45, Math.sin(a) * r * 1.08);
    flute.rotation.y = -a + Math.PI / 2;
    group.add(flute);
  }
  return tag(group, 'bottle_cap', { category: 'object', heightCm: 0.8 });
}

// HB pencil lying on the ground: a 17 cm log bridge.
export function createPencil() {
  const group = new THREE.Group();
  const r = 0.38;
  const body = mesh(new THREE.CylinderGeometry(r, r, 14, 6), mat(PALETTE.pencil, { roughness: 0.5 }));
  group.add(body);
  const wood = mesh(new THREE.ConeGeometry(r, 1.8, 6), mat(PALETTE.wood));
  wood.position.y = 7.9;
  group.add(wood);
  const lead = mesh(new THREE.ConeGeometry(r * 0.35, 0.65, 6), mat(PALETTE.graphite, { roughness: 0.3, metalness: 0.3 }));
  lead.position.y = 8.8 + 0.02;
  group.add(lead);
  const ferrule = mesh(new THREE.CylinderGeometry(r * 1.05, r * 1.05, 1, 10), mat(PALETTE.metal, { metalness: 0.8, roughness: 0.3 }));
  ferrule.position.y = -7.5;
  group.add(ferrule);
  const eraser = mesh(new THREE.CylinderGeometry(r, r, 0.9, 10), mat(PALETTE.eraser));
  eraser.position.y = -8.4;
  group.add(eraser);
  group.rotation.z = Math.PI / 2;
  group.position.y = r * 0.87;
  return tag(new THREE.Group().add(group), 'pencil', { category: 'object', heightCm: r * 2 });
}

// 1 cent euro coin: a copper platform.
export function createCoin() {
  const group = new THREE.Group();
  const r = 0.81;
  const copper = mat(PALETTE.copper, { metalness: 0.75, roughness: 0.35 });
  const disc = mesh(new THREE.CylinderGeometry(r, r, 0.14, 24), copper);
  disc.position.y = 0.07;
  group.add(disc);
  const rim = mesh(new THREE.TorusGeometry(r * 0.94, 0.04, 4, 24), copper);
  rim.rotation.x = Math.PI / 2;
  rim.position.y = 0.15;
  group.add(rim);
  const relief = mesh(new THREE.CylinderGeometry(r * 0.4, r * 0.4, 0.03, 8), copper);
  relief.position.y = 0.155;
  group.add(relief);
  return tag(group, 'coin', { category: 'object', heightCm: 0.2 });
}

// Toy construction brick (2x4): a red building with studs to climb.
export function createToyBrick({ color = PALETTE.toyRed } = {}) {
  const group = new THREE.Group();
  const plastic = mat(color, { roughness: 0.3 });
  const w = 3.2;
  const d = 1.6;
  const h = 0.96;
  const body = mesh(new THREE.BoxGeometry(w, h, d), plastic);
  body.position.y = h / 2;
  group.add(body);
  for (let x = 0; x < 4; x++) {
    for (let z = 0; z < 2; z++) {
      const stud = mesh(new THREE.CylinderGeometry(0.24, 0.24, 0.17, 10), plastic);
      stud.position.set(-w / 2 + 0.4 + x * 0.8, h + 0.085, -d / 2 + 0.4 + z * 0.8);
      group.add(stud);
    }
  }
  return tag(group, 'toy_brick', { category: 'object', heightCm: h + 0.17 });
}

// Bent steel paperclip, flat on the ground: a rail to walk along.
export function createPaperclip() {
  const L = 3.3;
  const W = 0.9;
  const pts = [
    [L * 0.7, 0, -W * 0.15],
    [-L * 0.35, 0, -W * 0.15],
    [-L * 0.48, 0, 0.05],
    [-L * 0.35, 0, W * 0.3],
    [L * 0.45, 0, W * 0.3],
    [L * 0.58, 0, 0],
    [L * 0.45, 0, -W * 0.45],
    [-L * 0.45, 0, -W * 0.45],
    [-L * 0.6, 0, 0],
    [-L * 0.45, 0, W * 0.5],
    [L * 0.2, 0, W * 0.5],
  ].map(([x, y, z]) => [x, 0.06, z]);
  const group = new THREE.Group().add(tube(pts, 0.05, mat(PALETTE.clip, { metalness: 0.9, roughness: 0.25 }), 60, 5));
  return tag(group, 'paperclip', { category: 'object', heightCm: 0.12 });
}
