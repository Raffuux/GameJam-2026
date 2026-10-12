// Signature buildings of each gang: real species habitats, sized like the
// big buildings downtown (30 to 50 cm, 1 unit = 1 cm). Small repeated parts
// (needles, threads, ribs) are merged into a single mesh per material so
// each habitat stays light in Godot.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { PALETTE, mat, rng, mesh, blob, tube, jitter, tag } from './common.js';

// Collects transformed geometries per material and merges them at the end.
class Batch {
  constructor() {
    this.parts = new Map();
  }

  add(geometry, material, matrix) {
    const g = (geometry.index ? geometry.toNonIndexed() : geometry.clone());
    for (const name of Object.keys(g.attributes)) {
      if (name !== 'position' && name !== 'normal') g.deleteAttribute(name);
    }
    if (!g.attributes.normal) g.computeVertexNormals();
    if (matrix) g.applyMatrix4(matrix);
    if (!this.parts.has(material)) this.parts.set(material, []);
    this.parts.get(material).push(g);
  }

  // Cylinder from a to b.
  stick(a, b, radius, material, radial = 4) {
    const va = new THREE.Vector3(...a);
    const vb = new THREE.Vector3(...b);
    const len = va.distanceTo(vb);
    if (len < 1e-4) return;
    const g = new THREE.CylinderGeometry(radius, radius, len, radial, 1);
    g.translate(0, len / 2, 0);
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), vb.clone().sub(va).normalize());
    this.add(g, material, new THREE.Matrix4().compose(va, q, new THREE.Vector3(1, 1, 1)));
  }

  build(group, { cast = true } = {}) {
    for (const [material, list] of this.parts) {
      const m = mesh(mergeGeometries(list), material, { cast });
      group.add(m);
    }
    return group;
  }
}

// Point on a dome of radius R and height H at polar fraction t (0 top, 1 rim).
function domePoint(R, H, t, a) {
  const phi = t * Math.PI / 2;
  return new THREE.Vector3(Math.cos(a) * Math.sin(phi) * R, Math.cos(phi) * H, Math.sin(a) * Math.sin(phi) * R);
}

// ---- Colonie: wood ant mound ------------------------------------------------

