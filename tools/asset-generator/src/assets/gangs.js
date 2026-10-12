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

// Skull tattoo flat in the XY plane, facing +Z, about 1 unit tall: eye
// sockets, nose and teeth are holes so the skin shows through, crossbones behind.
export function createSkull(color, { bones = true } = {}) {
  const m = mat(color, { side: THREE.DoubleSide, roughness: 0.6 });
  const g = new THREE.Group();
  const s = new THREE.Shape();
  s.moveTo(0.26, -0.2);
  s.absarc(0, 0.08, 0.38, -0.82, Math.PI + 0.82, false);
  s.lineTo(-0.2, -0.46);
  s.lineTo(0.2, -0.46);
  s.lineTo(0.26, -0.2);
  for (const x of [-0.15, 0.15]) {
    const eye = new THREE.Path();
    eye.absellipse(x, 0.02, 0.1, 0.11, 0, Math.PI * 2, true);
    s.holes.push(eye);
  }
  const nose = new THREE.Path();
  nose.moveTo(0, -0.08);
  nose.lineTo(0.05, -0.2);
  nose.lineTo(-0.05, -0.2);
  nose.lineTo(0, -0.08);
  s.holes.push(nose);
  for (const x of [-0.1, 0, 0.1]) {
    const tooth = new THREE.Path();
    tooth.moveTo(x - 0.015, -0.3);
    tooth.lineTo(x - 0.015, -0.44);
    tooth.lineTo(x + 0.015, -0.44);
    tooth.lineTo(x + 0.015, -0.3);
    tooth.lineTo(x - 0.015, -0.3);
    s.holes.push(tooth);
  }
  g.add(mesh(new THREE.ShapeGeometry(s, 10), m, { cast: false }));
  if (bones) {
    for (const side of [1, -1]) {
      const bar = flatBar(-0.48 * side, -0.62, 0.48 * side, -0.02, 0.08, m);
      bar.position.z = -0.01;
      g.add(bar);
      for (const [x, y] of [[-0.48 * side, -0.62], [0.48 * side, -0.02]]) {
        for (const k of [-1, 1]) {
          const knob = mesh(new THREE.CircleGeometry(0.06, 8), m, { cast: false });
          knob.position.set(x + k * 0.05 * side, y + k * -0.03, -0.01);
          g.add(knob);
        }
      }
    }
  }
  return g;
}

// Back tattoo for a gang: a skull over (or above) the gang emblem.
// Skull ink per gang; the emblem under it is inked in the gang colour.
const TATTOO_INK = { tisseuses: 0xf4f1ea, prieurs: 0x141414, nuee: 0xe6ecf5, colonie: 0xf08a1c };
function createGangTattoo(gang) {
  const ink = TATTOO_INK[gang.id] ?? gang.ink;
  const g = new THREE.Group();
  const skull = createSkull(ink, { bones: gang.emblem !== 'web' });
  if (gang.emblem === 'chevrons') {
    // Skull and crossbones with the rank chevrons under it.
    skull.scale.setScalar(0.62);
    skull.position.y = 0.22;
    const chevrons = createEmblem(gang.id, ink);
    chevrons.scale.setScalar(0.55);
    chevrons.position.set(0, -0.5, -0.005);
    g.add(skull, chevrons);
  } else {
    // Skull in front of the emblem.
    const emblem = createEmblem(gang.id, gang.color);
    emblem.scale.setScalar(gang.emblem === 'web' ? 1.25 : 1.05);
    emblem.position.z = 0.02;
    skull.scale.setScalar(gang.emblem === 'web' ? 0.75 : 0.58);
    skull.position.set(0, gang.emblem === 'claw' ? -0.05 : 0, 0.05);
    g.add(emblem, skull);
  }
  return g;
}

// Satin durag over the top of the head, with a seam, a tied band and two tails
// plus a short flap hanging behind. `radii` is the head size, centred on its top.
export function createDurag(color, radii) {
  const [rx, ry, rz] = radii;
  const satin = mat(color, { roughness: 0.32, metalness: 0.05, side: THREE.DoubleSide });
  const g = new THREE.Group();
  const capG = new THREE.SphereGeometry(1, 16, 8, 0, Math.PI * 2, 0, Math.PI * 0.55);
  capG.scale(rx * 1.08, ry * 1.25, rz * 1.08);
  g.add(mesh(capG, satin));
  const seamG = new THREE.TorusGeometry(1, 0.035, 4, 16, Math.PI);
  seamG.rotateY(Math.PI / 2);
  seamG.scale(rx, ry * 1.27, rz * 1.1);
  g.add(mesh(seamG, satin, { cast: false }));
  const bandG = new THREE.TorusGeometry(1, 0.06, 4, 24);
  bandG.rotateX(Math.PI / 2);
  bandG.scale(rx * 1.1, ry, rz * 1.1);
  const band = mesh(bandG, satin, { cast: false });
  band.position.y = -ry * 0.15;
  g.add(band);
  for (const side of [1, -1]) {
    const len = Math.max(rx, rz) * 1.9;
    const tailG = new THREE.BoxGeometry(rx * 0.26, rx * 0.03, len);
    tailG.translate(0, 0, -len / 2);
    const tail = mesh(tailG, satin, { cast: false });
    tail.position.set(side * rx * 0.12, -ry * 0.1, -rz * 1.02);
    tail.rotation.set(-0.95, side * 0.18, 0);
    g.add(tail);
  }
  const flapG = new THREE.BoxGeometry(rx * 1.3, ry * 1.5, rx * 0.03);
  flapG.translate(0, -ry * 0.75, 0);
  const flap = mesh(flapG, satin, { cast: false });
  flap.position.set(0, ry * 0.2, -rz * 1.04);
  flap.rotation.x = 0.25;
  g.add(flap);
  return g;
}

