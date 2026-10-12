// The bug city: GTA-style streets and buildings, at bug scale (1 unit = 1 cm).
// Streets are sized for bug traffic (a 5 cm beetle is a truck). Buildings are
// made from human junk: cardboard boxes, cereal boxes, milk cartons.
import * as THREE from 'three';
import { PALETTE, mat, rng, mesh, blob, segment, tube, jitter, tag } from './common.js';

export const CITY = {
  tile: 20, // a road tile is 20 x 20 cm
  roadWidth: 10, // two lanes of 5 cm
  curb: 0.4,
};

const C = {
  asphalt: 0x3b3c40,
  asphaltLight: 0x4a4b50,
  line: 0xf2d14b,
  zebra: 0xeeeeea,
  sidewalk: 0xb9b4a8,
  sidewalkDark: 0xa39e92,
  cardboard: 0xc49a6c,
  cardboardDark: 0x9d7547,
  window: 0x2c3a4a,
  windowLit: 0xffd27a,
  bank: 0xe8e1cf,
  bankTrim: 0xcfc4a6,
  gold: 0xe0b23a,
  binGreen: 0x2f6b3f,
  hydrant: 0xd23a2a,
  bag: 0x1f2124,
  paper: 0xefece4,
  filter: 0xd99a4a,
  bottle: 0x9fd4e6,
};

function box(w, h, d, material, x = 0, y = 0, z = 0) {
  const m = mesh(new THREE.BoxGeometry(w, h, d), material);
  m.position.set(x, y, z);
  return m;
}

function sidewalkStrip(length, width, z) {
  const g = new THREE.Group();
  const slabs = Math.round(length / width);
  for (let i = 0; i < slabs; i++) {
    const m = mat(i % 2 ? C.sidewalk : C.sidewalkDark);
    g.add(box(length / slabs - 0.08, CITY.curb, width - 0.08, m, -length / 2 + (i + 0.5) * (length / slabs), CITY.curb / 2, z));
  }
  return g;
}

// Straight road tile running along X, with sidewalks, dashed centre line and gutters.
export function createRoadStraight() {
  const { tile, roadWidth } = CITY;
  const sw = (tile - roadWidth) / 2;
  const group = new THREE.Group();
  group.add(box(tile, 0.1, roadWidth, mat(C.asphalt, { roughness: 0.95 }), 0, 0.05, 0));
  const lineMat = mat(C.line, { roughness: 0.6 });
  for (let i = 0; i < 4; i++) {
    group.add(box(2.6, 0.02, 0.25, lineMat, -tile / 2 + 2.5 + i * 5, 0.11, 0));
  }
  group.add(sidewalkStrip(tile, sw, -(roadWidth + sw) / 2));
  group.add(sidewalkStrip(tile, sw, (roadWidth + sw) / 2));
  return tag(group, 'road_straight', { category: 'city', heightCm: CITY.curb });
}

// Crossroads with zebra crossings on all four sides and sidewalk corners.
export function createRoadCross() {
  const { tile, roadWidth } = CITY;
  const sw = (tile - roadWidth) / 2;
  const group = new THREE.Group();
  group.add(box(tile, 0.1, tile, mat(C.asphalt, { roughness: 0.95 }), 0, 0.05, 0));
  const zebra = mat(C.zebra, { roughness: 0.6 });
  for (let side = 0; side < 4; side++) {
    const stripes = new THREE.Group();
    for (let i = 0; i < 6; i++) {
      stripes.add(box(0.8, 0.02, 2.2, zebra, -roadWidth / 2 + 0.9 + i * 1.65, 0.11, roadWidth / 2 - 1.5));
    }
    stripes.rotation.y = (side * Math.PI) / 2;
    group.add(stripes);
  }
  for (const x of [-1, 1]) {
    for (const z of [-1, 1]) {
      const corner = box(sw - 0.08, CITY.curb, sw - 0.08, mat(C.sidewalk), x * (roadWidth + sw) / 2, CITY.curb / 2, z * (roadWidth + sw) / 2);
      group.add(corner);
    }
  }
  return tag(group, 'road_cross', { category: 'city', heightCm: CITY.curb });
}

// Grid of windows on one face of a building. Faces +Z, centred on (0, 0).
function windowGrid(width, height, { cols, rows, seed = 1, lit = 0.35, inset = 0.06 }) {
  const r = rng(seed);
  const g = new THREE.Group();
  const cw = width / cols;
  const rh = height / rows;
  for (let c = 0; c < cols; c++) {
    for (let row = 0; row < rows; row++) {
      const on = r() < lit;
      const m = on ? mat(C.windowLit, { emissive: C.windowLit, emissiveIntensity: 0.9 }) : mat(C.window, { roughness: 0.2, metalness: 0.3 });
      const w = box(cw * 0.6, rh * 0.55, inset, m, -width / 2 + (c + 0.5) * cw, -height / 2 + (row + 0.5) * rh, 0);
      w.castShadow = false;
      g.add(w);
    }
  }
  return g;
}

// Put the same window grid on the four faces of a w x h x d block.
function addWindows(group, w, h, d, y0, opts) {
  const faces = [
    [0, d / 2 + 0.02, 0, w], [Math.PI, -d / 2 - 0.02, 0, w], [Math.PI / 2, 0, w / 2 + 0.02, d], [-Math.PI / 2, 0, -w / 2 - 0.02, d],
  ];
  faces.forEach(([rotY, z, x, faceW], i) => {
    const cols = Math.max(1, Math.round(faceW / opts.spacing));
    const grid = windowGrid(faceW * 0.9, h * 0.85, { ...opts, cols, rows: opts.rows, seed: (opts.seed ?? 1) + i });
    grid.rotation.y = rotY;
    grid.position.set(x, y0 + h / 2 + h * 0.03, z);
    group.add(grid);
  });
}

function door(width, height, material = mat(C.cardboardDark)) {
  const d = box(width, height, 0.15, material);
  d.position.y = height / 2;
  return d;
}

// Cardboard box apartment block, ~12 cm. Flaps folded open on the roof.
export function createBoxBuilding({ seed = 1, width = 12, depth = 10, height = 12 } = {}) {
  const group = new THREE.Group();
  const card = mat(C.cardboard, { roughness: 0.95 });
  group.add(box(width, height, depth, card, 0, height / 2, 0));
  addWindows(group, width, height * 0.75, depth, height * 0.2, { spacing: 2.4, rows: 3, seed, lit: 0.4 });
  const d = door(2.4, 3.2);
  d.position.z = depth / 2 + 0.05;
  group.add(d);
  // Packing tape along the top and open flaps.
  group.add(box(width + 0.02, 0.05, 1.6, mat(0xd8c08a, { roughness: 0.4 }), 0, height + 0.02, 0));
  for (const side of [1, -1]) {
    const flap = box(width, 0.1, depth / 2, card);
    flap.geometry.translate(0, 0, side * depth / 4);
    flap.position.set(0, height, side * depth / 2);
    flap.rotation.x = side * -0.5;
    group.add(flap);
  }
  // Rooftop AC unit made from a matchbox.
  group.add(box(2.4, 1.2, 1.6, mat(0x7c8a96), -width * 0.25, height + 0.6, -depth * 0.1));
  return tag(group, 'building_box', { category: 'city', heightCm: height + 2 });
}

