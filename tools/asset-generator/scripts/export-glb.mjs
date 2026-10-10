// Exports every catalog asset to assets/models/<id>.glb at the repo root
// (res://assets/models/ in Godot, also usable in Blender or Unity).
// Animated creatures get their procedural motion baked into a looping glTF
// animation ("walk", "hover" for the bee, "swarm" for the dump, "burn" for fires) for an AnimationPlayer.
// Run: npm run export:glb
import { mkdir, writeFile } from 'node:fs/promises';
import { deflateSync, crc32 } from 'node:zlib';
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { CATALOG, SURFACES, surfaceTextureData, pixelTextureData } from '../src/assets/index.js';

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
const CLIP_NAMES = { bee: 'hover', habitat_nuee: 'swarm', gang_nuee_1: 'swarm', gang_nuee_2: 'swarm', gang_nuee_3: 'swarm', fire_can: 'burn', trash_fire: 'burn' };

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

// Minimal PNG encoder for the RGBA surface textures.
function encodePNG({ data, size }) {
  const chunk = (type, body) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(body.length);
    const typed = Buffer.concat([Buffer.from(type, 'ascii'), body]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(typed) >>> 0);
    return Buffer.concat([len, typed, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr.set([8, 6, 0, 0, 0], 8); // 8-bit RGBA
  const rows = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    rows[y * (size * 4 + 1)] = 0;
    Buffer.from(data.buffer, data.byteOffset + y * size * 4, size * 4).copy(rows, y * (size * 4 + 1) + 1);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(rows)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}
const PNGS = Object.fromEntries(SURFACES.map((name) => [name, encodePNG(surfaceTextureData(name))]));
// Texture key of a material: its surface prefix, or the whole name for pixel-art creatures.
const textureKey = (name = '') => (name.startsWith('pix_') ? name : name.split('_')[0]);
function pngFor(key) {
  if (!PNGS[key] && key.startsWith('pix_')) PNGS[key] = encodePNG(pixelTextureData(key));
  return PNGS[key];
}

// GLTFExporter cannot encode images in Node, so the surface textures are
// spliced into the .glb afterwards. Each material's name starts with its
// surface (see grit.js), which picks the texture.
function addSurfaceTextures(glb) {
  const buf = Buffer.from(glb);
  const jsonLen = buf.readUInt32LE(12);
  const json = JSON.parse(buf.subarray(20, 20 + jsonLen).toString('utf8').trimEnd());
  const binStart = 20 + jsonLen;
  const binLen = buf.readUInt32LE(binStart);
  let bin = buf.subarray(binStart + 8, binStart + 8 + binLen);
  const used = [...new Set((json.materials ?? []).map((m) => textureKey(m.name)).filter((n) => pngFor(n)))];
  if (!used.length) return buf;
  json.images = [];
  json.textures = [];
  // Smooth sampling for surfaces, nearest for the pixel-art creatures.
  json.samplers = [{ magFilter: 9729, minFilter: 9987, wrapS: 10497, wrapT: 10497 }, { magFilter: 9728, minFilter: 9728, wrapS: 10497, wrapT: 10497 }];
  const textureOf = {};
  for (const name of used) {
    const png = PNGS[name];
    const offset = bin.length;
    bin = Buffer.concat([bin, png, Buffer.alloc((4 - (png.length % 4)) % 4)]);
    json.bufferViews.push({ buffer: 0, byteOffset: offset, byteLength: png.length });
    json.images.push({ bufferView: json.bufferViews.length - 1, mimeType: 'image/png', name });
    json.textures.push({ sampler: name.startsWith('pix_') ? 1 : 0, source: json.images.length - 1 });
    textureOf[name] = json.textures.length - 1;
  }
  json.buffers[0].byteLength = bin.length;
  for (const m of json.materials) {
    const t = textureOf[textureKey(m.name)];
    if (t === undefined) continue;
    m.pbrMetallicRoughness ??= {};
    m.pbrMetallicRoughness.baseColorTexture = { index: t };
  }
  let jsonBuf = Buffer.from(JSON.stringify(json), 'utf8');
  jsonBuf = Buffer.concat([jsonBuf, Buffer.alloc((4 - (jsonBuf.length % 4)) % 4, 0x20)]);
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jsonBuf.length + 8 + bin.length, 8);
  const chunkHead = (len, type) => {
    const h = Buffer.alloc(8);
    h.writeUInt32LE(len, 0);
    h.writeUInt32LE(type, 4);
    return h;
  };
  return Buffer.concat([header, chunkHead(jsonBuf.length, 0x4e4f534a), jsonBuf, chunkHead(bin.length, 0x004e4942), bin]);
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
  const glb = addSurfaceTextures(await exporter.parseAsync(object, { binary: true, animations }));
  await writeFile(new URL(`${entry.id}.glb`, outDir), glb);
  console.log(`${entry.id}.glb  ${(glb.byteLength / 1024).toFixed(1)} KB${animations.length ? `  (${animations[0].name}, ${animations[0].tracks.length} tracks)` : ''}`);
}