// A wood-ant mound, ~26 cm tall and 50 cm wide, thatched with pine needles and
// twigs, with tunnel entrances all around and a main gate facing +Z.
export function createAntMound({ seed = 21 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const R = 25;
  const H = 26;
  const soil = mat(0x7a5634, { roughness: 1 });
  const profile = [];
  for (let i = 0; i <= 12; i++) {
    const t = i / 12;
    const p = domePoint(R, H, t, 0);
    profile.push(new THREE.Vector2(p.x + (t > 0.95 ? 2 : 0), p.y));
  }
  profile[0].x = 0.01;
  profile.reverse(); // lathe points run bottom to top so faces point outwards
  const domeG = new THREE.LatheGeometry(profile, 28).toNonIndexed();
  jitter(domeG, 1.6, seed);
  group.add(mesh(domeG, soil));

  // Thatch: hundreds of needles and twigs lying on the surface.
  const batch = new Batch();
  const needleMats = [mat(0xa0682f, { roughness: 1 }), mat(0x6e4524, { roughness: 1 }), mat(0xc08a4a, { roughness: 1 })];
  const up = new THREE.Vector3(0, 1, 0);
  for (let i = 0; i < 900; i++) {
    const t = Math.sqrt(r()) * 0.98;
    const a = r() * Math.PI * 2;
    const p = domePoint(R, H, t, a);
    const normal = new THREE.Vector3(p.x / (R * R), p.y / (H * H), p.z / (R * R)).normalize();
    const tangent = new THREE.Vector3(r() - 0.5, r() - 0.5, r() - 0.5).cross(normal).normalize();
    const len = 2 + r() * 3;
    const start = p.clone().addScaledVector(normal, 0.3).addScaledVector(tangent, -len / 2);
    const end = start.clone().addScaledVector(tangent, len).addScaledVector(normal, (r() - 0.3) * 0.8);
    batch.stick(start.toArray(), end.toArray(), 0.12 + r() * 0.1, needleMats[Math.floor(r() * 3)], 3);
  }
  // A few bigger twigs poking out like beams.
  const twig = mat(PALETTE.bark, { roughness: 1 });
  for (let i = 0; i < 14; i++) {
    const a = r() * Math.PI * 2;
    const p = domePoint(R, H, 0.3 + r() * 0.6, a);
    const out = new THREE.Vector3(Math.cos(a), 0.6, Math.sin(a)).normalize();
    batch.stick(p.clone().addScaledVector(out, -2).toArray(), p.clone().addScaledVector(out, 4 + r() * 3).toArray(), 0.35, twig, 5);
  }
  // Entrances: dark holes with a raised rim of soil.
  const hole = mat(0x1a120b, { roughness: 1 });
  const rim = mat(0x8d6a42, { roughness: 1 });
  const entrances = [];
  for (let i = 0; i < 9; i++) entrances.push({ a: (i / 9) * Math.PI * 2 + r() * 0.3, t: 0.35 + r() * 0.5, size: 1 + r() * 0.8 });
  for (const e of entrances) {
    const p = domePoint(R, H, e.t, e.a);
    const normal = new THREE.Vector3(p.x / (R * R), p.y / (H * H), p.z / (R * R)).normalize();
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), normal);
    const m = new THREE.Matrix4().compose(p.clone().addScaledVector(normal, 0.4), q, new THREE.Vector3(1, 1, 1));
    batch.add(new THREE.CircleGeometry(e.size, 8), hole, m);
    const ringM = new THREE.Matrix4().compose(p.clone().addScaledVector(normal, 0.3), q, new THREE.Vector3(1, 1, 0.6));
    batch.add(new THREE.TorusGeometry(e.size * 1.15, e.size * 0.35, 4, 9), rim, ringM);
  }
  batch.build(group);
  // Main gate at the base, facing +Z: an arched tunnel big enough for a beetle truck.
  const gate = new THREE.Group();
  const arch = mesh(new THREE.TorusGeometry(5, 1.4, 6, 12, Math.PI), rim);
  gate.add(arch);
  const mouth = mesh(new THREE.CircleGeometry(4.6, 12, 0, Math.PI), hole, { cast: false });
  mouth.position.z = -0.6;
  gate.add(mouth);
  gate.position.set(0, 0, R - 2.5);
  group.add(gate);
  // Summit vent.
  const vent = mesh(new THREE.CylinderGeometry(1.6, 2.6, 2, 8), rim);
  vent.position.y = H + 0.5;
  group.add(vent);
  const ventHole = mesh(new THREE.CircleGeometry(1.4, 8), hole, { cast: false });
  ventHole.rotation.x = -Math.PI / 2;
  ventHole.position.y = H + 1.55;
  group.add(ventHole);
  return tag(group, 'habitat_colonie', { category: 'habitat', heightCm: H + 2 });
}

// ---- Tisseuses: web lair ----------------------------------------------------

function silkMat() {
  return mat(0xf6f8fb, { emissive: 0xc9d6e6, emissiveIntensity: 0.4, roughness: 0.3, transparent: true, opacity: 0.8 });
}