// Cereal box skyscraper, ~30 cm. The tallest thing downtown.
export function createTowerBuilding({ seed = 2, height = 30 } = {}) {
  const group = new THREE.Group();
  const w = 19;
  const d = 7;
  const printed = mat(0xe24b2c, { roughness: 0.8 });
  group.add(box(w, height, d, printed, 0, height / 2, 0));
  // Big printed logo disc on the front, like a billboard.
  const logo = mesh(new THREE.CircleGeometry(4.2, 16), mat(0xf6c932, { roughness: 0.7 }), { cast: false });
  logo.position.set(0, height * 0.78, d / 2 + 0.03);
  group.add(logo);
  const bowl = mesh(new THREE.CircleGeometry(2.4, 12), mat(0xffffff), { cast: false });
  bowl.position.set(0, height * 0.78, d / 2 + 0.05);
  group.add(bowl);
  addWindows(group, w, height * 0.55, d, 3.5, { spacing: 2, rows: 9, seed, lit: 0.45 });
  const d1 = door(3.5, 3, mat(C.window, { roughness: 0.2 }));
  d1.position.z = d / 2 + 0.05;
  group.add(d1);
  // Antenna from a pin.
  group.add(segment([w * 0.3, height, 0], [w * 0.3, height + 6, 0], 0.12, mat(PALETTE.metal, { metalness: 0.8, roughness: 0.3 })));
  const tip = blob(0.4, 0.4, 0.4, mat(0xff3b30, { emissive: 0xff3b30, emissiveIntensity: 1 }), 0);
  tip.position.set(w * 0.3, height + 6.2, 0);
  group.add(tip);
  return tag(group, 'building_tower', { category: 'city', heightCm: height + 6.5 });
}

// Milk carton apartments, ~20 cm, with the gable roof.
export function createCartonBuilding({ seed = 3 } = {}) {
  const group = new THREE.Group();
  const s = 7;
  const h = 16;
  const white = mat(0xf3f1ea, { roughness: 0.7 });
  group.add(box(s, h, s, white, 0, h / 2, 0));
  group.add(box(s + 0.02, 3, s + 0.02, mat(0x3f7fc4, { roughness: 0.7 }), 0, 2.5, 0));
  addWindows(group, s, h * 0.6, s, 5, { spacing: 2.2, rows: 5, seed, lit: 0.35 });
  const roof = new THREE.Shape();
  roof.moveTo(-s / 2, 0);
  roof.lineTo(s / 2, 0);
  roof.lineTo(0, 3.4);
  roof.lineTo(-s / 2, 0);
  const roofG = new THREE.ExtrudeGeometry(roof, { depth: s, bevelEnabled: false });
  roofG.translate(0, h, -s / 2);
  group.add(mesh(roofG, white));
  group.add(box(0.3, 1.2, s, white, 0, h + 3.9, 0));
  const d = door(2, 2.6, mat(0x2c5d92));
  d.position.z = s / 2 + 0.05;
  group.add(d);
  return tag(group, 'building_carton', { category: 'city', heightCm: h + 4.5 });
}

// The bank: a stone facade with columns, pediment and a golden coin sign.
// The vault is a stack of real coins behind the doors.
export function createBank() {
  const group = new THREE.Group();
  const stone = mat(C.bank, { roughness: 0.8 });
  const trim = mat(C.bankTrim, { roughness: 0.8 });
  const gold = mat(C.gold, { metalness: 0.8, roughness: 0.3 });
  const w = 18;
  const d = 12;
  const h = 10;
  // Steps.
  for (let i = 0; i < 3; i++) {
    group.add(box(w + 2 - i * 0.6, 0.5, 3 - i * 0.7, trim, 0, 0.25 + i * 0.5, d / 2 + 1.5 - i * 0.35));
  }
  group.add(box(w, h, d, stone, 0, h / 2, 0));
  group.add(box(w + 1, 0.8, d + 1, trim, 0, h + 0.4, 0));
  // Columns along the front.
  for (let i = 0; i < 6; i++) {
    const col = mesh(new THREE.CylinderGeometry(0.55, 0.65, h - 1.5, 8), stone);
    col.position.set(-w / 2 + 1.4 + i * ((w - 2.8) / 5), (h - 1.5) / 2 + 1.5, d / 2 + 0.9);
    group.add(col);
  }
  // Pediment.
  const ped = new THREE.Shape();
  ped.moveTo(-w / 2 - 0.5, 0);
  ped.lineTo(w / 2 + 0.5, 0);
  ped.lineTo(0, 3);
  ped.lineTo(-w / 2 - 0.5, 0);
  const pedG = new THREE.ExtrudeGeometry(ped, { depth: 2.2, bevelEnabled: false });
  pedG.translate(0, h + 0.8, d / 2 - 0.4);
  group.add(mesh(pedG, stone));
  // Gold coin sign in the pediment.
  const coin = mesh(new THREE.CylinderGeometry(1.1, 1.1, 0.2, 16), gold);
  coin.rotation.x = Math.PI / 2;
  coin.position.set(0, h + 1.9, d / 2 + 1.9);
  group.add(coin);
  // Big doors, slightly open, coins stacked in the vault.
  const doorMat = mat(0x5a3a22, { roughness: 0.6 });
  for (const side of [1, -1]) {
    const leaf = box(1.6, 5, 0.25, doorMat);
    leaf.geometry.translate(-side * 0.8, 2.5, 0);
    leaf.position.set(side * 1.6, 1.5, d / 2 + 0.1);
    leaf.rotation.y = side * 0.5;
    group.add(leaf);
  }
  const copper = mat(PALETTE.copper, { metalness: 0.75, roughness: 0.35 });
  for (let i = 0; i < 7; i++) {
    const c = mesh(new THREE.CylinderGeometry(0.81, 0.81, 0.14, 16), i % 3 ? copper : gold);
    c.position.set(0.2 * Math.sin(i), 1.6 + i * 0.15, d / 2 - 1.2);
    group.add(c);
  }
  return tag(group, 'bank', { category: 'city', heightCm: h + 4 });
}

// Slab with rounded corners in plan and bevelled (rounded) edges, centred, height along Y.
function roundedSlab(w, d, h, r, material, bevel = 0.3) {
  const b = Math.min(bevel, h / 2 - 0.01);
  const hw = w / 2 - b;
  const hd = d / 2 - b;
  const rr = Math.max(0.05, Math.min(r - b, hw, hd));
  const s = new THREE.Shape();
  s.moveTo(-hw + rr, -hd);
  s.lineTo(hw - rr, -hd);
  s.quadraticCurveTo(hw, -hd, hw, -hd + rr);
  s.lineTo(hw, hd - rr);
  s.quadraticCurveTo(hw, hd, hw - rr, hd);
  s.lineTo(-hw + rr, hd);
  s.quadraticCurveTo(-hw, hd, -hw, hd - rr);
  s.lineTo(-hw, -hd + rr);
  s.quadraticCurveTo(-hw, -hd, -hw + rr, -hd);
  const g = new THREE.ExtrudeGeometry(s, { depth: h - 2 * b, bevelEnabled: true, bevelThickness: b, bevelSize: b, bevelSegments: 5, curveSegments: 10 });
  g.translate(0, 0, -(h - 2 * b) / 2);
  g.rotateX(-Math.PI / 2);
  return mesh(g, material);
}

// 3x5 block font for signs: each glyph is 5 rows of 3 bits, top row first.
const FONT = {
  A: [7, 5, 7, 5, 5], B: [6, 5, 6, 5, 6], G: [7, 4, 5, 5, 7], I: [7, 2, 2, 2, 7], L: [4, 4, 4, 4, 7],
  O: [7, 5, 5, 5, 7], S: [7, 4, 7, 1, 7], U: [5, 5, 5, 5, 7], P: [7, 5, 7, 4, 4], H: [5, 5, 7, 5, 5],
  0: [7, 5, 5, 5, 7], 1: [2, 6, 2, 2, 7], 2: [7, 1, 7, 4, 7], 3: [7, 1, 7, 1, 7], 4: [5, 5, 7, 1, 1],
  5: [7, 4, 7, 1, 7], 6: [7, 4, 7, 5, 7], 7: [7, 1, 1, 1, 1], 8: [7, 5, 7, 5, 7], 9: [7, 5, 7, 1, 7],
  C: [7, 4, 4, 4, 7], D: [6, 5, 5, 5, 6], E: [7, 4, 6, 4, 7], F: [7, 4, 6, 4, 4], J: [1, 1, 1, 5, 7],
  K: [5, 5, 6, 5, 5], M: [5, 7, 5, 5, 5], N: [5, 7, 7, 7, 5], Q: [7, 5, 5, 7, 1], R: [6, 5, 6, 5, 5],
  T: [7, 2, 2, 2, 2], V: [5, 5, 5, 5, 2], W: [5, 5, 7, 7, 5], X: [5, 5, 2, 5, 5], Y: [5, 5, 2, 2, 2],
  Z: [7, 1, 2, 4, 7], '-': [0, 0, 7, 0, 0],
  '.': [0, 0, 0, 0, 2], ' ': [0, 0, 0, 0, 0],
};

