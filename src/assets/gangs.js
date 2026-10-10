// Gang identities for the territories on the map. Two gangs show their colours
// (a bandana, like Bloods and Crips), two wear tattoos. Each gang also has an
// emblem used on flags, graffiti tags and territory markers.
import * as THREE from 'three';
import { PALETTE, mat, mesh, tube, tag } from './common.js';
import { createPebble } from './nature.js';

export const GANGS = {
  tisseuses: { id: 'tisseuses', label: 'Les Tisseuses', species: 'spider', style: 'tattoo', color: 0x7b3fa0, ink: 0xf4f1ea, emblem: 'web' },
  prieurs: { id: 'prieurs', label: 'Les Prieurs', species: 'mantis', style: 'colors', color: 0xc8202a, ink: 0xf4f1ea, emblem: 'claw' },
  nuee: { id: 'nuee', label: 'La Nuée', species: 'fly', style: 'colors', color: 0x1f5fd1, ink: 0xf4f1ea, emblem: 'eye' },
  colonie: { id: 'colonie', label: 'La Colonie', species: 'ant', style: 'tattoo', color: 0xf08a1c, ink: 0xf08a1c, emblem: 'chevrons' },
};

function gangOf(id) {
  const gang = GANGS[id];
  if (!gang) throw new Error(`Unknown gang "${id}"`);
  return gang;
}

function flatBar(x1, y1, x2, y2, width, material) {
  const len = Math.hypot(x2 - x1, y2 - y1);
  const bar = mesh(new THREE.BoxGeometry(len, width, width * 0.3), material, { cast: false });
  bar.position.set((x1 + x2) / 2, (y1 + y2) / 2, 0);
  bar.rotation.z = Math.atan2(y2 - y1, x2 - x1);
  return bar;
}

// Emblem drawn flat in the XY plane, facing +Z, about 1 unit across.
export function createEmblem(gangId, color) {
  const gang = gangOf(gangId);
  const m = mat(color ?? gang.ink, { side: THREE.DoubleSide, roughness: 0.6 });
  const g = new THREE.Group();
  if (gang.emblem === 'web') {
    const spokes = 8;
    const w = 0.045;
    for (let i = 0; i < spokes; i++) {
      const a = (i / spokes) * Math.PI * 2;
      g.add(flatBar(0, 0, Math.cos(a) * 0.5, Math.sin(a) * 0.5, w, m));
    }
    for (const r of [0.17, 0.32, 0.47]) {
      for (let i = 0; i < spokes; i++) {
        const a1 = (i / spokes) * Math.PI * 2;
        const a2 = ((i + 1) / spokes) * Math.PI * 2;
        g.add(flatBar(Math.cos(a1) * r, Math.sin(a1) * r, Math.cos(a2) * r, Math.sin(a2) * r, w * 0.8, m));
      }
    }
  } else if (gang.emblem === 'claw') {
    // Two raptorial claws crossed in a V.
    for (const side of [1, -1]) {
      const s = new THREE.Shape();
      s.moveTo(side * 0.05, -0.45);
      s.lineTo(side * 0.45, 0.35);
      s.lineTo(side * 0.3, 0.5);
      s.lineTo(side * 0.32, 0.3);
      s.lineTo(side * -0.08, -0.35);
      s.lineTo(side * 0.05, -0.45);
      g.add(mesh(new THREE.ShapeGeometry(s), m, { cast: false }));
    }
  } else if (gang.emblem === 'eye') {
    // Compound eye: a cluster of hexagons.
    const cells = [[0, 0], [0.3, 0.17], [0, 0.34], [-0.3, 0.17], [-0.3, -0.17], [0, -0.34], [0.3, -0.17]];
    for (const [x, y] of cells) {
      const hex = mesh(new THREE.CircleGeometry(0.15, 6), m, { cast: false });
      hex.position.set(x, y, 0);
      g.add(hex);
    }
  } else if (gang.emblem === 'chevrons') {
    for (let i = 0; i < 3; i++) {
      const y = -0.3 + i * 0.3;
      g.add(flatBar(-0.4, y - 0.15, 0, y + 0.1, 0.1, m));
      g.add(flatBar(0, y + 0.1, 0.4, y - 0.15, 0.1, m));
    }
  }
  return g;
}

function anchorParent(object, anchor) {
  return anchor.parent ? object.getObjectByName(anchor.parent) : object;
}

