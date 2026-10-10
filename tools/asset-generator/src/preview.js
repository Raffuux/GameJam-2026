// Asset showcase: a small backyard diorama at spider scale.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { CATALOG, updateAssets } from './assets/index.js';

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
document.getElementById('app').appendChild(renderer.domElement);

const scene = new THREE.Scene();
// Soft image-based light so metal (can, coin, paperclip) catches reflections.
scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.35;
const sky = new THREE.Color(0x9fc7e0);
scene.background = sky;
scene.fog = new THREE.Fog(sky, 90, 240);

const camera = new THREE.PerspectiveCamera(50, 1, 0.05, 400);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI / 2 - 0.03;
controls.minDistance = 1.5;
controls.maxDistance = 120;

scene.add(new THREE.HemisphereLight(0xdff1ff, 0x5b4a2c, 1.1));
const sun = new THREE.DirectionalLight(0xfff1d6, 2.6);
sun.position.set(70, 80, 45);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
Object.assign(sun.shadow.camera, { left: -90, right: 90, top: 90, bottom: -90, near: 1, far: 300 });
sun.target.position.set(40, 0, 0);
scene.add(sun.target);
sun.shadow.bias = -0.0005;
sun.shadow.normalBias = 0.04;
scene.add(sun);

// Soil with a little noise in its height and colour.
const groundG = new THREE.PlaneGeometry(300, 300, 90, 90);
groundG.rotateX(-Math.PI / 2);
const gp = groundG.attributes.position;
const colors = [];
const soil = new THREE.Color(0x6e5a3a);
const moss = new THREE.Color(0x56763a);
const concrete = new THREE.Color(0x8f8a80);
for (let i = 0; i < gp.count; i++) {
  const x = gp.getX(i);
  const z = gp.getZ(i);
  const n = Math.sin(x * 0.21) * Math.cos(z * 0.17) + Math.sin(x * 0.05 + z * 0.08);
  // Flat, paved ground under the city block to the east.
  const urban = THREE.MathUtils.smoothstep(x, 38, 48);
  gp.setY(i, (n * 0.25 - 0.2) * (1 - urban) - 0.02 * urban);
  const c = soil.clone().lerp(moss, THREE.MathUtils.clamp(0.5 + n * 0.35, 0, 1)).lerp(concrete, urban * 0.85);
  colors.push(c.r, c.g, c.b);
}
groundG.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
groundG.computeVertexNormals();
const ground = new THREE.Mesh(groundG, new THREE.MeshStandardMaterial({ vertexColors: true, flatShading: true, roughness: 1 }));
ground.receiveShadow = true;
scene.add(ground);

// Where each asset sits in the diorama, plus background filler.
const layout = {
  grass_clump: [[-22, -18, 0], [-30, -6, 1.2], [18, -26, 2.5], [32, -10, 4], [-8, -32, 0.5], [40, 14, 3], [-40, 20, 5]],
  clover: [[-12, 6, 0], [-15, 9, 1], [-10, 11, 2]],
  dandelion: [[-24, -2, 0.3]],
  mushroom: [[-18, 22, 0], [-14, 25, 1]],
  pebble: [[12, 16, 0], [16, 20, 1], [-30, 28, 2]],
  twig: [[4, -18, 0.4]],
  fallen_leaf: [[22, 4, 0], [26, 24, 2]],
  acorn: [[-6, 14, 0.8]],
  soda_can: [[16, -10, 0]],
  soda_can_lying: [[28, -2, 0.6]],
  bottle_cap: [[6, 4, 0]],
  pencil: [[-2, -24, 1.1]],
  coin: [[2, 8, 0]],
  toy_brick: [[-6, 2, 0.3]],
  paperclip: [[10, 0, 0.5]],
  fly: [[7, 5.5, 0.6]],
  mantis: [[-20, 10, 0.4]],
  ant: [[0, -6, 1.57], [1.4, -6.2, 1.57], [2.8, -6.1, 1.57], [4.2, -5.9, 1.57]],
  ladybug: [[-4, 6, 2.2]],
  beetle: [[8, -8, -0.7]],
  bee: [[-14, -1, 0.6]],
  caterpillar: [[-10, -8, 0.9]],
  spider: [[2, 12, -0.4]],
};

// One small territory per gang, in a row behind the yard.
['tisseuses', 'prieurs', 'nuee', 'colonie'].forEach((gang, i) => {
  const cx = -45 + i * 30;
  const cz = -45;
  const species = { tisseuses: 'spider', prieurs: 'mantis', nuee: 'fly', colonie: 'ant' }[gang];
  layout[`flag_${gang}`] = [[cx, cz, 0]];
  layout[`marker_${gang}`] = [[cx + 7, cz + 3, 0.3]];
  layout[`tag_${gang}`] = [[cx - 7, cz + 3, 0.3]];
  layout[`${species}_${gang}`] = [[cx, cz + 7, 0]];
});