// Block letters in the XY plane facing +Z, centred, `cell` units per pixel.
function blockText(text, cell, material, depth = 0.15) {
  const g = new THREE.Group();
  const chars = [...text];
  const width = chars.length * 4 - 1;
  chars.forEach((ch, i) => {
    const rows = FONT[ch] ?? FONT[' '];
    rows.forEach((bits, row) => {
      for (let col = 0; col < 3; col++) {
        if (!(bits & (4 >> col))) continue;
        const px = box(cell * 0.92, cell * 0.92, depth, material);
        px.position.set((i * 4 + col - width / 2 + 0.5) * cell, (2 - row) * cell, depth / 2);
        px.castShadow = false;
        g.add(px);
      }
    });
  });
  return g;
}

// Gas station, ~14 cm: a canopy over two pump islands, a little shop and a price
// pylon, on a stained concrete apron. Opens on +Z (the road side).
export function createGasStation() {
  const group = new THREE.Group();
  const r = rng(41);
  const concrete = mat(0x8f8b83, { roughness: 0.95 });
  const concreteDark = mat(0x77736b, { roughness: 0.95 });
  const red = mat(0xb3261e, { roughness: 0.55 });
  const white = mat(0xe9e5da, { roughness: 0.6 });
  const yellow = mat(0xf0b92a, { roughness: 0.5 });
  const steel = mat(PALETTE.metal, { metalness: 0.7, roughness: 0.35 });
  const dark = mat(0x26272b, { roughness: 0.7 });
  const glass = mat(C.window, { roughness: 0.15, metalness: 0.3 });
  const glow = mat(0xfff2c8, { emissive: 0xfff2c8, emissiveIntensity: 1.4 });
  const led = mat(0xff9a2a, { emissive: 0xff9a2a, emissiveIntensity: 2 });
  const screen = mat(0x6fe3a0, { emissive: 0x6fe3a0, emissiveIntensity: 1.2 });

  // Concrete apron in slabs, with oil stains.
  const W = 30;
  const D = 24;
  const slab = 6;
  for (let x = 0; x < W / slab; x++) {
    for (let z = 0; z < D / slab; z++) {
      group.add(box(slab - 0.1, 0.3, slab - 0.1, (x + z) % 2 ? concrete : concreteDark, -W / 2 + (x + 0.5) * slab, 0.15, -D / 2 + (z + 0.5) * slab));
    }
  }
  group.add(box(W + 0.3, 0.26, D + 0.3, dark, 0, 0.13, 0));
  const oil = mat(0x121214, { roughness: 0.6 });
  for (let i = 0; i < 6; i++) {
    const stain = mesh(new THREE.CircleGeometry(0.6 + r() * 1.2, 10), oil, { cast: false });
    stain.rotation.x = -Math.PI / 2;
    stain.scale.set(1, 0.6 + r() * 0.6, 1);
    stain.position.set(-8 + r() * 16, 0.31 + i * 0.002, -1 + r() * 9);
    group.add(stain);
  }

  // Canopy on four pillars, red fascia with the brand in block letters, lights underneath.
  const cz = 4;
  const ch = 8;
  const cw = 18;
  const cd = 10;
  for (const x of [-cw / 2 + 2, cw / 2 - 2]) {
    for (const z of [cz - cd / 2 + 2, cz + cd / 2 - 2]) {
      const pillar = box(0.8, ch, 0.8, white, x, ch / 2, z);
      group.add(pillar, box(0.9, 1.2, 0.9, red, x, 0.9, z));
    }
  }
  // Rounded canopy: soft corners, bevelled fascia and a domed top.
  const place = (m, y) => {
    m.position.set(0, y, cz);
    group.add(m);
  };
  place(roundedSlab(cw, cd, 0.4, 2.6, white, 0.15), ch + 0.2);
  place(roundedSlab(cw + 0.3, cd + 0.3, 1.4, 2.8, red, 0.4), ch + 1.1);
  place(roundedSlab(cw + 0.45, cd + 0.45, 0.3, 2.85, yellow, 0.12), ch + 0.5);
  place(roundedSlab(cw - 0.4, cd - 0.4, 1.6, 2.6, red, 0.75), ch + 1.75);
  for (const x of [-5, 0, 5]) {
    for (const z of [cz - 2.5, cz + 2.5]) {
      const light = box(2.2, 0.08, 0.8, glow, x, ch - 0.02, z);
      light.castShadow = false;
      group.add(light);
    }
  }
  const brand = blockText('BUG OIL', 0.24, white);
  brand.position.set(0, ch + 1.1, cz + cd / 2 + 0.16);
  group.add(brand);
  const brandBack = blockText('BUG OIL', 0.24, white);
  brandBack.rotation.y = Math.PI;
  brandBack.position.set(0, ch + 1.1, cz - cd / 2 - 0.16);
  group.add(brandBack);

  // Two pump islands, two pumps each, hoses hooked on the side.
  for (const x of [-4, 4]) {
    group.add(box(1.8, 0.4, 7, yellow, x, 0.5, cz));
    group.add(box(1.5, 0.42, 6.7, concrete, x, 0.52, cz));
    for (const z of [cz - 1.8, cz + 1.8]) {
      const pump = new THREE.Group();
      pump.position.set(x, 0.7, z);
      pump.add(box(1.1, 3.2, 0.8, red, 0, 1.6, 0));
      pump.add(box(1.15, 0.5, 0.85, white, 0, 3.3, 0));
      pump.add(box(1.15, 0.25, 0.85, dark, 0, 0.12, 0));
      for (const side of [1, -1]) {
        const display = box(0.7, 0.45, 0.04, screen, 0, 2.5, side * 0.42);
        display.castShadow = false;
        pump.add(display);
        pump.add(box(0.5, 0.35, 0.05, dark, 0, 1.8, side * 0.42));
      }
      // Nozzle in its holster and a hose looping down.
      pump.add(box(0.15, 0.5, 0.3, dark, 0.62, 2.0, 0));
      pump.add(tube([[0.6, 1.8, 0], [0.9, 1.0, 0.15], [0.75, 0.3, 0.3], [0.62, 1.6, 0.05]], 0.07, dark, 12, 5));
      group.add(pump);
    }
  }

  // Shop at the back: glass front, door, sign band, roof units.
  const sx = -4;
  const sz = -7.5;
  const sw = 13;
  const sh = 5;
  const sd = 7;
  const shopBody = roundedSlab(sw, sd, sh, 1.4, white, 0.3);
  shopBody.position.set(sx, sh / 2 + 0.3, sz);
  group.add(shopBody);
  const shopRoof = roundedSlab(sw + 0.4, sd + 0.4, 1.1, 1.6, red, 0.4);
  shopRoof.position.set(sx, sh + 0.55 + 0.3, sz);
  const shopDome = roundedSlab(sw - 0.4, sd - 0.4, 1.2, 1.4, red, 0.55);
  shopDome.position.set(sx, sh + 1.2, sz);
  group.add(shopRoof, shopDome);
  const shop = blockText('SHOP', 0.2, white);
  shop.position.set(sx, sh + 0.85, sz + sd / 2 + 0.21);
  group.add(shop);
  for (let i = 0; i < 4; i++) {
    if (i === 1) continue;
    const pane = box(2.6, 3, 0.1, glass, sx - 4.5 + i * 3, 2.1, sz + sd / 2 + 0.03);
    group.add(pane, box(2.7, 0.15, 0.15, steel, sx - 4.5 + i * 3, 3.65, sz + sd / 2 + 0.05));
  }
  const shopDoor = box(2, 3.6, 0.12, glass, sx - 1.5, 2.1, sz + sd / 2 + 0.04);
  group.add(shopDoor, box(0.1, 3.6, 0.2, steel, sx - 2.5, 2.1, sz + sd / 2 + 0.06), box(0.1, 3.6, 0.2, steel, sx - 0.5, 2.1, sz + sd / 2 + 0.06));
  const lit = mat(C.windowLit, { emissive: C.windowLit, emissiveIntensity: 0.5 });
  group.add(box(sw - 0.6, 3.2, 0.02, lit, sx, 2.1, sz + sd / 2 - 0.05));
  group.add(box(2.4, 1, 1.8, steel, sx + 3, sh + 2.1, sz - 1), box(1.6, 0.8, 1.6, steel, sx - 3, sh + 2.0, sz + 0.5));
  // Ice chest and a stack of tyres by the door.
  group.add(box(2.2, 1.6, 1.2, mat(0x2f6ea8, { roughness: 0.5 }), sx + 4.5, 1.1, sz + sd / 2 + 0.8));
  const tyre = mat(0x1b1b1d, { roughness: 0.85 });
  for (let i = 0; i < 3; i++) {
    const t = mesh(new THREE.TorusGeometry(0.7, 0.32, 6, 14), tyre);
    t.rotation.x = Math.PI / 2;
    t.position.set(sx + 7.5 + (r() - 0.5) * 0.2, 0.62 + i * 0.6, sz + 2.5);
    group.add(t);
  }

  // Oil drums and an air pump on the side.
  const drumMats = [mat(0x2f5f8a, { roughness: 0.5 }), red, mat(0x3d6b3a, { roughness: 0.5 })];
  for (let i = 0; i < 3; i++) {
    const drum = mesh(new THREE.CylinderGeometry(0.75, 0.75, 2.2, 12), drumMats[i]);
    drum.position.set(6.5 + (i % 2) * 1.6, 1.4, -9 + i * 1.1);
    group.add(drum);
    for (const y of [0.6, 1.6]) {
      const ring = mesh(new THREE.TorusGeometry(0.76, 0.05, 4, 14), steel, { cast: false });
      ring.rotation.x = Math.PI / 2;
      ring.position.set(drum.position.x, y + 0.3, drum.position.z);
      group.add(ring);
    }
  }
  const tipped = mesh(new THREE.CylinderGeometry(0.75, 0.75, 2.2, 12), drumMats[0]);
  tipped.rotation.z = Math.PI / 2;
  tipped.rotation.y = 0.5;
  tipped.position.set(10, 1.05, -6);
  group.add(tipped);
  group.add(box(0.9, 2.6, 0.7, yellow, 11, 1.6, -1), box(0.95, 0.6, 0.75, dark, 11, 2.6, -1));
  group.add(tube([[11.45, 2.2, -1], [11.9, 1.2, -0.6], [11.6, 0.5, -0.2], [11.3, 1.6, -0.7]], 0.06, dark, 10, 5));

  // Price pylon at the corner: brand on top, three LED prices.
  const px = 12.5;
  const pz = 10;
  group.add(box(0.7, 15, 0.7, steel, px, 7.8, pz));
  group.add(box(5, 8, 0.6, red, px, 11, pz));
  group.add(box(5.2, 0.3, 0.7, yellow, px, 15.1, pz), box(5.2, 0.3, 0.7, yellow, px, 6.9, pz));
  for (const side of [1, -1]) {
    const face = new THREE.Group();
    face.position.set(px, 0, pz + side * 0.31);
    if (side < 0) face.rotation.y = Math.PI;
    const top = blockText('BUG', 0.36, white);
    top.position.y = 13.6;
    face.add(top);
    ['2.49', '2.79', '3.09'].forEach((price, i) => {
      face.add(box(4.2, 1.5, 0.06, dark, 0, 11.6 - i * 1.75, 0.03));
      const digits = blockText(price, 0.2, led, 0.08);
      digits.position.set(0, 11.6 - i * 1.75, 0.05);
      face.add(digits);
    });
    group.add(face);
  }
  // Trash piling up by the shop.
  const bag = createTrashBag({ seed: 43 });
  bag.position.set(sx - sw / 2 - 1.2, 0.3, sz + 2);
  const bag2 = createTrashBag({ seed: 44 });
  bag2.position.set(sx - sw / 2 - 1.5, 0.3, sz - 0.5);
  bag2.rotation.y = 1.2;
  const paper = createCrumpledPaper({ seed: 45 });
  paper.position.set(2, 0.3, -2);
  group.add(bag, bag2, paper);
  return tag(group, 'gas_station', { category: 'city', heightCm: 16 });
}