// Orb web in the XY plane (faces +Z), centred at `c`, merged into `batch`.
function orbWeb(batch, c, rx, ry, r, { spokes = 18, turns = 14, thread = 0.08 } = {}) {
  const silk = silkMat();
  const ends = [];
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2 + (r() - 0.5) * 0.12;
    ends.push([c[0] + Math.cos(a) * rx * (0.88 + r() * 0.12), c[1] + Math.sin(a) * ry * (0.88 + r() * 0.12), c[2]]);
    batch.stick(c, ends[i], thread, silk, 3);
  }
  for (let i = 0; i < spokes; i++) batch.stick(ends[i], ends[(i + 1) % spokes], thread * 1.4, silk, 3);
  let prev = null;
  for (let k = 0; k <= turns * spokes; k++) {
    const i = k % spokes;
    const f = 0.08 + (0.86 * k) / (turns * spokes);
    const p = [c[0] + (ends[i][0] - c[0]) * f, c[1] + (ends[i][1] - c[1]) * f, c[2]];
    if (prev) batch.stick(prev, p, thread * 0.7, silk, 3);
    prev = p;
  }
  // Hub disc.
  batch.add(new THREE.CircleGeometry(rx * 0.06, 8), silk, new THREE.Matrix4().makeTranslation(...c));
  return ends;
}

// Silk-wrapped prey hanging from a thread.
function cocoon(batch, top, length, r) {
  const silk = silkMat();
  const wrap = mat(0xe9e6dc, { roughness: 0.8 });
  const bottom = [top[0], top[1] - length, top[2]];
  batch.stick(top, bottom, 0.06, silk, 3);
  const g = new THREE.IcosahedronGeometry(1, 1);
  g.scale(0.9 + r() * 0.3, 2 + r() * 0.8, 0.9 + r() * 0.3);
  batch.add(g, wrap, new THREE.Matrix4().makeTranslation(bottom[0], bottom[1] - 2, bottom[2]));
  for (let k = 0; k < 4; k++) {
    const t = new THREE.TorusGeometry(1.0, 0.08, 3, 10);
    t.rotateX(Math.PI / 2 + (r() - 0.5) * 0.6);
    batch.add(t, silk, new THREE.Matrix4().makeTranslation(bottom[0], bottom[1] - 3.2 + k * 0.8, bottom[2]));
  }
}

