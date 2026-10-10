// Exports every catalog asset to assets/models/<id>.glb at the repo root
// (res://assets/models/ in Godot, also usable in Blender or Unity).
// Animated creatures get their procedural motion baked into a looping glTF
// animation ("walk", "hover" for the bee, "swarm" for the dump) for an AnimationPlayer.
// Run: npm run export:glb
import { mkdir, writeFile } from 'node:fs/promises';
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { CATALOG } from '../src/assets/index.js';

// GLTFExporter reads blobs through FileReader, which Node does not ship.
globalThis.FileReader ??= class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((buffer) => {
      this.result = buffer;
      this.onloadend?.();
    });
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then((buffer) => {
      this.result = `data:${blob.type};base64,${Buffer.from(buffer).toString('base64')}`;
      this.onloadend?.();
    });
  }
};

// 4π/3 s is a whole number of walk steps (9 rad/s) and wing beats (60 rad/s).
const LOOP_SECONDS = (4 * Math.PI) / 3;
const FPS = 30;
const CLIP_NAMES = { bee: 'hover', habitat_nuee: 'swarm', gang_nuee_1: 'swarm', gang_nuee_2: 'swarm', gang_nuee_3: 'swarm' };

function collectUpdaters(root) {
  const updaters = [];
  root.traverse((o) => {
    if (typeof o.userData.update === 'function') updaters.push(o.userData.update);
  });
  return updaters;
}

// Sample the procedural animation into keyframe tracks for every node that moves.
function bakeAnimation(root, updaters, name) {
  const nodes = [];
  root.traverse((o) => nodes.push(o));
  const frames = Math.round(LOOP_SECONDS * FPS);
  const times = [];
  const samples = nodes.map(() => ({ p: [], q: [] }));
  for (let f = 0; f <= frames; f++) {
    const t = (f / frames) * LOOP_SECONDS;
    times.push(t);
    for (const update of updaters) update(t, 1);
    nodes.forEach((o, i) => {
      samples[i].p.push(...o.position.toArray());
      samples[i].q.push(...o.quaternion.toArray());
    });
  }
  const varies = (arr, stride) => arr.some((v, k) => Math.abs(v - arr[k % stride]) > 1e-4);
  const tracks = [];
  nodes.forEach((o, i) => {
    if (o === root) return;
    if (varies(samples[i].p, 3)) tracks.push(new THREE.VectorKeyframeTrack(`${o.name}.position`, times, samples[i].p));
    if (varies(samples[i].q, 4)) tracks.push(new THREE.QuaternionKeyframeTrack(`${o.name}.quaternion`, times, samples[i].q));
  });
  for (const update of updaters) update(0, 1);
  return tracks.length ? new THREE.AnimationClip(name, LOOP_SECONDS, tracks) : null;
}

const outDir = new URL('../../../assets/models/', import.meta.url);
await mkdir(outDir, { recursive: true });
const exporter = new GLTFExporter();

// The map loads gang buildings as gang_<gang>_<n>.glb: seeded variants of each habitat.
const variants = [];
for (const gang of ['tisseuses', 'prieurs', 'nuee', 'colonie']) {
  const habitat = CATALOG.find((e) => e.id === `habitat_${gang}`);
  for (let n = 1; n <= 3; n++) {
    variants.push({ ...habitat, id: `gang_${gang}_${n}`, create: () => habitat.create({ seed: 100 * n + gang.length }) });
  }
}

for (const entry of [...CATALOG, ...variants]) {
  const object = entry.create();
  // Unique, readable node names so animation tracks (and Godot) can find them.
  let n = 0;
  object.traverse((o) => {
    if (o !== object) o.name = `${o.name || o.type.toLowerCase()}_${n++}`;
  });
  const updaters = collectUpdaters(object);
  const animations = [];
  // Flags wave by deforming their mesh, which glTF node animation cannot carry.
  if (updaters.length && !entry.id.startsWith('flag_')) {
    const clip = bakeAnimation(object, updaters, CLIP_NAMES[entry.id] ?? 'walk');
    if (clip) animations.push(clip);
  }
  object.traverse((o) => delete o.userData.update);
  const glb = await exporter.parseAsync(object, { binary: true, animations });
  await writeFile(new URL(`${entry.id}.glb`, outDir), Buffer.from(glb));
  console.log(`${entry.id}.glb  ${(glb.byteLength / 1024).toFixed(1)} KB${animations.length ? `  (${animations[0].name}, ${animations[0].tracks.length} tracks)` : ''}`);
}