// Shared bits for the rounded street buildings below.
function neon(color, intensity = 2.2) {
  return mat(color, { emissive: color, emissiveIntensity: intensity });
}

function placed(m, x, y, z, ry = 0) {
  m.position.set(x, y, z);
  m.rotation.y = ry;
  return m;
}

// Concrete pad under a building, slightly bevelled.
function pad(w, d, material) {
  return placed(roundedSlab(w, d, 0.3, 1.2, material, 0.1), 0, 0.15, 0);
}

// Retro roadside diner, ~10 cm: a long capsule of chrome, glass and red, with a
// neon sign on the roof and a little entrance porch. Opens on +Z.
export function createDiner() {
  const group = new THREE.Group();
  const r = rng(51);
  const concrete = mat(0x8f8b83, { roughness: 0.95 });
  const chrome = mat(0xd5d8dc, { metalness: 0.85, roughness: 0.25 });
  const red = mat(0xb3261e, { roughness: 0.5 });
  const cream = mat(0xf1e8d2, { roughness: 0.6 });
  const mint = mat(0x7fc8b4, { roughness: 0.55 });
  const glass = mat(C.window, { roughness: 0.1, metalness: 0.35 });
  const lit = neon(C.windowLit, 0.6);
  const dark = mat(0x26272b, { roughness: 0.7 });
  const W = 18;
  const D = 7;
  group.add(pad(W + 6, D + 7, concrete));
  // Capsule body in horizontal bands: chrome skirt, window band, red stripe, cream top.
  group.add(placed(roundedSlab(W, D, 1.8, D / 2, chrome, 0.3), 0, 1.2, 0));
  group.add(placed(roundedSlab(W - 0.3, D - 0.3, 2.8, D / 2 - 0.15, glass, 0.1), 0, 3.5, 0));
  group.add(placed(roundedSlab(W - 0.9, D - 0.9, 2.6, D / 2 - 0.45, lit, 0.1), 0, 3.5, 0));
  group.add(placed(roundedSlab(W + 0.1, D + 0.1, 0.5, D / 2, red, 0.2), 0, 5.15, 0));
  group.add(placed(roundedSlab(W, D, 1.2, D / 2, cream, 0.35), 0, 5.9, 0));
  group.add(placed(roundedSlab(W + 0.6, D + 0.6, 0.5, D / 2 + 0.3, mint, 0.22), 0, 6.65, 0));
  group.add(placed(roundedSlab(W - 1.5, D - 1.5, 0.9, D / 2 - 0.75, cream, 0.4), 0, 7.1, 0));
  // Window mullions along the front and back.
  for (let i = -6; i <= 6; i++) {
    for (const side of [1, -1]) group.add(box(0.14, 2.8, 0.14, chrome, i * 1.15, 3.5, side * (D / 2 - 0.05)));
  }
  // Booth silhouettes behind the glass.
  for (let i = -5; i <= 5; i += 2) group.add(box(0.5, 1.4, 1.6, red, i * 1.15, 2.7, D / 2 - 1.3));
  // Entrance porch: a rounded red vestibule with a glass door.
  const porch = roundedSlab(3.4, 2.4, 4.6, 0.9, red, 0.3);
  group.add(placed(porch, 0, 2.6, D / 2 + 0.9));
  group.add(placed(roundedSlab(3.9, 2.9, 0.4, 1.1, chrome, 0.15), 0, 5.05, D / 2 + 0.9));
  group.add(box(1.8, 3.3, 0.1, glass, 0, 2, D / 2 + 2.12), box(0.12, 0.9, 0.12, chrome, 0.6, 2.2, D / 2 + 2.2));
  group.add(box(2.6, 0.3, 1.2, concrete, 0, 0.45, D / 2 + 2.6));
  // Roof sign on two posts: neon block letters on a rounded panel.
  for (const x of [-3, 3]) group.add(box(0.25, 1.6, 0.25, chrome, x, 8.2, 0));
  group.add(placed(roundedSlab(9, 0.5, 2.6, 0.25, dark, 0.2), 0, 9.9, 0));
  for (const side of [1, -1]) {
    const word = blockText('DINER', 0.36, neon(0xff3b4a), 0.1);
    word.position.set(0, 9.9, side * 0.26);
    if (side < 0) word.rotation.y = Math.PI;
    group.add(word);
  }
  // EAT pole sign by the road, and an air vent and trash out back.
  group.add(box(0.4, 9, 0.4, chrome, W / 2 + 1.5, 4.8, D / 2 + 2.5));
  group.add(placed(roundedSlab(3.6, 0.5, 2.2, 0.9, red, 0.2), W / 2 + 1.5, 9.4, D / 2 + 2.5));
  for (const side of [1, -1]) {
    const eat = blockText('EAT', 0.34, neon(0xfff2c8), 0.1);
    eat.position.set(W / 2 + 1.5, 9.4, D / 2 + 2.5 + side * 0.26);
    if (side < 0) eat.rotation.y = Math.PI;
    group.add(eat);
  }
  group.add(placed(roundedSlab(2, 2, 1, 0.6, chrome, 0.3), -5, 7.9, -1));
  const dumpster = createDumpster();
  group.add(placed(dumpster, -W / 2 - 1, 0.3, -D / 2 - 1.6, 0.2));
  const bag = createTrashBag({ seed: 52 });
  group.add(placed(bag, -W / 2 + 2.5, 0.3, -D / 2 - 2));
  group.add(placed(createCrumpledPaper({ seed: 53 }), 4 + r(), 0.3, D / 2 + 4));
  group.add(box(3, 0.6, 0.6, dark, -W / 2 - 1, 0.6, D / 2 + 2));
  return tag(group, 'diner', { category: 'city', heightCm: 11 });
}