// The Tisseuses lair, ~50 cm: two dead branches holding a giant orb web,
// a sheet-and-funnel web at the base leading into a burrow, wrapped prey.
export function createWebLair({ seed = 22 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const bark = mat(0x5b4636, { roughness: 1 });
  const W = 44;
  const H = 50;
  // Two forked branches stuck in the ground.
  for (const side of [-1, 1]) {
    const x = side * W / 2;
    group.add(tube([[x, -1, 0], [x + side * 1.5, H * 0.5, 0.5], [x - side * 0.5, H, 0]], 1.4, bark, 12, 6));
    group.add(tube([[x - side * 0.2, H * 0.6, 0.3], [x - side * 5, H * 0.8, 1], [x - side * 8, H * 0.95, 0.5]], 0.7, bark, 8, 5));
    group.add(tube([[x + side * 0.5, H * 0.35, 0.2], [x + side * 5, H * 0.45, -1], [x + side * 9, H * 0.48, -2]], 0.6, bark, 8, 5));
  }
  // Crossbar branch at the top.
  group.add(tube([[-W / 2 - 3, H * 0.92, -1], [0, H * 1.0, -1.5], [W / 2 + 3, H * 0.9, -1]], 0.9, bark, 12, 6));
  const batch = new Batch();
  const silk = silkMat();
  const centre = [0, H * 0.55, 0];
  const ends = orbWeb(batch, centre, W / 2 - 2, H * 0.4, r);
  // Anchor lines from the web frame to branches and to the ground.
  for (const [x, y] of [[-W / 2, H * 0.9], [W / 2, H * 0.88], [-W / 2, H * 0.25], [W / 2, H * 0.3]]) {
    let best = ends[0];
    for (const e of ends) if (Math.hypot(e[0] - x, e[1] - y) < Math.hypot(best[0] - x, best[1] - y)) best = e;
    batch.stick(best, [x, y, 0], 0.12, silk, 3);
  }
  batch.stick(ends[Math.floor(ends.length * 0.75)], [-6, 0, 10], 0.1, silk, 3);
  batch.stick(ends[Math.floor(ends.length * 0.75) + 1], [8, 0, 12], 0.1, silk, 3);
  // Dew drops caught on the spiral.
  const dew = mat(0xd9f1ff, { roughness: 0.05, metalness: 0.1, transparent: true, opacity: 0.6 });
  for (let i = 0; i < 40; i++) {
    const e = ends[Math.floor(r() * ends.length)];
    const f = 0.2 + r() * 0.75;
    const p = [centre[0] + (e[0] - centre[0]) * f, centre[1] + (e[1] - centre[1]) * f, 0.15];
    const s = 0.25 + r() * 0.3;
    batch.add(new THREE.IcosahedronGeometry(s, 0), dew, new THREE.Matrix4().makeTranslation(...p));
  }
  // Wrapped prey hanging from the crossbar.
  for (const x of [-14, -3, 11]) cocoon(batch, [x, H * 0.95, -1.4], 4 + r() * 5, r);
  // Sheet web on the ground in front, funnelling into a burrow.
  const sheet = new THREE.Group();
  const sheetG = new THREE.CircleGeometry(14, 16, 0, Math.PI * 2);
  sheetG.rotateX(-Math.PI / 2);
  const sp = sheetG.attributes.position;
  for (let i = 0; i < sp.count; i++) {
    const x = sp.getX(i);
    const z = sp.getZ(i);
    const d = Math.hypot(x, z);
    sp.setY(i, 2.5 + Math.min(d, 14) * 0.12 - Math.max(0, 4 - d) * 0.9);
  }
  sheetG.computeVertexNormals();
  sheet.add(mesh(sheetG, mat(0xf4f6f8, { transparent: true, opacity: 0.55, side: THREE.DoubleSide, roughness: 0.4, depthWrite: false }), { cast: false }));
  const funnel = mesh(new THREE.CylinderGeometry(2.6, 1.2, 4, 10, 1, true), mat(0xf4f6f8, { transparent: true, opacity: 0.7, side: THREE.DoubleSide, depthWrite: false }), { cast: false });
  funnel.position.y = 0.6;
  sheet.add(funnel);
  const burrow = mesh(new THREE.CircleGeometry(1.2, 10), mat(0x120d0a), { cast: false });
  burrow.rotation.x = -Math.PI / 2;
  burrow.position.y = 0.05;
  sheet.add(burrow);
  // Guy lines holding the sheet up.
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2;
    batch.stick([Math.cos(a) * 13 + 0, 4.1, Math.sin(a) * 13 + 16], [Math.cos(a) * 16, 0, Math.sin(a) * 16 + 16], 0.06, silk, 3);
  }
  sheet.position.set(0, 0, 16);
  group.add(sheet);
  batch.build(group, { cast: false });
  return tag(group, 'habitat_tisseuses', { category: 'habitat', heightCm: H + 2 });
}

// ---- Prieurs: mantis nest ---------------------------------------------------

function broadLeaf(length, width) {
  const s = new THREE.Shape();
  s.moveTo(0, 0);
  s.bezierCurveTo(width, length * 0.25, width * 0.8, length * 0.8, 0, length);
  s.bezierCurveTo(-width * 0.8, length * 0.8, -width, length * 0.25, 0, 0);
  const g = new THREE.ShapeGeometry(s, 5);
  // Fold along the midrib and droop the tip.
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i);
    const y = p.getY(i);
    p.setZ(i, Math.abs(x) * 0.35 - (y / length) ** 2 * length * 0.25);
  }
  g.computeVertexNormals();
  return g;
}

