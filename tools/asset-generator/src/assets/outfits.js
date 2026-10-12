// Outfits for the creatures, matching the jumping spider variants of good-spider-hood:
// durag, Grove Street bandana over the face, baseball cap (forward or backwards),
// a fat joint, skull tattoos and the "girl" look (bigger eyes, curled lashes, red heels).
// Works on any creature exposing `userData.anchors` with head, mouth and back.
import * as THREE from 'three';
import { mat, mesh, blob, tube } from './common.js';
import { createDurag } from './gangs.js';

export const OUTFIT_COLORS = { green: 0x1d6a2c, purple: 0x5e2580, red: 0xa3141e, blue: 0x1f4fae, black: 0x202026 };
export const OUTFITS = [
  ...['durag', 'bandana', 'cap', 'capback'].flatMap((kind) => Object.keys(OUTFIT_COLORS).map((color) => `${kind}_${color}`)),
  'joint', 'skull', 'girl',
];

function parentOf(object, anchor) {
  return anchor.parent ? object.getObjectByName(anchor.parent) : object;
}

// Meshes of the creature itself that cloth and ink can wrap onto: no legs,
// antennae, wings or outfit parts.
function bodyMeshes(object) {
  const out = [];
  const walk = (o) => {
    if (o.userData.leg || o.name.startsWith('outfit_')) return;
    if (o.isMesh && !o.userData.antenna && !o.userData.noWrap && !o.material.transparent) out.push(o);
    o.children.forEach(walk);
  };
  walk(object);
  return out;
}

// Move every vertex of `part` (a mesh already in the scene) onto the creature's
// surface plus `offset`, along rays that `rayOf(worldVertex)` returns as
// [origin, direction]. Vertices whose ray misses stay where they are.
function wrap(object, part, rayOf, offset, maxShift = Infinity) {
  object.updateMatrixWorld(true);
  const targets = bodyMeshes(object);
  const ray = new THREE.Raycaster();
  const pos = part.geometry.attributes.position;
  const toLocal = part.matrixWorld.clone().invert();
  const v = new THREE.Vector3();
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i).applyMatrix4(part.matrixWorld);
    const [origin, dir] = rayOf(v.clone());
    ray.set(origin, dir);
    const hit = ray.intersectObjects(targets, false)[0];
    if (!hit) continue;
    const before = v.clone();
    v.copy(hit.point).addScaledVector(dir, -offset);
    if (v.distanceTo(before) > maxShift) continue;
    v.applyMatrix4(toLocal);
    pos.setXYZ(i, v.x, v.y, v.z);
  }
  pos.needsUpdate = true;
  part.geometry.computeVertexNormals();
}

// A group placed on an anchor (position and forward tilt), added to its parent.
function holder(object, anchor, name) {
  const g = new THREE.Group();
  g.name = name;
  g.position.set(...anchor.position);
  g.rotation.x = anchor.tilt ?? 0;
  parentOf(object, anchor).add(g);
  return g;
}

function durag(object, color) {
  const { head } = object.userData.anchors;
  holder(object, head, 'outfit_durag').add(createDurag(color, head.radii));
}