// Corner liquor store, ~8 cm: soft brick block with a rounded corner, striped
// awning, barred windows and neon in the glass. Opens on +Z.
export function createLiquorStore() {
  const group = new THREE.Group();
  const concrete = mat(0x8f8b83, { roughness: 0.95 });
  const brick = mat(0xa5533a, { roughness: 0.85 });
  const trim = mat(0xe3d9c2, { roughness: 0.6 });
  const green = mat(0x2f6b3f, { roughness: 0.6 });
  const steel = mat(PALETTE.metal, { metalness: 0.7, roughness: 0.35 });
  const shutter = mat(0x7d8087, { metalness: 0.5, roughness: 0.5 });
  const glass = mat(C.window, { roughness: 0.1, metalness: 0.35 });
  const lit = neon(C.windowLit, 0.5);
  const W = 14;
  const D = 10;
  const H = 6;
  group.add(pad(W + 4, D + 4, concrete));
  group.add(placed(roundedSlab(W, D, H, 3, brick, 0.35), 0, H / 2 + 0.3, 0));
  // Parapet: a cream cornice and a rounded cap.
  group.add(placed(roundedSlab(W + 0.5, D + 0.5, 0.6, 3.2, trim, 0.25), 0, H + 0.2, 0));
  group.add(placed(roundedSlab(W - 0.8, D - 0.8, 0.8, 2.6, brick, 0.35), 0, H + 0.8, 0));
  // Shop front: two lit windows behind bars and a door, under a rounded awning.
  const fz = D / 2 + 0.03;
  for (const x of [-4, 3.2]) {
    group.add(box(4, 3, 0.1, glass, x, 2.5, fz), box(3.8, 2.8, 0.05, lit, x, 2.5, fz - 0.08));
    for (let i = 0; i < 9; i++) group.add(box(0.1, 3, 0.1, steel, x - 1.8 + i * 0.45, 2.5, fz + 0.15));
    group.add(box(4.2, 0.12, 0.12, steel, x, 1.05, fz + 0.15), box(4.2, 0.12, 0.12, steel, x, 3.95, fz + 0.15));
  }
  group.add(box(2, 3.8, 0.1, glass, -0.6, 2.2, fz), box(2.3, 0.2, 0.2, trim, -0.6, 4.2, fz + 0.05));
  // Roll-down shutter half closed over the door.
  for (let i = 0; i < 6; i++) group.add(box(2.2, 0.2, 0.08, shutter, -0.6, 4.05 - i * 0.22, fz + 0.12));
  // Awning: a quarter cylinder in green and cream stripes.
  for (let i = 0; i < 12; i++) {
    const g = new THREE.CylinderGeometry(1.3, 1.3, 1.0, 10, 1, true, 0, Math.PI / 2);
    g.rotateZ(Math.PI / 2);
    const strip = mesh(g, i % 2 ? trim : green);
    strip.position.set(-5.5 + i * 1.0, 4.4, fz);
    group.add(strip);
  }
  // Neon signs: LIQUOR on a board over the cornice, 24 in the window.
  group.add(placed(roundedSlab(9, 0.5, 2, 0.6, mat(0x26272b, { roughness: 0.7 }), 0.18), 0, H + 1.9, fz - 0.6));
  const word = blockText('LIQUOR', 0.3, neon(0x5fd0ff), 0.1);
  word.position.set(0, H + 1.9, fz - 0.33);
  group.add(word);
  const hours = blockText('24', 0.2, neon(0xff4fa3), 0.08);
  hours.position.set(3.2, 2.9, fz + 0.06);
  group.add(hours);
  // Side wall: a GTA tag stripe, roof units, a crate stack and trash.
  group.add(box(0.05, 1.2, 6, mat(0x5e2580, { roughness: 0.6 }), W / 2 + 0.02, 2, -0.5));
  group.add(box(2.2, 1, 1.8, steel, -3, H + 1.6, -2), box(1.4, 0.8, 1.4, steel, 3, H + 1.5, -1.5));
  for (let i = 0; i < 3; i++) group.add(box(1.4, 1, 1.4, mat(0xc49a6c), W / 2 + 1, 0.8 + i * 1.02, -3 + (i % 2) * 0.2));
  group.add(placed(createTrashBag({ seed: 61 }), -W / 2 - 1, 0.3, 1.5));
  group.add(placed(createCrumpledPaper({ seed: 62 }), 2.5, 0.3, D / 2 + 1.6));
  return tag(group, 'liquor_store', { category: 'city', heightCm: 9 });
}

