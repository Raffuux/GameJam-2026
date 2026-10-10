/* Bestiaire — créatures low-poly procédurales pour Spider Jam.
   Avant = +Z, haut = +Y. Requiert THREE (r128+) en global.
   Chaque fabrique renvoie un THREE.Group ; root.userData.rig.update(t, {walk, fly, special}) anime le modèle.
   Les pivots (Leg_R1, Wing_L, Antenna_R...) sont nommés pour pouvoir les ré-animer dans le moteur. */
(function (global) {
  'use strict';
  const D = Math.PI / 180;

  // ---------- primitives ----------
  function mat(color, o) {
    return new THREE.MeshStandardMaterial(Object.assign({ color, roughness: 0.65, metalness: 0, flatShading: true }, o || {}));
  }
  function shade(m) { m.castShadow = true; m.receiveShadow = true; return m; }
  function blob(rx, ry, rz, material, w, h) {
    const m = shade(new THREE.Mesh(new THREE.SphereGeometry(1, w || 10, h || 7), material));
    m.scale.set(rx, ry, rz);
    return m;
  }
  function gem(r, material, detail) {
    return shade(new THREE.Mesh(new THREE.IcosahedronGeometry(r, detail == null ? 1 : detail), material));
  }
  function cone(r, h, material, seg) { // pointe vers +Y
    return shade(new THREE.Mesh(new THREE.ConeGeometry(r, h, seg || 5), material));
  }
  function at(o, x, y, z) { o.position.set(x, y, z); return o; }
  function rot(o, x, y, z) { o.rotation.set(x || 0, y || 0, z || 0); return o; }
  function rod(len, r0, r1, material, seg) { // de l'origine vers +X
    const g = new THREE.CylinderGeometry(r1, r0, len, seg || 6, 1);
    g.rotateZ(-Math.PI / 2);
    g.translate(len / 2, 0, 0);
    return shade(new THREE.Mesh(g, material));
  }
  function link(a, b, r0, r1, material, seg) {
    const A = new THREE.Vector3().fromArray(a), B = new THREE.Vector3().fromArray(b);
    const d = B.clone().sub(A);
    const m = rod(d.length(), r0, r1, material, seg);
    m.position.copy(A);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(1, 0, 0), d.normalize());
    return m;
  }
  function rng(seed) { return function () { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }

  // ---------- membres articulés ----------
  // Chaîne dans le plan XY local, qui part vers +X ; chaque articulation plie autour de Z.
  function chain(name, lengths, angles, radii, mats) {
    const root = new THREE.Group(); root.name = name;
    const joints = [];
    let parent = root;
    lengths.forEach((len, i) => {
      const j = new THREE.Group();
      j.name = name + '_' + i;
      j.rotation.z = angles[i];
      if (i > 0) j.position.x = lengths[i - 1];
      const m = Array.isArray(mats) ? mats[i % mats.length] : mats;
      const r0 = radii[i], r1 = radii[i + 1] != null ? radii[i + 1] : r0 * 0.6;
      j.add(rod(len, r0, r1, m));
      if (i > 0) j.add(gem(r0 * 1.15, m, 0));
      parent.add(j); joints.push(j); parent = j;
    });
    root.userData.joints = joints;
    root.userData.base = angles.slice();
    return root;
  }
  // yaw : 0 = vers l'extérieur, + = vers l'avant
  function setYaw(o, a) { o.rotation.y = o.userData.side > 0 ? -a : Math.PI + a; }

  function addLimb(list, parent, o) {
    const limb = chain(o.name, o.lengths, o.angles, o.radii, o.mats);
    limb.position.set(o.pos[0] * o.side, o.pos[1], o.pos[2]);
    Object.assign(limb.userData, { side: o.side, yaw: o.yaw * D, phase: o.phase || 0 });
    setYaw(limb, limb.userData.yaw);
    parent.add(limb); list.push(limb);
    return limb;
  }
  function legPairs(rig, parent, list, common) {
    list.forEach((L, k) => [1, -1].forEach(side => addLimb(rig.legs, parent, Object.assign({}, common, L, {
      side, name: 'Leg_' + (side > 0 ? 'R' : 'L') + (k + 1),
      phase: ((k + (side > 0 ? 0 : 1)) % 2) * Math.PI
    }))));
  }
  function antennaPair(rig, parent, o) {
    [1, -1].forEach(side => addLimb(rig.antennae, parent, Object.assign({}, o, { side, name: (o.name || 'Antenna') + '_' + (side > 0 ? 'R' : 'L') })));
  }

  function wingGeo(len, width, rootW) {
    const s = new THREE.Shape();
    s.moveTo(0, -rootW / 2);
    s.bezierCurveTo(len * 0.35, -width * 0.6, len * 0.9, -width * 0.55, len, -width * 0.05);
    s.bezierCurveTo(len * 1.02, width * 0.35, len * 0.5, width * 0.55, 0, rootW / 2);
    s.lineTo(0, -rootW / 2);
    const g = new THREE.ShapeGeometry(s, 10);
    g.rotateX(-Math.PI / 2);
    return g;
  }
  function addWings(rig, parent, o) {
    [1, -1].forEach(side => {
      const pivot = new THREE.Group();
      pivot.name = o.name + '_' + (side > 0 ? 'R' : 'L');
      pivot.position.set(o.pos[0] * side, o.pos[1], o.pos[2]);
      const flap = new THREE.Group(); flap.name = pivot.name + '_flap'; pivot.add(flap);
      flap.add(new THREE.Mesh(wingGeo(o.len, o.width, o.root || o.width * 0.25), o.mat));
      Object.assign(pivot.userData, {
        side, flap, rest: o.rest * D, open: o.open * D, tilt: (o.tilt || 0) * D,
        amp: (o.amp || 55) * D, freq: o.freq || 40, phase: o.phase || 0
      });
      setYaw(pivot, pivot.userData.rest);
      parent.add(pivot); rig.wings.push(pivot);
    });
  }

  // ---------- animation ----------
  function makeRig(name) {
    const root = new THREE.Group(); root.name = name;
    const body = new THREE.Group(); body.name = name + '_Body'; root.add(body);
    const rig = { root, body, legs: [], wings: [], antennae: [] };
    root.userData.rig = rig;
    return rig;
  }
  function walkLegs(rig, t, walk, speed, amp, lift) {
    rig.legs.forEach(leg => {
      const u = leg.userData, j = u.joints, p = t * speed + u.phase;
      setYaw(leg, u.yaw + Math.sin(p) * amp * walk);
      const up = Math.max(0, Math.cos(p)) * lift * walk;
      j.forEach((jt, i) => { jt.rotation.z = u.base[i]; });
      j[0].rotation.z += up;
      if (j[1]) j[1].rotation.z -= up * 0.5;
    });
  }
  function finish(rig, o) {
    rig.update = function (t, w) {
      w = Object.assign({ walk: 0, fly: 0, special: 0 }, w);
      walkLegs(rig, t, w.walk, o.speed, o.amp, o.lift);
      if (w.fly) rig.legs.forEach(l => { l.userData.joints[0].rotation.z -= 0.6 * w.fly; });
      rig.wings.forEach(p => {
        const u = p.userData;
        setYaw(p, u.rest + (u.open - u.rest) * w.fly);
        u.flap.rotation.z = u.tilt * (1 - w.fly) + Math.sin(t * u.freq + u.phase) * u.amp * w.fly;
      });
      rig.antennae.forEach((a, i) => {
        const j = a.userData.joints;
        j[0].rotation.z = a.userData.base[0] + Math.sin(t * 2.1 + i * 1.7) * 0.1 + Math.sin(t * 7.3 + i) * 0.03;
      });
      rig.body.position.y = w.fly * ((o.hover || 1.2) + Math.sin(t * 2.4) * 0.08)
        + Math.abs(Math.sin(t * o.speed)) * 0.02 * w.walk + Math.sin(t * 1.6) * 0.004;
      rig.body.rotation.x = -0.1 * w.fly;
      if (o.extra) o.extra(t, w);
    };
    rig.update(0, {});
    return rig.root;
  }
  // poils raides sur une ellipsoïde (cx,cy,cz,rx,ry,rz)
  function bristles(parent, n, e, material, seed, len) {
    const r = rng(seed);
    for (let i = 0; i < n; i++) {
      const x = (r() - 0.5) * 1.6, z = (r() - 0.5) * 1.6;
      const yy = 1 - x * x - z * z;
      if (yy < 0.15) continue;
      const c = cone(0.012, len || 0.12, material, 3);
      c.position.set(e[0] + x * e[3], e[1] + Math.sqrt(yy) * e[4] * 0.97, e[2] + z * e[5]);
      c.rotation.set(-0.6 + r() * 0.3, 0, x * 0.8);
      parent.add(c);
    }
  }

  // ---------- créatures ----------
  function spider() {
    const rig = makeRig('Epeire'), b = rig.body;
    const brown = mat(0x8a5a2b, { roughness: 0.75 }), brownD = mat(0x4a2c12, { roughness: 0.8 });
    const tan = mat(0xd6a86a, { roughness: 0.7 }), cream = mat(0xf6ecd0, { roughness: 0.6 });
    const eyeM = mat(0x0c0c10, { roughness: 0.08, metalness: 0.4 }), shine = mat(0xffffff, { emissive: 0xffffff, emissiveIntensity: 0.6 });
    const silk = mat(0xf5f5ff, { transparent: true, opacity: 0.7, roughness: 0.2 });

    const abd = at(blob(0.5, 0.44, 0.58, brown, 12, 9), 0, 0.68, -0.6); abd.rotation.x = 0.3; abd.name = 'Abdomen';
    b.add(abd);
    // croix de l'épeire + folium (enfants de l'abdomen, coordonnées sur sphère unité)
    const dot = (dir, m, s) => { const v = new THREE.Vector3().fromArray(dir).normalize().multiplyScalar(0.96); const d = blob(s, s, s, m, 6, 4); d.position.copy(v); abd.add(d); };
    [-0.55, -0.25, 0.05, 0.35, 0.6].forEach(a => dot([0, Math.cos(a), Math.sin(a)], cream, 0.1));
    [-0.4, 0.4].forEach(a => dot([Math.sin(a), Math.cos(a), 0.12], cream, 0.09));
    [-1, 1].forEach(s => { [0.5, 0.0, -0.5].forEach(z => dot([s * 0.75, 0.55, z], brownD, 0.16)); dot([s * 0.6, 0.75, 0.55], cream, 0.06); });
    b.add(rot(at(cone(0.06, 0.12, brownD), 0, 0.42, -1.12), -Math.PI / 2 - 0.4, 0, 0));

    b.add(at(gem(0.1, brownD, 0), 0, 0.55, -0.08));                        // pédicelle
    const ceph = at(blob(0.33, 0.22, 0.38, tan, 10, 7), 0, 0.52, 0.2); b.add(ceph);
    b.add(at(blob(0.1, 0.06, 0.28, brownD), 0, 0.71, 0.16));
    // yeux : 2 gros devant, 2 moyens, 4 latéraux
    [-1, 1].forEach(s => {
      b.add(at(gem(0.065, eyeM), s * 0.07, 0.64, 0.52));
      b.add(at(blob(0.016, 0.016, 0.016, shine, 5, 3), s * 0.075 + 0.015, 0.675, 0.575));
      b.add(at(gem(0.045, eyeM), s * 0.05, 0.71, 0.45));
      b.add(at(gem(0.035, eyeM, 0), s * 0.17, 0.62, 0.47));
      b.add(at(gem(0.03, eyeM, 0), s * 0.19, 0.64, 0.41));
      b.add(at(blob(0.075, 0.11, 0.075, brownD), s * 0.075, 0.42, 0.52));        // chélicères
      b.add(rot(at(cone(0.025, 0.08, eyeM, 4), s * 0.075, 0.3, 0.55), Math.PI, 0, 0)); // crochets
    });
    antennaPair(rig, b, { name: 'Palp', pos: [0.11, 0.46, 0.5], yaw: 70, lengths: [0.18, 0.15, 0.12], angles: [0.5, -0.9, -0.7], radii: [0.03, 0.028, 0.026, 0.03], mats: [tan, brownD] });

    const base = [0.5, 0.2, 0.5, 0.4], ang = [0.95, -0.7, -0.95, -0.5];
    const L = s => base.map(v => v * s);
    legPairs(rig, b, [
      { pos: [0.18, 0.47, 0.38], yaw: 55, lengths: L(1.15) },
      { pos: [0.25, 0.47, 0.25], yaw: 18, lengths: L(1.0) },
      { pos: [0.25, 0.47, 0.1], yaw: -22, lengths: L(0.85) },
      { pos: [0.18, 0.47, -0.02], yaw: -55, lengths: L(1.0) }
    ], { angles: ang, radii: [0.055, 0.045, 0.04, 0.03, 0.014], mats: [tan, brownD] });

    const thread = rod(8, 0.008, 0.008, silk, 4); thread.name = 'Silk';
    thread.rotation.z = Math.PI / 2; thread.position.set(0, 1.1, -0.62); thread.visible = false;
    b.add(thread);

    return finish(rig, {
      speed: 7, amp: 0.3, lift: 0.4,
      extra(t, w) {
        thread.visible = w.special > 0.05;
        thread.scale.x = Math.max(0.001, w.special);
        if (w.special) {
          rig.body.position.y += w.special * (1.6 + Math.sin(t * 1.3) * 0.25);
          rig.body.rotation.z = Math.sin(t * 0.9) * 0.15 * w.special;
          rig.legs.forEach((l, i) => {
            const j = l.userData.joints;
            j[0].rotation.z -= 0.3 * w.special;
            j[2].rotation.z -= (0.5 + Math.sin(t * 2 + i) * 0.12) * w.special;
          });
        } else rig.body.rotation.z = 0;
      }
    });
  }

  function fly() {
    const rig = makeRig('Mouche'), b = rig.body;
    const metal = mat(0x2fa36b, { metalness: 0.55, roughness: 0.3 }), metalD = mat(0x17603f, { metalness: 0.5, roughness: 0.35 });
    const black = mat(0x1a1a1c, { roughness: 0.8 }), eye = mat(0xb02a1e, { roughness: 0.35, metalness: 0.1 });
    const face = mat(0xd8d0b8, { roughness: 0.5, metalness: 0.3 });
    const wingM = mat(0xdff2ff, { transparent: true, opacity: 0.38, side: THREE.DoubleSide, roughness: 0.1, metalness: 0.3, depthWrite: false });

    b.add(at(blob(0.3, 0.28, 0.34, metal), 0, 0.56, 0.05));
    b.add(at(blob(0.29, 0.24, 0.42, metal), 0, 0.5, -0.42));
    [-0.3, -0.52].forEach(z => b.add(at(blob(0.295, 0.245, 0.05, metalD), 0, 0.5, z)));
    bristles(b, 26, [0, 0.56, 0.05, 0.3, 0.28, 0.34], black, 7, 0.13);
    bristles(b, 16, [0, 0.5, -0.42, 0.29, 0.24, 0.42], black, 11, 0.1);
    b.add(at(blob(0.24, 0.22, 0.16, black), 0, 0.6, 0.42));
    [-1, 1].forEach(s => { const e = at(gem(0.17, eye), s * 0.15, 0.64, 0.46); e.scale.set(1, 1.15, 0.85); b.add(e); });
    b.add(at(blob(0.08, 0.11, 0.05, face), 0, 0.57, 0.57));
    b.add(link([0, 0.5, 0.54], [0, 0.34, 0.62], 0.035, 0.03, black));
    b.add(at(blob(0.06, 0.03, 0.06, black), 0, 0.33, 0.63));
    antennaPair(rig, b, { pos: [0.04, 0.66, 0.58], yaw: 70, lengths: [0.06, 0.08], angles: [0.8, -1.4], radii: [0.025, 0.03, 0.005], mats: black });
    addWings(rig, b, { name: 'Wing', pos: [0.1, 0.78, 0.12], len: 0.8, width: 0.32, rest: -68, open: -12, tilt: -4, amp: 60, freq: 48, mat: wingM });
    legPairs(rig, b, [{ pos: [0.12, 0.42, 0.2], yaw: 45 }, { pos: [0.15, 0.4, 0.05], yaw: 0 }, { pos: [0.12, 0.4, -0.1], yaw: -40 }],
      { lengths: [0.22, 0.34, 0.28], angles: [0.5, -1.2, -0.8], radii: [0.03, 0.025, 0.018, 0.01], mats: black });
    return finish(rig, {
      speed: 12, amp: 0.35, lift: 0.4, hover: 1.4,
      extra(t, w) { rig.body.position.x = Math.sin(t * 1.7) * 0.25 * w.fly; rig.body.rotation.y = Math.sin(t * 1.1) * 0.4 * w.fly; }
    });
  }

  function mantis() {
    const rig = makeRig('Mante'), b = rig.body;
    const green = mat(0x7cc243, { roughness: 0.55 }), greenD = mat(0x4f8f2a), greenL = mat(0xc4e88a);
    const eyeM = mat(0xdbe86a, { roughness: 0.3 }), black = mat(0x111111, { roughness: 0.3 });
    const wingM = mat(0x9fd66a, { transparent: true, opacity: 0.8, roughness: 0.45, side: THREE.DoubleSide });

    const abd = at(blob(0.26, 0.2, 0.8, green), 0, 0.64, -0.85); abd.rotation.x = 0.12; b.add(abd);
    const belly = at(blob(0.22, 0.14, 0.72, greenD), 0, 0.57, -0.85); belly.rotation.x = 0.12; b.add(belly);
    [-1, 1].forEach(s => { const w = at(blob(0.19, 0.04, 0.72, wingM), s * 0.08, 0.82, -0.72); w.rotation.set(0.12, 0, s * 0.28); b.add(w); });
    b.add(at(blob(0.17, 0.16, 0.3, green), 0, 0.66, -0.05));
    b.add(link([0, 0.66, 0.02], [0, 1.12, 0.5], 0.1, 0.07, green, 7));
    b.add(at(gem(0.085, green), 0, 1.13, 0.51));

    const head = new THREE.Group(); head.name = 'Head'; head.position.set(0, 1.21, 0.58); b.add(head);
    head.add(blob(0.27, 0.13, 0.12, green));
    head.add(rot(at(cone(0.09, 0.2, greenL), 0, -0.15, 0.04), Math.PI, 0, 0));
    [-1, 1].forEach(s => {
      const e = at(gem(0.1, eyeM), s * 0.26, 0.04, 0.0); e.scale.set(0.9, 1.2, 1); head.add(e);
      head.add(at(blob(0.022, 0.04, 0.02, black, 6, 4), s * 0.3, 0.05, 0.085));
    });
    antennaPair(rig, head, { pos: [0.06, 0.1, 0.06], yaw: 75, lengths: [0.45, 0.45], angles: [1.0, -0.5], radii: [0.012, 0.01, 0.004], mats: greenD });

    // pattes ravisseuses
    const arms = [];
    [1, -1].forEach(side => {
      const arm = addLimb(arms, b, { name: 'Arm_' + (side > 0 ? 'R' : 'L'), side, pos: [0.08, 1.0, 0.42], yaw: 76,
        lengths: [0.32, 0.5, 0.4, 0.12], angles: [-0.9, 1.6, -2.95, 0.7], radii: [0.065, 0.065, 0.045, 0.025, 0.012], mats: green });
      const j = arm.userData.joints;
      for (let k = 1; k <= 4; k++) j[1].add(rot(at(cone(0.016, 0.09, greenL, 3), k * 0.1, -0.06, 0), Math.PI, 0, 0));
      for (let k = 1; k <= 3; k++) j[2].add(rot(at(cone(0.012, 0.07, greenL, 3), k * 0.1, -0.045, 0), Math.PI, 0, 0));
    });
    legPairs(rig, b, [{ pos: [0.12, 0.62, 0.05], yaw: 30 }, { pos: [0.13, 0.62, -0.2], yaw: -35 }],
      { lengths: [0.5, 0.7, 0.5], angles: [0.75, -1.45, -0.55], radii: [0.04, 0.035, 0.025, 0.012], mats: green });

    return finish(rig, {
      speed: 5, amp: 0.3, lift: 0.35,
      extra(t, w) {
        head.rotation.y = Math.sin(t * 0.5) * 0.5 * (1 - w.walk * 0.6);
        head.rotation.z = Math.sin(t * 0.31) * 0.15;
        const ph = (t % 2.2) / 2.2;
        let s = ph < 0.1 ? ph / 0.1 : ph < 0.3 ? 1 - (ph - 0.1) / 0.2 : 0;
        s = s * s * (3 - 2 * s) * w.special;
        arms.forEach(a => {
          const j = a.userData.joints, bs = a.userData.base;
          j[0].rotation.z = bs[0] + s * 0.6 + Math.sin(t * 1.2) * 0.04;
          j[1].rotation.z = bs[1] - s * 0.9;
          j[2].rotation.z = bs[2] + s * 2.2;
        });
      }
    });
  }

  function ant() {
    const rig = makeRig('Fourmi'), b = rig.body;
    const red = mat(0x9a3218, { roughness: 0.35, metalness: 0.15 }), dark = mat(0x3a150c, { roughness: 0.3, metalness: 0.2 });
    const eye = mat(0x0d0d0d, { roughness: 0.15 }), crumbM = mat(0xe8c98a, { roughness: 0.9 });

    const g = at(blob(0.3, 0.26, 0.4, dark), 0, 0.52, -0.6); g.rotation.x = -0.25; b.add(g);
    b.add(at(gem(0.09, red), 0, 0.44, -0.18));
    b.add(at(blob(0.06, 0.1, 0.05, red), 0, 0.52, -0.17));
    const th = at(blob(0.15, 0.15, 0.34, red), 0, 0.46, 0.16); th.rotation.x = -0.15; b.add(th);
    const head = new THREE.Group(); head.name = 'Head'; head.position.set(0, 0.56, 0.62); b.add(head);
    head.add(blob(0.25, 0.22, 0.24, red));
    [-1, 1].forEach(s => {
      head.add(at(blob(0.06, 0.08, 0.07, eye), s * 0.21, 0.05, 0.07));
      head.add(link([s * 0.09, -0.1, 0.17], [s * 0.02, -0.13, 0.36], 0.045, 0.012, dark));
    });
    antennaPair(rig, head, { pos: [0.08, 0.12, 0.18], yaw: 62, lengths: [0.35, 0.42], angles: [0.95, -1.5], radii: [0.022, 0.02, 0.03], mats: red });
    legPairs(rig, b, [{ pos: [0.1, 0.38, 0.3], yaw: 40 }, { pos: [0.11, 0.38, 0.17], yaw: 0 }, { pos: [0.1, 0.38, 0.04], yaw: -40 }],
      { lengths: [0.3, 0.48, 0.42], angles: [0.75, -1.35, -0.7], radii: [0.035, 0.03, 0.02, 0.012], mats: red });
    const crumb = at(gem(0.3, crumbM, 0), 0, 0.08, 0.6); crumb.name = 'Crumb'; crumb.scale.set(1.1, 0.8, 1); head.add(crumb);
    return finish(rig, {
      speed: 9, amp: 0.4, lift: 0.4,
      extra(t, w) {
        crumb.visible = w.special > 0.05;
        crumb.scale.setScalar(Math.max(0.001, w.special));
        head.rotation.x = -0.25 * w.special + Math.sin(t * 1.3) * 0.04;
      }
    });
  }

  function ladybug() {
    const rig = makeRig('Coccinelle'), b = rig.body;
    const red = mat(0xd8261c, { roughness: 0.22, metalness: 0.05 }), black = mat(0x151515, { roughness: 0.45 }), white = mat(0xf4f1e6);
    const wingM = mat(0x8e6a4a, { transparent: true, opacity: 0.55, side: THREE.DoubleSide, roughness: 0.3, depthWrite: false });

    b.add(at(blob(0.42, 0.18, 0.55, black), 0, 0.3, -0.05));
    const shells = [];
    [1, -1].forEach(side => {
      const pivot = new THREE.Group(); pivot.name = 'Elytron_' + (side > 0 ? 'R' : 'L');
      pivot.position.set(0, 0.32, 0.28); b.add(pivot);
      const geo = new THREE.SphereGeometry(1, 12, 8, side > 0 ? Math.PI / 2 : -Math.PI / 2, Math.PI, 0, Math.PI / 2);
      const shell = shade(new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: 0xd8261c, roughness: 0.22, flatShading: true, side: THREE.DoubleSide })));
      shell.scale.set(0.48, 0.42, 0.6); shell.position.set(0, -0.02, -0.36); pivot.add(shell);
      [[0.4, 0.25], [0.6, -0.25], [0.32, -0.62]].forEach(([x, z]) => {
        const v = new THREE.Vector3(side * x, Math.sqrt(1 - x * x - z * z), z).multiplyScalar(0.97);
        const sp = blob(0.17, 0.17, 0.17, black, 8, 5); sp.position.copy(v); shell.add(sp);
      });
      shells.push(pivot);
    });
    const front = at(blob(0.15, 0.1, 0.1, black, 8, 5), 0, 0.6, 0.18); b.add(front);
    b.add(at(blob(0.34, 0.2, 0.2, black), 0, 0.36, 0.42));
    [-1, 1].forEach(s => b.add(at(blob(0.11, 0.09, 0.09, white), s * 0.22, 0.4, 0.5)));
    b.add(at(blob(0.2, 0.14, 0.13, black), 0, 0.3, 0.6));
    [-1, 1].forEach(s => b.add(at(blob(0.05, 0.04, 0.03, white), s * 0.1, 0.33, 0.71)));
    antennaPair(rig, b, { pos: [0.08, 0.36, 0.68], yaw: 65, lengths: [0.1, 0.08], angles: [0.6, -0.6], radii: [0.015, 0.013, 0.025], mats: black });
    addWings(rig, b, { name: 'Wing', pos: [0.08, 0.6, 0.15], len: 0.85, width: 0.32, rest: -85, open: -8, amp: 50, freq: 38, mat: wingM });
    legPairs(rig, b, [{ pos: [0.18, 0.22, 0.25], yaw: 40 }, { pos: [0.22, 0.22, 0.0], yaw: 0 }, { pos: [0.2, 0.22, -0.2], yaw: -40 }],
      { lengths: [0.16, 0.22, 0.18], angles: [0.3, -1.1, -0.8], radii: [0.03, 0.025, 0.018, 0.01], mats: black });
    return finish(rig, {
      speed: 10, amp: 0.35, lift: 0.35, hover: 1.3,
      extra(t, w) {
        shells.forEach((p, i) => { const s = i === 0 ? 1 : -1; p.rotation.x = 0.7 * w.fly; p.rotation.z = s * 0.55 * w.fly; });
        front.visible = w.fly < 0.3;
        rig.wings.forEach(p => { p.scale.setScalar(Math.max(0.001, w.fly)); });
      }
    });
  }

  function bee() {
    const rig = makeRig('Abeille'), b = rig.body;
    const yellow = mat(0xf2b52a, { roughness: 0.85 }), black = mat(0x1c1612, { roughness: 0.85 }), fuzz = mat(0xc9923a, { roughness: 1 });
    const eye = mat(0x1a1410, { roughness: 0.2, metalness: 0.25 }), pollen = mat(0xf7c843, { roughness: 1 });
    const wingM = mat(0xe8f6ff, { transparent: true, opacity: 0.35, side: THREE.DoubleSide, roughness: 0.1, metalness: 0.3, depthWrite: false });

    for (let i = 0; i < 6; i++) {
      const u = i / 5, z = -0.2 - u * 0.62, rad = 0.12 + 0.17 * Math.sin(Math.PI * (0.25 + u * 0.7));
      b.add(at(blob(rad, rad * 0.92, 0.1, i % 2 ? black : yellow), 0, 0.5 - u * 0.1, z));
    }
    b.add(rot(at(cone(0.03, 0.14, black, 4), 0, 0.4, -0.88), -Math.PI / 2 - 0.2, 0, 0));
    const th = at(gem(0.25, fuzz, 1), 0, 0.58, 0.08); th.scale.set(1, 0.95, 1.1); b.add(th);
    bristles(b, 22, [0, 0.58, 0.08, 0.25, 0.24, 0.27], fuzz, 5, 0.09);
    b.add(at(blob(0.2, 0.2, 0.14, black), 0, 0.58, 0.36));
    b.add(at(blob(0.1, 0.1, 0.05, fuzz), 0, 0.52, 0.47));
    [-1, 1].forEach(s => b.add(at(blob(0.07, 0.13, 0.08, eye), s * 0.15, 0.61, 0.39)));
    antennaPair(rig, b, { pos: [0.05, 0.66, 0.46], yaw: 72, lengths: [0.16, 0.22], angles: [1.1, -1.5], radii: [0.018, 0.016, 0.02], mats: black });
    addWings(rig, b, { name: 'Wing', pos: [0.12, 0.78, 0.15], len: 0.64, width: 0.24, rest: -72, open: -5, tilt: -3, amp: 55, freq: 52, mat: wingM });
    addWings(rig, b, { name: 'HindWing', pos: [0.1, 0.76, 0.03], len: 0.42, width: 0.16, rest: -80, open: -22, tilt: -3, amp: 55, freq: 52, phase: 0.4, mat: wingM });
    legPairs(rig, b, [{ pos: [0.1, 0.42, 0.2], yaw: 45 }, { pos: [0.13, 0.42, 0.08], yaw: 0 }, { pos: [0.11, 0.42, -0.04], yaw: -45 }],
      { lengths: [0.2, 0.3, 0.26], angles: [0.35, -1.4, -0.6], radii: [0.03, 0.028, 0.02, 0.01], mats: black });
    rig.legs.filter(l => /3$/.test(l.name)).forEach(l => l.userData.joints[1].add(at(blob(0.07, 0.055, 0.055, pollen), 0.16, 0, 0)));
    return finish(rig, { speed: 10, amp: 0.35, lift: 0.4, hover: 1.5, extra(t, w) { rig.body.position.z = Math.sin(t * 0.9) * 0.2 * w.fly; } });
  }

  const list = [
    { id: 'epeire', name: 'Épeire', latin: 'Araneus diadematus', size: 15, build: spider, color: '#b07a3e', tag: 'Héroïne',
      role: "Le personnage joué. Ses toiles servent de pièges, de ponts et de raccourcis entre les brins d'herbe.",
      modes: [{ id: 'repos', label: 'Repos' }, { id: 'marche', label: 'Marche', w: { walk: 1 } }, { id: 'soie', label: 'Au bout du fil', w: { special: 1 } }] },
    { id: 'mouche', name: 'Mouche verte', latin: 'Lucilia sericata', size: 10, build: fly, color: '#2fa36b', tag: 'Proie',
      role: 'Proie de base. Vole en zigzag autour des miettes et finit collée dans les toiles.',
      modes: [{ id: 'repos', label: 'Repos' }, { id: 'marche', label: 'Marche', w: { walk: 1 } }, { id: 'vol', label: 'Vol', w: { fly: 1 } }] },
    { id: 'mante', name: 'Mante religieuse', latin: 'Mantis religiosa', size: 70, build: mantis, color: '#7cc243', tag: 'Prédatrice',
      role: 'La menace du quartier. Immobile sur une tige, elle frappe tout ce qui passe à portée de ses pattes avant.',
      modes: [{ id: 'repos', label: 'Affût' }, { id: 'marche', label: 'Marche', w: { walk: 1 } }, { id: 'frappe', label: 'Frappe', w: { special: 1 } }] },
    { id: 'fourmi', name: 'Fourmi rousse', latin: 'Formica rufa', size: 7, build: ant, color: '#9a3218', tag: 'Habitante',
      role: 'La population de la ville. Transporte des miettes, conduit les véhicules et forme des files sur les routes de terre.',
      modes: [{ id: 'repos', label: 'Repos' }, { id: 'marche', label: 'Marche', w: { walk: 1 } }, { id: 'miette', label: 'Porte une miette', w: { walk: 1, special: 1 } }] },
    { id: 'coccinelle', name: 'Coccinelle', latin: 'Coccinella septempunctata', size: 7, build: ladybug, color: '#d8261c', tag: 'Passante',
      role: "Passante tranquille. Se promène sur les feuilles et s'envole dès qu'on approche.",
      modes: [{ id: 'repos', label: 'Repos' }, { id: 'marche', label: 'Marche', w: { walk: 1 } }, { id: 'vol', label: 'Envol', w: { fly: 1 } }] },
    { id: 'abeille', name: 'Abeille', latin: 'Apis mellifera', size: 13, build: bee, color: '#f2b52a', tag: 'Livreuse',
      role: 'Livreuse aérienne. Fait la navette entre les fleurs et la ruche, et pique si on la dérange.',
      modes: [{ id: 'repos', label: 'Repos' }, { id: 'marche', label: 'Marche', w: { walk: 1 } }, { id: 'vol', label: 'Vol', w: { fly: 1 } }] }
  ];

  function countTris(obj) {
    let n = 0;
    obj.traverse(o => { if (o.isMesh) { const g = o.geometry; n += (g.index ? g.index.count : g.attributes.position.count) / 3; } });
    return Math.round(n);
  }

  global.Bestiaire = { list, countTris };
})(window);