// Paisley bandana tied over the nose and mouth, band around the head, knot at the back.
// The mask is shrink-wrapped onto the face so it fits every head shape.
function bandana(object, color) {
  const { head } = object.userData.anchors;
  const [rx, ry, rz] = head.radii;
  const size = Math.max(rx, rz);
  const cloth = mat(color, { roughness: 0.9, side: THREE.DoubleSide });
  const g = holder(object, head, 'outfit_bandana');
  const paisley = (m) => {
    m.userData.pixKind = 'paisley';
    return m;
  };
  // Mask: front lower part of a shell around the head, wrapped onto the face from its centre.
  const centre = new THREE.Vector3(0, -ry * 0.7, 0);
  const maskG = new THREE.SphereGeometry(1, 18, 10, Math.PI / 2 - 1.3, 2.6, Math.PI * 0.5, Math.PI * 0.32);
  maskG.scale(rx * 2, ry * 2.5, rz * 2);
  maskG.translate(0, centre.y + ry * 0.5, 0);
  const mask = paisley(mesh(maskG, cloth));
  g.add(mask);
  const centreWorld = () => g.localToWorld(centre.clone());
  wrap(object, mask, (v) => {
    const c = centreWorld();
    const dir = v.clone().sub(c).normalize();
    return [c.clone().addScaledVector(dir, size * 4), dir.negate()];
  }, size * 0.06, size * 0.9);
  // The point hanging under the chin starts at the front of the mask's lower edge.
  const pos = maskG.attributes.position;
  let low = null;
  for (let i = 0; i < pos.count; i++) {
    const p = new THREE.Vector3().fromBufferAttribute(pos, i);
    if (Math.abs(p.x) < rx * 0.15 && (!low || p.y < low.y)) low = p;
  }
  const tip = new THREE.Shape();
  tip.moveTo(-rx * 0.9, 0);
  tip.lineTo(rx * 0.9, 0);
  tip.lineTo(0, -ry * 2);
  tip.lineTo(-rx * 0.9, 0);
  const tipM = paisley(mesh(new THREE.ShapeGeometry(tip), cloth));
  tipM.position.set(0, low.y + ry * 0.3, low.z);
  tipM.rotation.x = 0.3;
  g.add(tipM);
  const bandG = new THREE.TorusGeometry(1, 0.07, 4, 24);
  bandG.rotateX(Math.PI / 2);
  bandG.scale(rx * 1.2, ry, rz * 1.2);
  const band = paisley(mesh(bandG, cloth, { cast: false }));
  band.position.y = -ry * 0.55;
  g.add(band);
  wrap(object, band, (v) => {
    const c = g.localToWorld(new THREE.Vector3(0, -ry * 0.55, 0));
    const dir = v.clone().sub(c).normalize();
    return [c.clone().addScaledVector(dir, size * 4), dir.negate()];
  }, size * 0.07, size * 0.5);
  const knot = paisley(blob(rx * 0.22, rx * 0.18, rx * 0.18, cloth, 1));
  knot.position.set(0, -ry * 0.55, -rz * 1.25);
  g.add(knot);
  for (const side of [1, -1]) {
    const len = size * 0.9;
    const tail = paisley(mesh(new THREE.BoxGeometry(rx * 0.22, rx * 0.03, len).translate(0, 0, -len / 2), cloth, { cast: false }));
    tail.position.set(side * rx * 0.08, -ry * 0.6, -rz * 1.3);
    tail.rotation.set(-0.9, side * 0.35, 0);
    g.add(tail);
  }
}

// Baseball cap: dome, half-disc brim, top button and a white "S" on the front.
function cap(object, color, back = false) {
  const { head } = object.userData.anchors;
  const [rx, ry, rz] = head.radii;
  const felt = mat(color, { roughness: 0.85, side: THREE.DoubleSide });
  const g = holder(object, head, back ? 'outfit_capback' : 'outfit_cap');
  const turn = new THREE.Group();
  if (back) turn.rotation.y = Math.PI;
  g.add(turn);
  const R = [rx * 1.15, Math.max(ry * 1.6, rx * 0.75), rz * 1.15];
  const domeG = new THREE.SphereGeometry(1, 20, 8, 0, Math.PI * 2, 0, Math.PI / 2);
  domeG.scale(...R);
  turn.add(mesh(domeG, felt));
  const brimS = new THREE.Shape();
  brimS.absellipse(0, 0, R[0] * 0.95, R[2] * 0.95 + rz * 0.85, 0, Math.PI, false);
  brimS.lineTo(R[0] * 0.95, 0);
  const brimG = new THREE.ExtrudeGeometry(brimS, { depth: rx * 0.06, bevelEnabled: false, curveSegments: 16 });
  brimG.rotateX(Math.PI / 2);
  const brim = mesh(brimG, felt);
  brim.position.y = rx * 0.03;
  brim.rotation.x = back ? -0.25 : 0.12;
  turn.add(brim);
  const button = blob(rx * 0.1, rx * 0.06, rx * 0.1, felt, 1);
  button.position.y = R[1];
  turn.add(button);
  // "S" on the front panel, drawn as a tube on the dome.
  const white = mat(0xeee9dc, { roughness: 0.6 });
  const a = 0.95;
  const centre = new THREE.Vector3(0, R[1] * Math.cos(a), R[2] * Math.sin(a));
  const s = 0.22 * rx;
  const pts = [[0.8, 0.9], [0, 1.1], [-0.8, 0.6], [0, 0], [0.8, -0.6], [0, -1.1], [-0.8, -0.9]].map(([x, y]) => {
    // Tilt the letter with the dome surface.
    const v = new THREE.Vector3(x * s, y * s * Math.sin(a), -y * s * Math.cos(a) * (R[2] / R[1]));
    return v.add(centre).toArray();
  });
  const logo = tube(pts, s * 0.16, white, 24, 5);
  turn.add(logo);
}