// Auto repair garage, ~9 cm: a corrugated half-round hangar with a roll-up door,
// a rounded office on the side, tyres and drums. Opens on +Z.
export function createGarage() {
  const group = new THREE.Group();
  const r = rng(71);
  const concrete = mat(0x8f8b83, { roughness: 0.95 });
  const tin = mat(0x9aa3a8, { metalness: 0.6, roughness: 0.45 });
  const rust = mat(0x8a4b2a, { roughness: 0.8 });
  const yellow = mat(0xf0b92a, { roughness: 0.5 });
  const white = mat(0xe9e5da, { roughness: 0.6 });
  const dark = mat(0x26272b, { roughness: 0.7 });
  const steel = mat(PALETTE.metal, { metalness: 0.7, roughness: 0.35 });
  const glass = mat(C.window, { roughness: 0.1, metalness: 0.35 });
  const R = 6;
  const L = 14;
  group.add(pad(2 * R + 10, L + 6, concrete));
  // Hangar: an extruded half disc, with ribs every metre and a rust streak.
  const arch = new THREE.Shape();
  arch.absarc(0, 0, R, 0, Math.PI, false);
  arch.lineTo(R, 0);
  const shell = new THREE.ExtrudeGeometry(arch, { depth: L, bevelEnabled: false, curveSegments: 24 });
  shell.translate(0, 0, -L / 2);
  group.add(placed(mesh(shell, tin), -2, 0.3, 0));
  for (let i = 0; i <= L; i += 1.4) {
    const rib = mesh(new THREE.TorusGeometry(R + 0.04, 0.07, 4, 24, Math.PI), i % 2.8 < 1 ? tin : steel, { cast: false });
    group.add(placed(rib, -2, 0.3, -L / 2 + i));
  }
  const streak = mesh(new THREE.TorusGeometry(R + 0.06, 0.5, 3, 8, 0.5), rust, { cast: false });
  streak.position.set(-2, 0.3, 2);
  streak.rotation.z = 1.1;
  group.add(streak);
  // Front: roll-up door (half up), yellow frame, sign.
  const fz = L / 2 + 0.05;
  group.add(box(7.4, 0.4, 0.3, yellow, -2, 5.3, fz), box(0.4, 5.1, 0.3, yellow, -5.7, 2.85, fz), box(0.4, 5.1, 0.3, yellow, 1.7, 2.85, fz));
  for (let i = 0; i < 6; i++) group.add(box(7, 0.38, 0.1, steel, -2, 5 - i * 0.4, fz));
  group.add(box(7, 2.6, 0.05, dark, -2, 1.6, fz - 0.4));
  const sign = blockText('GARAGE', 0.24, white, 0.1);
  sign.position.set(-2, 6.4, fz);
  group.add(placed(roundedSlab(6.4, 0.3, 1.8, 0.5, mat(0xb3261e, { roughness: 0.5 }), 0.12), -2, 6.4, fz - 0.15), sign);
  // Rounded office on the right with a window and a door.
  group.add(placed(roundedSlab(5, 6, 4.4, 1.5, white, 0.3), R + 0.5, 2.5, 3));
  group.add(placed(roundedSlab(5.4, 6.4, 0.6, 1.7, yellow, 0.25), R + 0.5, 4.9, 3));
  group.add(box(2.4, 1.6, 0.1, glass, R + 0.2, 2.8, 6.03), box(1.2, 3, 0.1, glass, R + 2.1, 1.8, 6.03));
  // Tyre stacks, drums, a jack and an engine block outside.
  const tyre = mat(0x1b1b1d, { roughness: 0.85 });
  for (const [x, z, n] of [[3.5, 9, 4], [5, 10.2, 2], [-8.5, 5, 3]]) {
    for (let i = 0; i < n; i++) {
      const t = mesh(new THREE.TorusGeometry(0.7, 0.32, 6, 14), tyre);
      t.rotation.x = Math.PI / 2;
      group.add(placed(t, x + (r() - 0.5) * 0.25, 0.62 + i * 0.6, z));
    }
  }
  const drumMats = [mat(0x2f5f8a, { roughness: 0.5 }), rust];
  for (let i = 0; i < 3; i++) {
    const drum = mesh(new THREE.CylinderGeometry(0.75, 0.75, 2.2, 12), drumMats[i % 2]);
    group.add(placed(drum, -9 + (i % 2) * 1.5, 1.4, -4 + i * 1.6));
  }
  group.add(box(1.6, 0.4, 0.8, mat(0xb3261e), 0.5, 0.5, 9.5), box(0.15, 1.6, 0.15, steel, 0.9, 1.2, 9.5));
  group.add(box(1.8, 1.2, 1.2, dark, -4.5, 0.9, 9.8), box(1.2, 0.5, 0.8, steel, -4.5, 1.7, 9.8));
  group.add(placed(createTrashBag({ seed: 72 }), R + 3.5, 0.3, -2));
  return tag(group, 'garage', { category: 'city', heightCm: 8 });
}

// Two-storey roadside motel, ~10 cm: a long block with rounded ends, an outdoor
// walkway, a kidney pool and a tall neon sign. Opens on +Z.
export function createMotel() {
  const group = new THREE.Group();
  const concrete = mat(0x8f8b83, { roughness: 0.95 });
  const peach = mat(0xe9b58f, { roughness: 0.7 });
  const teal = mat(0x2f8f8a, { roughness: 0.55 });
  const white = mat(0xe9e5da, { roughness: 0.6 });
  const steel = mat(PALETTE.metal, { metalness: 0.7, roughness: 0.35 });
  const glass = mat(C.window, { roughness: 0.1, metalness: 0.35 });
  const water = mat(0x3fb6d8, { roughness: 0.1, metalness: 0.1, emissive: 0x1d6f8a, emissiveIntensity: 0.3 });
  const W = 24;
  const D = 6;
  const floor = 3.6;
  group.add(pad(W + 8, D + 16, concrete));
  const bz = -4;
  group.add(placed(roundedSlab(W, D, floor * 2, 2.2, peach, 0.3), 0, floor + 0.3, bz));
  group.add(placed(roundedSlab(W + 2, D + 3, 0.6, 2.8, teal, 0.25), 0, floor * 2 + 0.6, bz + 0.8));
  group.add(placed(roundedSlab(W - 1, D - 1, 0.6, 2, white, 0.25), 0, floor * 2 + 1.1, bz));
  // Upper walkway with a rail on posts, stairs at the end.
  const fz = bz + D / 2;
  group.add(box(W - 3, 0.3, 1.8, white, 0, floor + 0.3, fz + 0.9));
  for (let x = -W / 2 + 2; x <= W / 2 - 2; x += 2.5) group.add(box(0.25, floor, 0.25, white, x, floor / 2 + 0.3, fz + 1.7));
  group.add(box(W - 3, 0.12, 0.12, steel, 0, floor + 1.5, fz + 1.75));
  for (let x = -W / 2 + 2; x <= W / 2 - 2; x += 0.6) group.add(box(0.06, 1.2, 0.06, steel, x, floor + 0.9, fz + 1.75));
  for (let i = 0; i < 8; i++) group.add(box(0.55, 0.2, 1.6, white, (W - 3) / 2 + 0.3 + i * 0.5, floor + 0.2 - (i + 1) * 0.45, fz + 0.9));
  group.add(segment([(W - 3) / 2, floor + 0.3, fz + 1.75], [(W - 3) / 2 + 4.3, 0.4, fz + 1.75], 0.08, steel));
  // Doors and windows, numbered by colour: one teal door and a lit window per room.
  for (let k = 0; k < 6; k++) {
    const x = -W / 2 + 2.8 + k * 3.6;
    for (const y of [0.3, floor + 0.45]) {
      group.add(box(1.1, 2.4, 0.1, teal, x, y + 1.2, fz + 0.03));
      const on = (k + (y > 1 ? 1 : 0)) % 3 === 0;
      group.add(box(1.4, 1.1, 0.1, on ? neon(C.windowLit, 0.6) : glass, x + 1.4, y + 1.6, fz + 0.03));
    }
  }
  // Kidney pool: two overlapping rounded basins with a white rim.
  for (const [x, z, w, d] of [[-4, 7, 9, 5], [1, 8, 6, 4]]) {
    group.add(placed(roundedSlab(w + 0.8, d + 0.8, 0.45, 2.2, white, 0.15), x, 0.4, z));
    group.add(placed(roundedSlab(w, d, 0.1, 1.9, water, 0.04), x, 0.66, z));
  }
  group.add(box(0.1, 1.4, 0.1, steel, -8.3, 1.1, 6.5), box(0.1, 1.4, 0.1, steel, -8.3, 1.1, 7.3));
  // Tall sign: a rounded panel with MOTEL and a VACANCY strip, on a pole.
  const sx = W / 2 + 2.5;
  const sz = 9;
  group.add(box(0.5, 13, 0.5, steel, sx, 6.8, sz));
  group.add(placed(roundedSlab(7, 0.6, 3.2, 1.2, teal, 0.25), sx, 12.6, sz));
  group.add(placed(roundedSlab(6, 0.5, 1.2, 0.5, white, 0.2), sx, 10.2, sz));
  for (const side of [1, -1]) {
    const word = blockText('MOTEL', 0.3, neon(0xff4fa3), 0.1);
    word.position.set(sx, 12.6, sz + side * 0.31);
    const vac = blockText('VACANCY', 0.16, neon(0xff3b4a), 0.08);
    vac.position.set(sx, 10.2, sz + side * 0.26);
    if (side < 0) {
      word.rotation.y = Math.PI;
      vac.rotation.y = Math.PI;
    }
    group.add(word, vac);
  }
  group.add(placed(createDumpster(), -W / 2 - 2, 0.3, bz, Math.PI / 2));
  group.add(placed(createCrumpledPaper({ seed: 81 }), 5, 0.3, 4));
  return tag(group, 'motel', { category: 'city', heightCm: 14 });
}