const GOLD = 0xd9a92b;
// Colour gangs wear their colour; the Tisseuses wear black, the Colonie army khaki.
const DURAG = { tisseuses: 0x141414, colonie: 0x5f6238 };

// Gold chain around the neck (ring in the XY plane, like the bandana) with a
// skull pendant hanging in front.
export function createChain(radius) {
  const gold = mat(GOLD, { metalness: 0.9, roughness: 0.28 });
  const g = new THREE.Group();
  const ring = radius * 1.3;
  const links = 32;
  for (let i = 0; i < links; i++) {
    const a = (i / links) * Math.PI * 2;
    const link = mesh(new THREE.TorusGeometry(radius * 0.085, radius * 0.04, 4, 8), gold, { cast: false });
    link.position.set(Math.cos(a) * ring, Math.sin(a) * ring, 0);
    link.rotation.z = a + Math.PI / 2;
    if (i % 2) link.rotation.x = Math.PI / 2;
    g.add(link);
  }
  const pendant = createSkull(GOLD, { bones: false });
  pendant.traverse((o) => {
    if (o.isMesh) o.material = mat(GOLD, { metalness: 0.9, roughness: 0.28, side: THREE.DoubleSide });
  });
  pendant.scale.setScalar(radius * 0.75);
  pendant.position.set(0, -ring - radius * 0.3, radius * 0.25);
  g.add(pendant);
  return g;
}

function place(object, anchor, part) {
  const holder = new THREE.Group();
  holder.position.set(...anchor.position);
  holder.rotation.x = anchor.tilt ?? 0;
  holder.add(part);
  anchorParent(object, anchor).add(holder);
  return holder;
}

// Dress a creature as a gang member. Everyone gets a skull tattoo on the back
// (with the gang emblem), a gold chain and a durag. Colour gangs (Bloods/Crips
// style) wear a durag and a bandana in their colour; tattoo gangs wear a black
// or khaki durag and let the ink speak. Works on any creature that exposes
// `userData.anchors` (fly, mantis, ant, spider).
export function applyGang(object, gangId) {
  const gang = gangOf(gangId);
  const anchors = object.userData.anchors;
  if (!anchors) throw new Error(`${object.name} has no gang anchors`);
  const { radius } = anchors.neck;
  if (gang.style === 'colors') {
    const cloth = mat(gang.color, { roughness: 0.9, side: THREE.DoubleSide });
    const band = new THREE.Group();
    const ring = mesh(new THREE.TorusGeometry(radius * 1.1, radius * 0.38, 4, 12), cloth);
    ring.scale.set(1, 1, 1.4);
    band.add(ring);
    // The knotted triangle hanging under the chin.
    const flap = mesh(new THREE.ConeGeometry(radius * 1.1, radius * 1.8, 3), cloth);
    flap.rotation.z = Math.PI;
    flap.scale.set(1, 1, 0.35);
    flap.position.set(0, -radius * 1.8, radius * 0.3);
    band.add(flap);
    place(object, anchors.neck, band).name = 'gang_bandana';
  }
  const chain = createChain(radius);
  chain.position.z = gang.style === 'colors' ? -radius * 0.55 : 0;
  place(object, anchors.neck, chain).name = 'gang_chain';
  if (anchors.head) {
    const durag = createDurag(DURAG[gang.id] ?? gang.color, anchors.head.radii);
    place(object, anchors.head, durag).name = 'gang_durag';
  }
  const { position, size, tilt = 0 } = anchors.back;
  const tattoo = createGangTattoo(gang);
  tattoo.scale.setScalar(size * 2.2);
  tattoo.rotation.x = -Math.PI / 2 + tilt;
  tattoo.position.set(...position);
  tattoo.name = 'gang_tattoo';
  anchorParent(object, anchors.back).add(tattoo);
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
  banner.userData.keepGeometry = true;
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