// Fat cone joint in the corner of the mouth, glowing ember, ash, smoke and a faint light.
function joint(object) {
  const { mouth } = object.userData.anchors;
  const L = mouth.size * 1.6;
  const g = holder(object, mouth, 'outfit_joint');
  const aim = new THREE.Group();
  aim.rotation.set(0.18, 0.45, 0);
  g.add(aim);
  const paper = mat(0xe8e0cc, { roughness: 0.9 });
  const bodyG = new THREE.CylinderGeometry(L * 0.13, L * 0.06, L, 10, 1);
  bodyG.rotateX(Math.PI / 2);
  bodyG.translate(0, 0, L / 2);
  aim.add(mesh(bodyG, paper));
  const twist = blob(L * 0.035, L * 0.035, L * 0.06, paper, 1);
  twist.position.z = -L * 0.03;
  aim.add(twist);
  const ash = mesh(new THREE.CylinderGeometry(L * 0.125, L * 0.13, L * 0.08, 10).rotateX(Math.PI / 2), mat(0x7d7a74, { roughness: 1 }));
  ash.position.z = L * 1.0;
  aim.add(ash);
  const ember = mesh(new THREE.CircleGeometry(L * 0.12, 10), mat(0xff5a14, { emissive: 0xff5a14, emissiveIntensity: 3, roughness: 1 }));
  ember.position.z = L * 1.045;
  aim.add(ember);
  const smoke = mat(0xbdb8b0, { roughness: 1, transparent: true, opacity: 0.45, depthWrite: false });
  for (let i = 0; i < 4; i++) {
    const puff = blob(L * (0.1 + i * 0.05), L * (0.1 + i * 0.05), L * (0.1 + i * 0.05), smoke, 1);
    puff.position.set(L * 0.05 * Math.sin(i * 2), L * (0.25 + i * 0.28), L * (1.05 + i * 0.05));
    aim.add(puff);
  }
  const light = new THREE.PointLight(0xff7a2a, L * L * 2.5, L * 5, 2);
  light.position.z = L * 1.15;
  light.name = 'joint_light';
  aim.add(light);
}

// Pixel-art skull tattoo: a fine grid laid on the body from above, holding the
// skull-and-crossbones texture (clear background), on the back and on the head.
function tattoo(object, anchor, size, ink, name) {
  const g = holder(object, anchor, name);
  const plane = new THREE.PlaneGeometry(size, size, 20, 20);
  plane.rotateX(-Math.PI / 2);
  const m = mat(ink, { roughness: 0.7, alphaTest: 0.5, side: THREE.DoubleSide });
  const decal = mesh(plane, m, { cast: false });
  decal.userData.pixKind = 'skull';
  decal.userData.keepUV = true;
  g.add(decal);
  wrap(object, decal, (v) => {
    const up = new THREE.Vector3(0, 1, 0).transformDirection(g.matrixWorld);
    return [v.clone().addScaledVector(up, size * 2), up.negate()];
  }, size * 0.015, size * 0.5);
  return g;
}