// Street trash bin, ~3 cm: a green municipal bin at bug scale.
export function createTrashBin() {
  const group = new THREE.Group();
  const green = mat(C.binGreen, { roughness: 0.6 });
  const body = mesh(new THREE.CylinderGeometry(1.1, 0.95, 2.6, 10), green);
  body.position.y = 1.3;
  group.add(body);
  const lid = mesh(new THREE.CylinderGeometry(1.25, 1.2, 0.35, 10), green);
  lid.position.y = 2.75;
  group.add(lid);
  const ring = mesh(new THREE.TorusGeometry(1.0, 0.07, 4, 12), mat(PALETTE.metal, { metalness: 0.7, roughness: 0.3 }));
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 1.9;
  group.add(ring);
  // A crumpled scrap sticking out.
  const scrap = blob(0.45, 0.4, 0.45, mat(C.paper), 0);
  scrap.position.set(0.3, 3.05, 0.2);
  group.add(scrap);
  return tag(group, 'trash_bin', { category: 'city', heightCm: 3.3 });
}

// Matchbox dumpster behind the buildings.
export function createDumpster() {
  const group = new THREE.Group();
  const blue = mat(0x2d5f8a, { roughness: 0.6 });
  group.add(box(5, 2.6, 3, blue, 0, 1.5, 0));
  const lid = box(5.1, 0.2, 3.1, mat(0x1f1f22, { roughness: 0.7 }));
  lid.geometry.translate(0, 0, 1.55);
  lid.position.set(0, 2.85, -1.55);
  lid.rotation.x = -0.6;
  group.add(lid);
  for (const x of [-2, 2]) {
    for (const z of [-1.1, 1.1]) {
      const wheel = mesh(new THREE.CylinderGeometry(0.25, 0.25, 0.2, 8), mat(PALETTE.black));
      wheel.rotation.x = Math.PI / 2;
      wheel.position.set(x, 0.25, z);
      group.add(wheel);
    }
  }
  const bag = blob(1.2, 0.9, 1.0, mat(C.bag, { roughness: 0.35 }));
  jitter(bag.geometry, 0.2, 9);
  bag.position.set(-0.8, 3.1, 0.2);
  group.add(bag);
  return tag(group, 'dumpster', { category: 'city', heightCm: 4 });
}

// Black garbage bag, tied at the top, ~4 cm.
export function createTrashBag({ seed = 4 } = {}) {
  const group = new THREE.Group();
  const plastic = mat(C.bag, { roughness: 0.3 });
  const g = new THREE.IcosahedronGeometry(1.8, 1);
  g.scale(1, 0.85, 0.9);
  jitter(g, 0.5, seed);
  const bag = mesh(g, plastic);
  bag.position.y = 1.4;
  group.add(bag);
  const neck = mesh(new THREE.ConeGeometry(0.6, 1.2, 6), plastic);
  neck.position.y = 3.1;
  group.add(neck);
  for (const side of [1, -1]) {
    const ear = blob(0.5, 0.2, 0.25, plastic, 0);
    ear.position.set(side * 0.45, 3.7, 0);
    ear.rotation.z = side * 0.6;
    group.add(ear);
  }
  return tag(group, 'trash_bag', { category: 'city', heightCm: 3.9 });
}

// Crumpled paper ball, ~3 cm.
export function createCrumpledPaper({ seed = 5 } = {}) {
  const g = new THREE.IcosahedronGeometry(1.4, 1);
  jitter(g, 0.9, seed);
  const ball = mesh(g, mat(C.paper, { roughness: 0.9 }));
  ball.position.y = 1.2;
  return tag(new THREE.Group().add(ball), 'crumpled_paper', { category: 'city', heightCm: 2.6 });
}

// Cigarette butt, 3 cm long: a log on the sidewalk.
export function createCigaretteButt() {
  const group = new THREE.Group();
  const filter = mesh(new THREE.CylinderGeometry(0.4, 0.4, 1.8, 8), mat(C.filter, { roughness: 0.9 }));
  filter.rotation.z = Math.PI / 2;
  filter.position.set(-0.6, 0.4, 0);
  const paper = mesh(new THREE.CylinderGeometry(0.39, 0.39, 1.2, 8), mat(C.paper, { roughness: 0.9 }));
  paper.rotation.z = Math.PI / 2;
  paper.position.set(0.9, 0.4, 0);
  const ash = mesh(new THREE.CylinderGeometry(0.36, 0.3, 0.2, 8), mat(0x555048));
  ash.rotation.z = Math.PI / 2;
  ash.position.set(1.6, 0.4, 0);
  group.add(filter, paper, ash);
  group.rotation.y = 0.4;
  return tag(new THREE.Group().add(group), 'cigarette_butt', { category: 'city', heightCm: 0.8 });
}

// Empty plastic water bottle lying on its side, 20 cm: a crystal tunnel.
export function createPlasticBottle() {
  const profile = [
    [0, 0], [3, 0.1], [3.2, 0.6], [3.2, 13], [2.6, 15], [1.3, 17], [1.3, 19], [1.5, 19.2], [1.5, 20], [0, 20],
  ].map(([x, y]) => new THREE.Vector2(x, y));
  const g = new THREE.LatheGeometry(profile, 14);
  const body = mesh(g, mat(C.bottle, { transparent: true, opacity: 0.45, roughness: 0.1, side: THREE.DoubleSide, depthWrite: false }));
  const cap = mesh(new THREE.CylinderGeometry(1.55, 1.55, 1, 12), mat(0x2f7ad8, { roughness: 0.4 }));
  cap.position.y = 19.6;
  const label = mesh(new THREE.CylinderGeometry(3.25, 3.25, 5, 14, 1, true), mat(0x4aa3df, { side: THREE.DoubleSide }));
  label.position.y = 7;
  const inner = new THREE.Group().add(body, cap, label);
  inner.rotation.z = Math.PI / 2;
  inner.position.set(10, 3.2, 0);
  return tag(new THREE.Group().add(inner), 'plastic_bottle', { category: 'city', heightCm: 6.4 });
}

// Fire hydrant, ~2.5 cm: a red bug-scale hydrant for the sidewalk.
export function createFireHydrant() {
  const group = new THREE.Group();
  const red = mat(C.hydrant, { roughness: 0.45 });
  const base = mesh(new THREE.CylinderGeometry(0.75, 0.8, 0.25, 10), red);
  base.position.y = 0.12;
  const body = mesh(new THREE.CylinderGeometry(0.55, 0.6, 1.6, 10), red);
  body.position.y = 1;
  const collar = mesh(new THREE.CylinderGeometry(0.68, 0.68, 0.2, 10), red);
  collar.position.y = 1.85;
  const dome = mesh(new THREE.SphereGeometry(0.55, 10, 5, 0, Math.PI * 2, 0, Math.PI / 2), red);
  dome.position.y = 1.95;
  const nut = mesh(new THREE.CylinderGeometry(0.15, 0.18, 0.3, 5), red);
  nut.position.y = 2.6;
  group.add(base, body, collar, dome, nut);
  const metal = mat(PALETTE.metal, { metalness: 0.7, roughness: 0.3 });
  for (const [x, z, r] of [[0.7, 0, 0.22], [-0.7, 0, 0.22], [0, 0.72, 0.3]]) {
    const outlet = mesh(new THREE.CylinderGeometry(r, r, 0.4, 8), red);
    outlet.position.set(x * 0.95, 1.2, z * 0.95);
    outlet.lookAt(outlet.position.clone().add(new THREE.Vector3(x, 0, z)));
    outlet.rotateX(Math.PI / 2);
    group.add(outlet);
    const cap = mesh(new THREE.CylinderGeometry(r * 0.8, r * 0.8, 0.12, 5), metal);
    cap.position.set(x * 1.25, 1.2, z * 1.25);
    cap.lookAt(cap.position.clone().add(new THREE.Vector3(x, 0, z)));
    cap.rotateX(Math.PI / 2);
    group.add(cap);
  }
  return tag(group, 'fire_hydrant', { category: 'city', heightCm: 2.75 });
}