// A small downtown block east of the yard: one crossroads, four streets,
// a building on each corner, street furniture on the sidewalks.
const CX = 85;
Object.assign(layout, {
  road_cross: [[CX, 0, 0]],
  road_straight: [[CX - 20, 0, 0], [CX + 20, 0, 0], [CX, -20, Math.PI / 2], [CX, 20, Math.PI / 2], [CX - 40, 0, 0]],
  bank: [[CX + 22, -20, 0]],
  building_tower: [[CX - 22, -22, 0]],
  building_carton: [[CX + 16, 18, Math.PI]],
  building_box: [[CX - 20, 19, Math.PI]],
  fire_hydrant: [[CX + 8, 6.5, 0], [CX - 26, -6.5, 1]],
  street_lamp: [[CX - 14, -7, 0], [CX + 14, 7.5, Math.PI], [CX - 7.5, 14, -Math.PI / 2]],
  trash_bin: [[CX + 12, -7, 0], [CX - 18, 7, 0]],
  dumpster: [[CX + 30, 14, 0.3]],
  trash_bag: [[CX + 34, 18, 0], [CX + 27, 19, 1], [CX + 33, 10, 2]],
  crumpled_paper: [[CX + 4, 3, 0], [CX + 25, 23, 1]],
  cigarette_butt: [[CX - 4, 7.5, 0.7]],
  plastic_bottle: [[CX + 32, 30, 0.4]],
  spider_web: [[CX - 33, -24, Math.PI / 2]],
  warehouse: [[CX + 10, 52, 0]],
  puddle: [[CX - 12, 50, 0]],
  anthill: [[CX + 40, 50, 0]],
  scaffolding: [[CX + 45, -24, 0]],
});

const focus = {};
const list = document.getElementById('list');
const groups = { nature: 'Végétation', object: 'Objets du quotidien', insect: 'Insectes', city: 'Ville', zone: 'Props de zones', gang: 'Gangs et territoires' };
let lastCat = null;
CATALOG.forEach((entry, idx) => {
  const spots = layout[entry.id] ?? [[idx * 4, 0, 0]];
  spots.forEach(([x, z, rotY], i) => {
    const obj = entry.create({ seed: idx * 10 + i + 1 });
    obj.position.set(x, 0, z);
    obj.rotation.y = rotY;
    obj.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    if (entry.id === 'bee') obj.position.y = 8; // hovering between the flowers
    scene.add(obj);
    if (i === 0) focus[entry.id] = obj;
  });
  if (entry.category !== lastCat) {
    const h = document.createElement('h2');
    h.textContent = groups[entry.category];
    list.appendChild(h);
    lastCat = entry.category;
  }
  const b = document.createElement('button');
  b.id = `asset-${entry.id}`;
  const size = new THREE.Box3().setFromObject(entry.create(), true).getSize(new THREE.Vector3());
  b.innerHTML = `${entry.label}<span class="size">${Math.max(size.x, size.y, size.z).toFixed(1)} cm</span>`;
  b.addEventListener('click', () => frame(entry.id, b));
  list.appendChild(b);
});

// Smoothly move the camera to an asset.
let tween = null;
function frame(id, button) {
  document.querySelectorAll('#panel button').forEach((el) => el.classList.toggle('active', el === button));
  const obj = focus[id];
  const box = new THREE.Box3().setFromObject(obj, true);
  const center = box.getCenter(new THREE.Vector3());
  const radius = Math.max(box.getSize(new THREE.Vector3()).length() * 0.5, 0.6);
  // Look at the asset's front (+Z), a little from the side and above.
  const dir = new THREE.Vector3(0.45, 0.5, 1).normalize().applyAxisAngle(new THREE.Vector3(0, 1, 0), obj.rotation.y);
  tween = {
    fromPos: camera.position.clone(), fromTarget: controls.target.clone(),
    toPos: center.clone().add(dir.multiplyScalar(radius * 2.8)), toTarget: center, t: 0,
  };
}

camera.position.set(-6, 9, 46);
controls.target.set(0, 2, 0);

function resize() {
  const w = innerWidth;
  const h = innerHeight;
  renderer.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

const clock = new THREE.Clock();
const ants = scene.children.filter((o) => o.userData.assetId === 'ant');
renderer.setAnimationLoop(() => {
  const rawDt = clock.getDelta();
  const dt = Math.min(rawDt, 0.05);
  const t = clock.elapsedTime;
  updateAssets(scene, t, 1);
  // The ant column marches along x and loops.
  for (const ant of ants) {
    ant.position.x += dt * 1.8;
    if (ant.position.x > 12) ant.position.x -= 14;
  }
  if (tween) {
    tween.t = Math.min(1, tween.t + rawDt * 1.6);
    const k = tween.t * tween.t * (3 - 2 * tween.t);
    camera.position.lerpVectors(tween.fromPos, tween.toPos, k);
    controls.target.lerpVectors(tween.fromTarget, tween.toTarget, k);
    if (tween.t === 1) tween = null;
  }
  controls.update();
  renderer.render(scene, camera);
});
window.__preview = { scene, camera, controls, frame };