function skull(object) {
  const { back, head } = object.userData.anchors;
  // Dark ink on the green bugs, bone-white ink on the dark or red ones.
  const ink = ['mantis', 'caterpillar'].includes(object.userData.assetId) ? 0x141414 : 0xd8d2c4;
  tattoo(object, back, back.size * 2.1, ink, 'outfit_skull');
  tattoo(object, { ...head, position: [head.position[0], head.position[1], head.position[2] - head.radii[2] * 0.15] }, Math.max(head.radii[0], head.radii[2]) * 1.5, ink, 'outfit_skull_head');
}

// Bigger eyes with curled lashes, red stilettos on every foot.
function girl(object) {
  const eyes = [];
  const feet = [];
  object.traverse((o) => {
    if (o.userData.eye) eyes.push(o);
    if (o.userData.foot) feet.push(o);
  });
  const spots = object.userData.anchors.eyes;
  if (!eyes.length && spots) {
    const glossy = mat(0x0c0c0e, { roughness: 0.15 });
    for (const p of spots.positions) {
      const eye = blob(spots.radius, spots.radius, spots.radius, glossy);
      eye.position.set(...p);
      eye.userData.eye = { radius: spots.radius, side: Math.sign(p[0]) };
      object.add(eye);
      eyes.push(eye);
    }
  }
  const black = mat(0x0c0c0e, { roughness: 0.5 });
  for (const eye of eyes) {
    const k = 1.35;
    eye.scale.multiplyScalar(k);
    const r = eye.userData.eye.radius * k;
    const side = eye.userData.eye.side;
    const p = eye.position;
    const up = new THREE.Vector3(0, 1, 0);
    for (let i = 0; i < 4; i++) {
      const f = i / 3;
      const d = new THREE.Vector3(side * (0.2 + 0.7 * f), 0.9 - 0.3 * f, 0.55 - 0.3 * f).normalize();
      const root = p.clone().addScaledVector(d, r * 0.97);
      const mid = root.clone().addScaledVector(d, r * 0.45).addScaledVector(up, r * 0.2);
      const tip = mid.clone().addScaledVector(d, r * 0.2).addScaledVector(up, r * 0.32).add(new THREE.Vector3(side * r * 0.08, 0, -r * 0.18));
      const lash = tube([root.toArray(), mid.toArray(), tip.toArray()], r * 0.055, black, 8, 4);
      lash.name = 'outfit_lash';
      eye.parent.add(lash);
    }
  }
  const red = mat(0xc4101c, { roughness: 0.25, metalness: 0.1 });
  const sole = mat(0x1a0d0d, { roughness: 0.6 });
  for (const foot of feet) {
    const r = foot.userData.foot.radius;
    const shoe = blob(r * 1.3, r * 0.95, r * 1.45, red, 1);
    shoe.position.copy(foot.position);
    shoe.position.y += r * 0.25;
    const heel = mesh(new THREE.CylinderGeometry(r * 0.22, r * 0.1, r * 1.4, 6), red);
    heel.position.copy(foot.position);
    heel.position.y -= r * 0.25;
    const inward = foot.position.clone().setY(0).normalize().multiplyScalar(-r * 0.9);
    heel.position.add(inward);
    const tipSole = blob(r * 0.9, r * 0.2, r * 1.0, sole, 1);
    tipSole.position.copy(foot.position);
    tipSole.position.y -= r * 0.7;
    tipSole.position.addScaledVector(inward, -0.6);
    for (const m of [shoe, heel, tipSole]) {
      m.name = 'outfit_heel';
      foot.parent.add(m);
    }
  }
}

// Dress `object` in outfit `name` ("durag_red", "capback_blue", "joint", ...).
export function applyOutfit(object, name) {
  const [kind, colorName] = name.split('_');
  const color = OUTFIT_COLORS[colorName];
  if (kind === 'durag') durag(object, color);
  else if (kind === 'bandana') bandana(object, color);
  else if (kind === 'cap') cap(object, color);
  else if (kind === 'capback') cap(object, color, true);
  else if (kind === 'joint') joint(object);
  else if (kind === 'skull') skull(object);
  else if (kind === 'girl') girl(object);
  else throw new Error(`Unknown outfit "${name}"`);
  object.userData.outfit = name;
  return object;
}