// Street lamp made from a burnt matchstick and a glowing bead.
export function createStreetLamp() {
  const group = new THREE.Group();
  const wood = mat(PALETTE.wood, { roughness: 0.9 });
  group.add(box(0.3, 9, 0.3, wood, 0, 4.5, 0));
  group.add(box(2.2, 0.25, 0.25, wood, 1, 9, 0));
  const head = blob(0.45, 0.35, 0.45, mat(0x3a2a22), 0);
  head.position.set(2, 8.95, 0);
  group.add(head);
  const bulb = blob(0.3, 0.3, 0.3, mat(0xfff1b8, { emissive: 0xffd36b, emissiveIntensity: 2 }), 1);
  bulb.position.set(2, 8.6, 0);
  bulb.castShadow = false;
  group.add(bulb);
  return tag(group, 'street_lamp', { category: 'city', heightCm: 9.4 });
}

// ---- Zone props -----------------------------------------------------------

// Spider web stretched between two buildings (Tisseuses alleys).
// Vertical, faces +Z, spans `width` x `height` with its bottom at `bottom`.
export function createSpiderWeb({ width = 14, height = 12, bottom = 3, seed = 6 } = {}) {
  const r = rng(seed);
  const group = new THREE.Group();
  const silk = mat(0xf4f6f8, { emissive: 0xc9d6e6, emissiveIntensity: 0.35, roughness: 0.3, transparent: true, opacity: 0.85 });
  const cx = 0;
  const cy = bottom + height / 2;
  const thread = (a, b, rad = 0.05) => {
    const t = segment([a[0], a[1], 0], [b[0], b[1], 0], rad, silk, 3);
    t.castShadow = false;
    group.add(t);
  };
  // Frame threads to the corners, then spokes and a spiral.
  const spokes = 12;
  const ends = [];
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2 + r() * 0.1;
    const rx = (width / 2) * (0.85 + r() * 0.15);
    const ry = (height / 2) * (0.85 + r() * 0.15);
    ends.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]);
    thread([cx, cy], ends[i], 0.04);
  }
  for (let i = 0; i < spokes; i++) thread(ends[i], ends[(i + 1) % spokes], 0.06);
  const turns = 7;
  let prev = null;
  for (let k = 0; k <= turns * spokes; k++) {
    const i = k % spokes;
    const f = 0.12 + (0.8 * k) / (turns * spokes);
    const p = [cx + (ends[i][0] - cx) * f, cy + (ends[i][1] - cy) * f];
    if (prev) thread(prev, p, 0.03);
    prev = p;
  }
  return tag(group, 'spider_web', { category: 'zone', heightCm: bottom + height });
}

// Sardine tin warehouse on the docks (Prieurs). Lid rolled back on its key.
export function createWarehouse() {
  const group = new THREE.Group();
  const tin = mat(0xb9c0c8, { metalness: 0.75, roughness: 0.35 });
  const w = 16;
  const d = 10;
  const h = 5;
  group.add(box(w, h, d, tin, 0, h / 2, 0));
  group.add(box(w + 0.03, 3, d + 0.03, mat(0x2a5d9c, { roughness: 0.6 }), 0, 2, 0));
  const fish = mesh(new THREE.ConeGeometry(0.9, 3.5, 4), mat(0xe9e4d6), { cast: false });
  fish.rotation.z = Math.PI / 2;
  fish.scale.set(1, 1, 0.1);
  fish.position.set(-2, 2, d / 2 + 0.1);
  group.add(fish);
  // Rolled lid along the back edge.
  const roll = mesh(new THREE.CylinderGeometry(1.2, 1.2, w * 0.95, 12), tin);
  roll.rotation.z = Math.PI / 2;
  roll.position.set(0, h + 1.2, -d / 2 + 0.5);
  group.add(roll);
  group.add(segment([w / 2 - 0.5, h + 1.2, -d / 2 + 0.5], [w / 2 + 2, h + 1.2, -d / 2 + 0.5], 0.2, tin));
  // Loading door and a pallet of matchsticks.
  const doorway = box(4, 3.5, 0.2, mat(0x1c1f24), 3.5, 1.75, d / 2 + 0.05);
  group.add(doorway);
  const wood = mat(PALETTE.wood, { roughness: 0.9 });
  for (let i = 0; i < 5; i++) group.add(box(4, 0.3, 0.3, wood, 3.5, 0.15, d / 2 + 1.5 + i * 0.6));
  for (let i = 0; i < 3; i++) group.add(box(0.3, 0.3, 3, wood, 2 + i * 1.5, 0.45, d / 2 + 2.7));
  return tag(group, 'warehouse', { category: 'zone', heightCm: h + 2.4 });
}

// Puddle for the docks: a flat, glossy water surface.
export function createPuddle({ seed = 7, size = 30 } = {}) {
  const r = rng(seed);
  const shape = new THREE.Shape();
  const n = 14;
  for (let i = 0; i <= n; i++) {
    const a = (i / n) * Math.PI * 2;
    const rad = (size / 2) * (0.75 + r() * 0.25);
    const x = Math.cos(a) * rad;
    const y = Math.sin(a) * rad * 0.7;
    if (i === 0) shape.moveTo(x, y);
    else shape.lineTo(x, y);
  }
  const g = new THREE.ShapeGeometry(shape);
  g.rotateX(-Math.PI / 2);
  const water = mesh(g, mat(0x3f6f8f, { roughness: 0.05, metalness: 0.2, transparent: true, opacity: 0.85 }), { cast: false });
  water.position.y = 0.05;
  return tag(new THREE.Group().add(water), 'puddle', { category: 'zone', heightCm: 0.05 });
}

// Anthill mound with an entrance (Colonie).
export function createAnthill({ seed = 8 } = {}) {
  const g = new THREE.ConeGeometry(9, 7, 14, 4).toNonIndexed();
  g.translate(0, 3.5, 0);
  jitter(g, 0.9, seed);
  const group = new THREE.Group();
  group.add(mesh(g, mat(0x8a6a44, { roughness: 1 })));
  const hole = mesh(new THREE.CircleGeometry(1.4, 8), mat(0x1c140d), { cast: false });
  hole.rotation.x = -Math.PI / 2;
  hole.position.y = 7.05;
  group.add(hole);
  const side = mesh(new THREE.CircleGeometry(1, 8), mat(0x1c140d), { cast: false });
  side.position.set(0, 1.6, 7.6);
  side.rotation.x = -0.6;
  group.add(side);
  return tag(group, 'anthill', { category: 'zone', heightCm: 7.5 });
}

// Building-site scaffolding from popsicle sticks (Colonie), three floors.
export function createScaffolding() {
  const group = new THREE.Group();
  const stick = mat(0xe3c38f, { roughness: 0.9 });
  const w = 14;
  const d = 4;
  const floorH = 5;
  for (const x of [-w / 2, 0, w / 2]) {
    for (const z of [-d / 2, d / 2]) group.add(box(0.4, floorH * 3, 0.4, stick, x, (floorH * 3) / 2, z));
  }
  for (let f = 1; f <= 3; f++) {
    for (let i = 0; i < 4; i++) group.add(box(w + 0.8, 0.15, 0.9, stick, 0, f * floorH, -d / 2 + 0.5 + i * 1));
    // Cross braces on the front.
    const brace = box(Math.hypot(w / 2, floorH), 0.12, 0.3, stick, -w / 4, (f - 0.5) * floorH, d / 2 + 0.2);
    brace.rotation.z = Math.atan2(floorH, w / 2);
    group.add(brace);
  }
  // A toy brick pallet on the top floor.
  group.add(box(3.2, 1, 1.6, mat(PALETTE.toyRed, { roughness: 0.3 }), 3, floorH * 3 + 0.6, 0));
  return tag(group, 'scaffolding', { category: 'zone', heightCm: floorH * 3 + 1.1 });
}