// Ootheca: the mantis egg case, a ribbed foam lump stuck to a stem.
function ootheca(batch, pos, r) {
  const foam = mat(0xd8c49a, { roughness: 1 });
  const rib = mat(0xbca476, { roughness: 1 });
  const body = new THREE.IcosahedronGeometry(1, 1);
  body.scale(1.6, 2.6, 1.4);
  batch.add(body, foam, new THREE.Matrix4().makeTranslation(...pos));
  for (let k = 0; k < 6; k++) {
    const t = new THREE.TorusGeometry(1.35 - Math.abs(k - 2.5) * 0.15, 0.18, 3, 10);
    t.rotateX(Math.PI / 2);
    t.scale(1.15, 1, 1);
    batch.add(t, rib, new THREE.Matrix4().makeTranslation(pos[0], pos[1] - 1.8 + k * 0.7, pos[2]));
  }
}

// The Prieurs' nest, ~45 cm: a clump of tall stalks with broad leaves
// forming roofs and lookout platforms, egg cases stuck to the stems.
export function createMantisNest({ seed = 23 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const batch = new Batch();
  const stemMat = mat(0x5d8a2f, { roughness: 0.8 });
  const leafMats = [mat(0x4f8f2a, { side: THREE.DoubleSide, roughness: 0.7 }), mat(0x6aa83a, { side: THREE.DoubleSide, roughness: 0.7 }), mat(0x3d7524, { side: THREE.DoubleSide, roughness: 0.7 })];
  const stems = [];
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2 + r() * 0.4;
    const d = 3 + r() * 9;
    const h = 30 + r() * 18;
    const base = [Math.cos(a) * d, 0, Math.sin(a) * d];
    const lean = [Math.cos(a) * (3 + r() * 4), Math.sin(a) * (3 + r() * 4)];
    const pts = [base, [base[0] + lean[0] * 0.4, h * 0.5, base[2] + lean[1] * 0.4], [base[0] + lean[0], h, base[2] + lean[1]]];
    stems.push({ pts, h, a });
    const curve = new THREE.CatmullRomCurve3(pts.map((p) => new THREE.Vector3(...p)));
    batch.add(new THREE.TubeGeometry(curve, 10, 0.55 + r() * 0.3, 5, false), stemMat);
    // Leaves spiralling up the stem.
    for (let k = 0; k < 5; k++) {
      const t = 0.3 + k * 0.15;
      const p = curve.getPoint(t);
      const len = 9 + r() * 7;
      const g = broadLeaf(len, len * 0.35);
      g.rotateX(-Math.PI / 2 + 0.5 + r() * 0.4);
      g.rotateY(a + k * 2.1 + r());
      batch.add(g, leafMats[Math.floor(r() * 3)], new THREE.Matrix4().makeTranslation(p.x, p.y, p.z));
    }
  }
  // Big flat leaves as roofs and platforms at three levels.
  for (const [y, size] of [[14, 22], [24, 18], [34, 14]]) {
    const g = broadLeaf(size, size * 0.55);
    g.translate(0, -size / 2, 0);
    g.rotateX(-Math.PI / 2 + 0.08);
    g.rotateY(r() * Math.PI * 2);
    batch.add(g, leafMats[0], new THREE.Matrix4().makeTranslation(r() * 4 - 2, y, r() * 4 - 2));
  }
  // Egg cases on three stems.
  for (const s of stems.slice(0, 3)) {
    const t = 0.45 + r() * 0.2;
    const p = new THREE.CatmullRomCurve3(s.pts.map((q) => new THREE.Vector3(...q))).getPoint(t);
    ootheca(batch, [p.x + Math.cos(s.a) * 1.4, p.y, p.z + Math.sin(s.a) * 1.4], r);
  }
  batch.build(group);
  // Dry leaf litter around the base.
  const litter = new Batch();
  const dry = [mat(0xa7783a, { side: THREE.DoubleSide }), mat(0x8a5e2a, { side: THREE.DoubleSide })];
  for (let i = 0; i < 18; i++) {
    const g = broadLeaf(5 + r() * 4, 2.5);
    g.rotateX(-Math.PI / 2);
    g.rotateY(r() * Math.PI * 2);
    const a = r() * Math.PI * 2;
    const d = 6 + r() * 14;
    litter.add(g, dry[i % 2], new THREE.Matrix4().makeTranslation(Math.cos(a) * d, 0.2, Math.sin(a) * d));
  }
  litter.build(group);
  return tag(group, 'habitat_prieurs', { category: 'habitat', heightCm: 50 });
}