// Dress a creature in a gang's signature: a bandana for colour gangs,
// a tattoo on the back for tattoo gangs. Works on any creature that
// exposes `userData.anchors` (fly, mantis, ant, spider).
export function applyGang(object, gangId) {
  const gang = gangOf(gangId);
  const anchors = object.userData.anchors;
  if (!anchors) throw new Error(`${object.name} has no gang anchors`);
  if (gang.style === 'colors') {
    const { position, radius } = anchors.neck;
    const cloth = mat(gang.color, { roughness: 0.9, side: THREE.DoubleSide });
    const band = new THREE.Group();
    band.position.set(...position);
    const ring = mesh(new THREE.TorusGeometry(radius * 1.1, radius * 0.38, 4, 12), cloth);
    ring.scale.set(1, 1, 1.4);
    band.add(ring);
    // The knotted triangle hanging under the chin.
    const flap = mesh(new THREE.ConeGeometry(radius * 1.1, radius * 1.8, 3), cloth);
    flap.rotation.z = Math.PI;
    flap.scale.set(1, 1, 0.35);
    flap.position.set(0, -radius * 1.8, radius * 0.3);
    band.add(flap);
    band.name = 'gang_bandana';
    anchorParent(object, anchors.neck).add(band);
  } else {
    const { position, size, tilt = 0 } = anchors.back;
    const tattoo = createEmblem(gang.id);
    tattoo.scale.setScalar(size * 2.2);
    tattoo.rotation.x = -Math.PI / 2 + tilt;
    tattoo.position.set(...position);
    tattoo.name = 'gang_tattoo';
    anchorParent(object, anchors.back).add(tattoo);
  }
  object.userData.gang = gang.id;
  return object;
}

// Gang flag on a twig pole, ~14 cm tall. Waves when updated.
export function createGangFlag(gangId) {
  const gang = gangOf(gangId);
  const group = new THREE.Group();
  const pole = 14;
  group.add(tube([[0, 0, 0], [0.3, pole * 0.5, 0.1], [0, pole, 0]], 0.3, mat(PALETTE.bark), 8, 5));
  const W = 7;
  const H = 4.5;
  const clothG = new THREE.PlaneGeometry(W, H, 8, 3);
  clothG.translate(W / 2, 0, 0);
  const base = clothG.attributes.position.array.slice();
  const banner = mesh(clothG, mat(gang.color, { side: THREE.DoubleSide, roughness: 0.9 }));
  banner.position.set(0.2, pole - H / 2 - 0.3, 0);
  const front = createEmblem(gang.id, gang.style === 'tattoo' && gang.ink === gang.color ? PALETTE.black : gang.ink);
  front.scale.setScalar(3.4);
  front.position.set(W / 2, 0, 0.12);
  banner.add(front);
  group.add(banner);
  group.userData.update = (t) => {
    const pos = clothG.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const x = base[i * 3];
      pos.setZ(i, Math.sin(x * 0.9 - t * 4) * x * 0.09);
    }
    pos.needsUpdate = true;
    clothG.computeVertexNormals();
    front.position.z = 0.12 + Math.sin(W / 2 * 0.9 - t * 4) * (W / 2) * 0.09;
  };
  return tag(group, `flag_${gang.id}`, { category: 'gang', heightCm: pole, animated: true });
}

// Graffiti tag: the emblem sprayed on a round splash of gang colour.
// Stands upright facing +Z; stick it on a can, a rock or a brick.
export function createGangTag(gangId, { size = 4 } = {}) {
  const gang = gangOf(gangId);
  const group = new THREE.Group();
  const splash = mesh(new THREE.CircleGeometry(size / 2, 9), mat(gang.color, { side: THREE.DoubleSide, roughness: 0.95 }), { cast: false });
  group.add(splash);
  for (let i = 0; i < 3; i++) {
    const drip = mesh(new THREE.PlaneGeometry(size * 0.05, size * (0.15 + i * 0.08)), splash.material, { cast: false });
    drip.position.set(-size * 0.2 + i * size * 0.2, -size * (0.5 + i * 0.03), 0);
    group.add(drip);
  }
  const emblem = createEmblem(gang.id, gang.ink === gang.color ? PALETTE.black : gang.ink);
  emblem.scale.setScalar(size * 0.75);
  emblem.position.z = 0.03;
  group.add(emblem);
  group.position.y = size * 0.75;
  return tag(new THREE.Group().add(group), `tag_${gang.id}`, { category: 'gang', heightCm: size * 1.3 });
}

// Territory marker: a little cairn of stones with a painted band and emblem.
export function createTerritoryMarker(gangId, { seed = 11 } = {}) {
  const gang = gangOf(gangId);
  const group = new THREE.Group();
  let y = 0;
  [3.2, 2.4, 1.6].forEach((size, i) => {
    const stone = createPebble({ seed: seed + i, size });
    stone.position.y = y;
    stone.rotation.y = i * 1.3;
    group.add(stone);
    y += size * 0.9;
  });
  // The middle stone is painted in the gang colour.
  group.children[1].traverse((o) => { if (o.isMesh) o.material = mat(gang.color, { roughness: 0.95 }); });
  const top = createEmblem(gang.id, gang.ink === gang.color ? PALETTE.black : gang.ink);
  top.scale.setScalar(2.2);
  top.rotation.x = -Math.PI / 2;
  top.position.y = y + 0.4;
  const plate = mesh(new THREE.CircleGeometry(1.3, 9), mat(gang.color, { side: THREE.DoubleSide }), { cast: false });
  plate.rotation.x = -Math.PI / 2;
  plate.position.y = y + 0.35;
  group.add(plate, top);
  return tag(group, `marker_${gang.id}`, { category: 'gang', heightCm: y + 0.5 });
}
