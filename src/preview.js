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
scene.fog = new THREE.Fog(sky, 60, 160);

const camera = new THREE.PerspectiveCamera(50, 1, 0.05, 400);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI / 2 - 0.03;
controls.minDistance = 1.5;
controls.maxDistance = 120;

scene.add(new THREE.HemisphereLight(0xdff1ff, 0x5b4a2c, 1.1));
const sun = new THREE.DirectionalLight(0xfff1d6, 2.6);
sun.position.set(30, 60, 25);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -60, right: 60, top: 60, bottom: -60, near: 1, far: 200 });
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
for (let i = 0; i < gp.count; i++) {
  const x = gp.getX(i);
  const z = gp.getZ(i);
  const n = Math.sin(x * 0.21) * Math.cos(z * 0.17) + Math.sin(x * 0.05 + z * 0.08);
  gp.setY(i, n * 0.25 - 0.2);
  const c = soil.clone().lerp(moss, THREE.MathUtils.clamp(0.5 + n * 0.35, 0, 1));
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
};

const focus = {};
const list = document.getElementById('list');
const groups = { nature: 'Végétation', object: 'Objets du quotidien', insect: 'Insectes' };
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
  const dir = camera.position.clone().sub(controls.target).normalize();
  dir.y = Math.max(dir.y, 0.25);
  dir.normalize();
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