// ---- Nuée: garbage dump -----------------------------------------------------

// The Nuée's dump, ~30 cm high: a rotting heap of food scraps and trash,
// with a cloud of flies circling above (animated).
export function createFlyDump({ seed = 24 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  // The heap itself.
  const heapProfile = [];
  for (let i = 0; i <= 10; i++) {
    const t = i / 10;
    heapProfile.push(new THREE.Vector2(Math.max(0.01, Math.sin(t * Math.PI / 2) * 26), (1 - t * t) * 16));
  }
  heapProfile.reverse();
  const heapG = new THREE.LatheGeometry(heapProfile, 20).toNonIndexed();
  jitter(heapG, 3, seed);
  group.add(mesh(heapG, mat(0x4d4232, { roughness: 1 })));
  const batch = new Batch();
  const onHeap = (a, d) => {
    const h = (1 - (d / 26) ** 2) * 16;
    return [Math.cos(a) * d, Math.max(0, h), Math.sin(a) * d];
  };
  // Banana peel: three floppy yellow strips.
  {
    const [x, y, z] = onHeap(0.5, 8);
    for (let k = 0; k < 3; k++) {
      const g = broadLeaf(11, 2.4);
      g.rotateX(-Math.PI / 2 + 0.3);
      g.rotateY((k / 3) * Math.PI * 2);
      batch.add(g, mat(0xe8c43a, { side: THREE.DoubleSide, roughness: 0.6 }), new THREE.Matrix4().makeTranslation(x, y + 1.5, z));
    }
    batch.add(new THREE.CylinderGeometry(0.8, 1, 2.5, 6), mat(0x5c4a22), new THREE.Matrix4().makeTranslation(x, y + 2.5, z));
  }
  // Apple core.
  {
    const [x, y, z] = onHeap(2.3, 12);
    const core = [[0, 3.2], [2.6, 2.6], [1.2, 1.6], [1.1, 0], [1.2, -1.6], [2.6, -2.6], [0, -3.2]].map(([a, b]) => new THREE.Vector2(a, b));
    batch.add(new THREE.LatheGeometry(core, 10), mat(0xf1e2b4, { roughness: 0.8 }), new THREE.Matrix4().makeTranslation(x, y + 3, z));
    for (const sy of [2.6, -2.6]) {
      const skin = new THREE.TorusGeometry(2.6, 0.5, 4, 10);
      skin.rotateX(Math.PI / 2);
      batch.add(skin, mat(0xb8322a, { roughness: 0.5 }), new THREE.Matrix4().makeTranslation(x, y + 3 + sy, z));
    }
  }
  // Pizza crust slice (triangle wedge with crust).
  {
    const [x, y, z] = onHeap(4.1, 10);
    const s = new THREE.Shape();
    s.moveTo(0, 0);
    s.lineTo(12, -4);
    s.lineTo(12, 4);
    s.lineTo(0, 0);
    const g = new THREE.ExtrudeGeometry(s, { depth: 0.6, bevelEnabled: false });
    g.rotateX(-Math.PI / 2);
    g.rotateZ(0.25);
    batch.add(g, mat(0xe0a64a, { roughness: 0.9 }), new THREE.Matrix4().makeTranslation(x - 6, y + 0.8, z));
    const crust = new THREE.CylinderGeometry(1, 1, 8.4, 8);
    crust.rotateX(Math.PI / 2);
    batch.add(crust, mat(0xb9772e), new THREE.Matrix4().makeTranslation(x + 6, y + 2.4, z));
    for (let k = 0; k < 4; k++) {
      batch.add(new THREE.CylinderGeometry(0.9, 0.9, 0.3, 8), mat(0xb3322a), new THREE.Matrix4().makeTranslation(x - 1 + k * 2, y + 1.6, z + (k % 2 ? 1 : -1)));
    }
  }
  // Crushed can, paper scraps, bottle caps, eggshell halves.
  {
    const [x, y, z] = onHeap(5.4, 14);
    batch.add(jitter(new THREE.CylinderGeometry(3.3, 3.3, 5, 12).toNonIndexed(), 1, seed + 1), mat(0x2f6fbf, { roughness: 0.4, metalness: 0.3 }), new THREE.Matrix4().makeRotationZ(1.3).setPosition(x, y + 3, z));
  }
  for (let i = 0; i < 9; i++) {
    const [x, y, z] = onHeap(r() * Math.PI * 2, 4 + r() * 20);
    const g = jitter(new THREE.IcosahedronGeometry(1.2 + r() * 1.2, 1), 0.9, seed + i);
    batch.add(g, mat(i % 3 ? 0xefece4 : 0xd8d0b8, { roughness: 0.9 }), new THREE.Matrix4().makeTranslation(x, y + 1, z));
  }
  for (let i = 0; i < 4; i++) {
    const [x, y, z] = onHeap(r() * Math.PI * 2, 8 + r() * 14);
    const shell = new THREE.SphereGeometry(2, 10, 5, 0, Math.PI * 2, 0, Math.PI / 2);
    shell.rotateX(Math.PI + (r() - 0.5));
    batch.add(shell, mat(0xf3eadb, { side: THREE.DoubleSide }), new THREE.Matrix4().makeTranslation(x, y + 1.6, z));
  }
  // Garbage bags slumped against the heap.
  for (let i = 0; i < 4; i++) {
    const a = r() * Math.PI * 2;
    const g = jitter(new THREE.IcosahedronGeometry(5 + r() * 2, 1), 2, seed + 10 + i);
    g.scale(1, 0.8, 1);
    batch.add(g, mat(0x1f2124, { roughness: 0.3 }), new THREE.Matrix4().makeTranslation(Math.cos(a) * 24, 4, Math.sin(a) * 24));
  }
  // Puddles of goo.
  for (let i = 0; i < 3; i++) {
    const a = r() * Math.PI * 2;
    const g = new THREE.CircleGeometry(3 + r() * 3, 9);
    g.rotateX(-Math.PI / 2);
    batch.add(g, mat(0x6b7a2a, { roughness: 0.1, metalness: 0.2 }), new THREE.Matrix4().makeTranslation(Math.cos(a) * 30, 0.06, Math.sin(a) * 30));
  }
  batch.build(group);
  // Fly swarm circling above the heap. Speeds are whole turns per baked loop.
  const swarm = new THREE.Group();
  swarm.name = 'swarm';
  const flyMat = mat(PALETTE.flyBody, { roughness: 0.5 });
  const flies = [];
  for (let i = 0; i < 24; i++) {
    const f = blob(0.35, 0.3, 0.5, flyMat, 0);
    f.castShadow = false;
    flies.push({ f, radius: 4 + r() * 12, height: 20 + r() * 12, speed: (r() < 0.5 ? 1 : 2) * (r() < 0.5 ? -1 : 1), phase: r() * Math.PI * 2 });
    swarm.add(f);
  }
  group.add(swarm);
  group.userData.update = (t) => {
    for (const { f, radius, height, speed, phase } of flies) {
      const a = t * speed * 1.5 + phase;
      f.position.set(Math.cos(a) * radius, height + Math.sin(t * 3 + phase) * 1.5, Math.sin(a) * radius);
      f.rotation.y = -a;
    }
  };
  group.userData.update(0);
  return tag(group, 'habitat_nuee', { category: 'habitat', heightCm: 34, animated: true });
}
