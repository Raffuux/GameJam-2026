// Character design sheets: turnaround views, a detail close-up, the palette
// and design notes for every creature and gang. Open sheet.html?id=spider,
// sheet.html?gang=prieurs or sheet.html?lineup (see scripts/design-sheets.mjs).
import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { CATALOG, GANGS, applyGang, createAsset, pixelize } from './assets/index.js';
import { createSpider, createMantis, createFly, createAnt } from './assets/insects.js';

const W = 1400;
const H = 1100;
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(W, H);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.setScissorTest(true);
renderer.setClearColor(0xe8e2d4);
document.getElementById('views').appendChild(renderer.domElement);
const envMap = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;

const hex = (n) => `#${n.toString(16).padStart(6, '0')}`;

const SPECIES = {
  fly: { label: 'Mouche', latin: 'Musca domestica', notes: ['Gros yeux composés rouges, ailes translucides qui vibrent en vol.', 'Corps trapu et poilu, pattes fines : rapide, nerveuse, jamais posée longtemps.', 'Vit dans la décharge, se déplace en essaim.'] },
  mantis: { label: 'Mante religieuse', latin: 'Mantis religiosa', notes: ['Silhouette verticale, pattes ravisseuses repliées devant la tête.', 'Tête triangulaire très mobile, regard fixe : calme et menaçante.', 'Le pronotum long porte le bandana chez les Prieurs.'] },
  ant: { label: 'Fourmi', latin: 'Formica', notes: ['Trois segments bien séparés, antennes coudées.', 'Petite mais nombreuse : se lit en colonne, jamais seule.', 'Le tatouage se pose sur le gastre (l\'arrière du corps).'] },
  ladybug: { label: 'Coccinelle', latin: 'Coccinella septempunctata', notes: ['Dôme rouge à points noirs, très lisible de loin.', 'Petite tête noire à taches blanches.', 'Personnage neutre : civile, commerçante, PNJ.'] },
  beetle: { label: 'Scarabée rhinocéros', latin: 'Dynastinae', notes: ['Carapace sombre et brillante, corne frontale massive.', 'Lent et lourd : videur, gros bras, « camion » de la ville.', 'Personnage neutre pour l\'instant, aucun gang.'] },
  bee: { label: 'Abeille', latin: 'Apis mellifera', notes: ['Rayures jaunes et noires, ailes en vol stationnaire.', 'Animation « hover » : flotte sur place.', 'Personnage neutre : livreuse, messagère.'] },
  caterpillar: { label: 'Chenille', latin: 'Lepidoptera (larve)', notes: ['Segments ronds en file, ondule en avançant.', 'Grosse tête, petites pattes : comique, inoffensive.', 'Personnage neutre : passante, « bus » de la ville.'] },
  spider: { label: 'Araignée', latin: 'Araneus', notes: ['Huit pattes longues, démarche en tripode alterné.', 'Céphalothorax et abdomen bien distincts, rangée d\'yeux.', 'Personnage joueur : échelle de référence (1 m dans Godot).'] },
};

const GANG_NOTES = {
  tisseuses: { sign: "Tête de mort sur toile tatouée sur l'abdomen, durag noir, chaîne en or", notes: ["Gang des araignées. Signature : le tatouage, pas de couleur portée.", "Tête de mort blanche sur une toile violette, en plein dos : lisible vu de dessus (caméra de jeu).", "Durag noir satiné et chaîne en or avec pendentif tête de mort.", "Violet réservé aux drapeaux, tags et bornes. QG : repaire aux toiles géantes."] },
  prieurs: { sign: "Durag et bandana rouges, tête de mort et griffes tatouées, chaîne en or", notes: ["Gang des mantes. Signature : le rouge, à la Bloods.", "Durag rouge à longues queues, bandana rouge noué autour du pronotum.", "Tatouage à l'encre noire : tête de mort noire sur deux griffes croisées rouges.", "Chaîne en or avec pendentif tête de mort. QG : nid des mantes et docks."] },
  nuee: { sign: "Durag et bandana bleus, tête de mort tatouée, chaîne en or", notes: ["Gang des mouches. Signature : le bleu, à la Crips.", "Durag bleu et bandana bleu, très visibles quand l'essaim passe.", "Tatouage : tête de mort blanche et os croisés sur l'œil composé bleu.", "Chaîne en or avec pendentif tête de mort. QG : la décharge."] },
  colonie: { sign: "Tête de mort et chevrons tatoués sur le gastre, durag kaki, chaîne en or", notes: ["Gang des fourmis. Signature : le tatouage.", "Tête de mort et os croisés orange, avec trois chevrons dessous comme un galon militaire.", "Durag kaki façon armée et chaîne en or : tout le monde pareil, en colonne.", "QG : la grande fourmilière et le chantier."] },
};

const FACTORY = { spider: createSpider, mantis: createMantis, fly: createFly, ant: createAnt };

// --- Scenes -----------------------------------------------------------------

function studio(object) {
  const scene = new THREE.Scene();
  scene.environment = envMap;
  scene.environmentIntensity = 0.35;
  scene.add(new THREE.HemisphereLight(0xfff6e8, 0x5a4c3a, 1.1));
  const box = new THREE.Box3().setFromObject(object, true);
  const size = box.getSize(new THREE.Vector3());
  const span = Math.max(size.x, size.y, size.z);
  const key = new THREE.DirectionalLight(0xfff0dc, 2.4);
  key.position.set(span * 1.5, span * 2.5, span * 2);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  Object.assign(key.shadow.camera, { left: -span * 1.5, right: span * 1.5, top: span * 1.5, bottom: -span * 1.5, near: 0.01, far: span * 10 });
  key.shadow.bias = -0.0005;
  key.shadow.normalBias = 0.02;
  scene.add(key);
  const rim = new THREE.DirectionalLight(0xcfe0ff, 1.2);
  rim.position.set(-span * 2, span, -span * 2);
  scene.add(rim);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(span * 8, span * 8), new THREE.ShadowMaterial({ opacity: 0.22 }));
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = box.min.y;
  floor.receiveShadow = true;
  scene.add(floor);
  scene.add(object);
  return { scene, box, size, span };
}

function rest(object) {
  object.traverse((o) => o.userData.update?.(0, 0));
  object.updateMatrixWorld(true);
  return object;
}

// Orthographic camera looking along `dir` at the whole object.
function orthoView(stage, dir, aspect) {
  const center = stage.box.getCenter(new THREE.Vector3());
  const cam = new THREE.OrthographicCamera();
  cam.position.copy(center).addScaledVector(dir, stage.span * 4);
  if (Math.abs(dir.y) > 0.9) cam.up.set(0, 0, -1);
  cam.lookAt(center);
  cam.updateMatrixWorld();
  // Fit the projected box.
  const inv = cam.matrixWorldInverse;
  const pb = new THREE.Box3();
  const { min, max } = stage.box;
  for (const x of [min.x, max.x]) for (const y of [min.y, max.y]) for (const z of [min.z, max.z]) pb.expandByPoint(new THREE.Vector3(x, y, z).applyMatrix4(inv));
  let w = (pb.max.x - pb.min.x) * 1.18;
  let h = (pb.max.y - pb.min.y) * 1.18;
  if (w / h > aspect) h = w / aspect;
  else w = h * aspect;
  const cx = (pb.max.x + pb.min.x) / 2;
  const cy = (pb.max.y + pb.min.y) / 2;
  Object.assign(cam, { left: cx - w / 2, right: cx + w / 2, top: cy + h / 2, bottom: cy - h / 2, near: 0.01, far: stage.span * 10 });
  cam.updateProjectionMatrix();
  return cam;
}

function perspView(stage, dir, aspect, { target, distance } = {}) {
  const center = target ?? stage.box.getCenter(new THREE.Vector3());
  const cam = new THREE.PerspectiveCamera(30, aspect, 0.01, stage.span * 20);
  const r = distance ?? stage.span * 0.62 / Math.tan(THREE.MathUtils.degToRad(15)) / Math.min(1, aspect);
  cam.position.copy(center).addScaledVector(dir.clone().normalize(), r);
  cam.lookAt(center);
  return cam;
}

const FRONT = new THREE.Vector3(0, 0, 1);
const SIDE = new THREE.Vector3(1, 0, 0);
const BACK = new THREE.Vector3(0, 0, -1);
const TOP = new THREE.Vector3(0, 1, 0);
const THREE_Q = new THREE.Vector3(1, 0.55, 1.15);

// Close-up on the gang look (durag, chain, bandana), on the back tattoo, or on
// the head for plain creatures.
function detailView(stage, object, aspect, focus = 'look') {
  if (focus === 'tattoo') {
    const b = new THREE.Box3().setFromObject(object.getObjectByName('gang_tattoo'), true);
    const s = b.getSize(new THREE.Vector3());
    return perspView(stage, new THREE.Vector3(0.25, 1, -0.45), aspect, { target: b.getCenter(new THREE.Vector3()), distance: Math.max(s.x, s.y, s.z) * 3.4 });
  }
  const gear = ['gang_durag', 'gang_chain', 'gang_bandana'].map((n) => object.getObjectByName(n)).filter(Boolean);
  if (gear.length) {
    const b = new THREE.Box3();
    for (const g of gear) b.union(new THREE.Box3().setFromObject(g, true));
    const s = b.getSize(new THREE.Vector3());
    return perspView(stage, new THREE.Vector3(0.9, 0.35, 1), aspect, { target: b.getCenter(new THREE.Vector3()), distance: Math.max(s.x, s.y, s.z) * 3 });
  }
  const { box, size } = stage;
  const target = new THREE.Vector3((box.min.x + box.max.x) / 2, box.min.y + size.y * 0.6, box.max.z - size.z * 0.18);
  return perspView(stage, new THREE.Vector3(0.6, 0.3, 1), aspect, { target, distance: Math.max(size.x, size.y, size.z) * 0.75 });
}

// --- Layout -------------------------------------------------------------------

const cells = [];
function grid(cols, rows, pad = 18) {
  const cw = (W - pad * (cols + 1)) / cols;
  const ch = (H - pad * (rows + 1)) / rows;
  const out = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) out.push({ x: pad + c * (cw + pad), y: pad + r * (ch + pad), w: cw, h: ch });
  return out;
}

function addCell(rect, stage, camera, label, sub = '') {
  cells.push({ rect, stage, camera });
  const views = document.getElementById('views');
  const frame = document.createElement('div');
  frame.className = 'cell';
  Object.assign(frame.style, { left: `${rect.x}px`, top: `${rect.y}px`, width: `${rect.w}px`, height: `${rect.h}px` });
  views.appendChild(frame);
  const el = document.createElement('div');
  el.className = 'label';
  el.innerHTML = `${label}${sub ? `<small>${sub}</small>` : ''}`;
  Object.assign(el.style, { left: `${rect.x + 12}px`, top: `${rect.y + 10}px` });
  views.appendChild(el);
}

function render() {
  for (const { rect, stage, camera } of cells) {
    const y = H - rect.y - rect.h;
    renderer.setViewport(rect.x, y, rect.w, rect.h);
    renderer.setScissor(rect.x, y, rect.w, rect.h);
    renderer.render(stage.scene, camera);
  }
  document.body.dataset.ready = '1';
}

// Main colours of an object, weighted by how much geometry uses them.
function palette(object, max = 6) {
  const weight = new Map();
  object.traverse((o) => {
    if (!o.isMesh || o.material.transparent || o.material.emissive?.getHex()) return;
    const k = o.material.userData.baseColor ?? o.material.color.getHex();
    weight.set(k, (weight.get(k) ?? 0) + o.geometry.attributes.position.count);
  });
  return [...weight.entries()].sort((a, b) => b[1] - a[1]).slice(0, max).map(([k]) => k);
}

function sidebar({ kicker, title, gang, sections, colors, foot }) {
  const side = document.getElementById('side');
  side.innerHTML = `
    <p class="kicker">${kicker}</p>
    <h1>${title}</h1>
    ${gang ? `<span class="gang" style="background:${hex(gang.color)};color:${gang.color === 0xf08a1c ? '#2a241c' : '#fff'}">${gang.label}</span>` : ''}
    ${sections.map(([h, body]) => `<h2>${h}</h2>${Array.isArray(body) ? `<ul>${body.map((l) => `<li>${l}</li>`).join('')}</ul>` : `<p>${body}</p>`}`).join('')}
    ${colors ? `<h2>Palette</h2><div class="swatches">${[...new Set(colors)].map((c) => `<div class="swatch"><i style="background:${hex(c)}"></i>${hex(c)}</div>`).join('')}</div>` : ''}
    <div class="foot">${foot}</div>`;
}

const sizeText = (stage) => `${stage.size.z.toFixed(1)} cm de long · ${stage.size.y.toFixed(1)} cm de haut`;

// --- Sheets -------------------------------------------------------------------

function characterSheet(id) {
  const entry = CATALOG.find((e) => e.id === id);
  const gang = entry.gang ? GANGS[entry.gang] : null;
  const speciesId = gang ? gang.species : id;
  const sp = SPECIES[speciesId];
  const make = () => rest(createAsset(id, { seed: 3 }));
  const rects = grid(3, 2);
  const views = [
    ['Face', 'orthographique', FRONT, 'ortho'],
    ['Profil', 'orthographique', SIDE, 'ortho'],
    ['Dos', 'orthographique', BACK, 'ortho'],
    ['Trois-quarts', '', THREE_Q, 'persp'],
    gang ? ['Tatouage', 'dos', null, 'tattoo'] : ['Dessus', 'vue de jeu', TOP, 'ortho'],
    gang ? ['Look', 'durag, chaîne' + (gang.style === 'colors' ? ', bandana' : ''), null, 'detail'] : ['Détail tête', '', null, 'detail'],
  ];
  let ref;
  views.forEach(([label, sub, dir, kind], i) => {
    const object = make();
    ref ??= object;
    const stage = studio(object);
    const aspect = rects[i].w / rects[i].h;
    const cam = kind === 'ortho' ? orthoView(stage, dir, aspect) : kind === 'persp' ? perspView(stage, dir, aspect) : detailView(stage, object, aspect, kind === 'tattoo' ? 'tattoo' : 'look');
    addCell(rects[i], stage, cam, label, sub);
  });
  const stage = studio(make());
  sidebar({
    kicker: gang ? `Membre de gang · ${sp.label}` : `Personnage · ${sp.latin}`,
    title: gang ? `${sp.label} des ${gang.label.replace(/^(Les|La) /, '')}` : sp.label,
    gang,
    sections: [
      ['Taille', sizeText(stage)],
      ...(gang ? [['Signe distinctif', GANG_NOTES[gang.id].sign]] : []),
      ['Notes', gang ? GANG_NOTES[gang.id].notes : sp.notes],
      ...(gang ? [] : [['Animation', CATALOG.find((e) => e.id === id) && id === 'bee' ? 'hover (vol stationnaire)' : 'walk (boucle de marche)']]),
    ],
    colors: [...(gang ? [gang.color] : []), ...palette(ref, gang ? 5 : 6)],
    foot: `Modèle : assets/models/${id}.glb · 1 unité = 1 cm`,
  });
}

function gangSheet(gangId) {
  const gang = GANGS[gangId];
  const sp = SPECIES[gang.species];
  const memberId = `${gang.species}_${gang.id}`;
  const rects = grid(3, 3);
  const items = [
    [memberId, 'Face', '', FRONT, 'ortho'],
    [memberId, 'Trois-quarts', '', THREE_Q, 'persp'],
    [memberId, 'Dos', '', BACK, 'ortho'],
    [memberId, 'Tatouage', 'dos', null, 'tattoo'],
    [memberId, 'Look', 'durag, chaîne' + (gang.style === 'colors' ? ', bandana' : ''), null, 'detail'],
    [`habitat_${gang.id}`, 'QG', 'habitat', new THREE.Vector3(1, 0.8, 1.2), 'persp'],
    [`flag_${gang.id}`, 'Drapeau', '', new THREE.Vector3(0.5, 0.15, 1), 'persp'],
    [`tag_${gang.id}`, 'Tag', 'graffiti', FRONT, 'ortho'],
    [`marker_${gang.id}`, 'Borne', 'limite de territoire', new THREE.Vector3(0.8, 0.5, 1), 'persp'],
  ];
  let member;
  items.forEach(([id, label, sub, dir, kind], i) => {
    const object = rest(createAsset(id, { seed: 3 }));
    if (id === memberId) member ??= object;
    const stage = studio(object);
    const aspect = rects[i].w / rects[i].h;
    const cam = kind === 'ortho' ? orthoView(stage, dir, aspect) : kind === 'persp' ? perspView(stage, dir, aspect) : detailView(stage, object, aspect, kind === 'tattoo' ? 'tattoo' : 'look');
    addCell(rects[i], stage, cam, label, sub);
  });
  sidebar({
    kicker: `Gang · ${sp.label}s`,
    title: gang.label,
    gang,
    sections: [
      ['Style', gang.style === 'tattoo' ? 'Tatouage (pas de couleur portée)' : 'Couleurs (bandana)'],
      ['Signe distinctif', GANG_NOTES[gang.id].sign],
      ['Notes', GANG_NOTES[gang.id].notes],
    ],
    colors: [gang.color, gang.ink, ...palette(member, 4)],
    foot: `Modèles : ${memberId}.glb, flag_${gang.id}.glb, tag_${gang.id}.glb, marker_${gang.id}.glb, gang_${gang.id}_1..3.glb`,
  });
}

// Every gang species dressed in every gang's signs, to compare silhouettes.
function lineup() {
  const species = ['spider', 'mantis', 'fly', 'ant'];
  const gangs = [null, ...Object.values(GANGS)];
  const rects = grid(gangs.length, species.length, 14);
  species.forEach((s, r) => {
    gangs.forEach((gang, c) => {
      let object = FACTORY[s]();
      if (gang) object = applyGang(object, gang.id);
      object = rest(pixelize(object));
      const stage = studio(object);
      const rect = rects[r * gangs.length + c];
      const own = gang && gang.species === s;
      addCell(rect, stage, perspView(stage, THREE_Q, rect.w / rect.h), `${SPECIES[s].label}`, gang ? `${gang.label}${own ? ' ★' : ''}` : 'sans gang');
    });
  });
  sidebar({
    kicker: 'Planche comparative',
    title: 'Signes de gang sur chaque espèce',
    sections: [
      ['Lecture', 'Chaque ligne est une espèce, chaque colonne un gang. ★ = l\'espèce qui forme ce gang.'],
      ['Signatures', Object.values(GANGS).map((g) => `<b style="color:${hex(g.color)}">${g.label}</b> : ${GANG_NOTES[g.id].sign.toLowerCase()}`)],
      ['Usage', 'applyGang() marche sur l\'araignée, la mante, la mouche et la fourmi : on peut recruter n\'importe quelle espèce dans n\'importe quel gang (traîtres, recrues, PNJ).'],
    ],
    foot: 'Générée par tools/asset-generator (sheet.html?lineup)',
  });
}

const params = new URLSearchParams(location.search);
if (params.has('lineup')) lineup();
else if (params.has('gang')) gangSheet(params.get('gang'));
else characterSheet(params.get('id') ?? 'spider');
render();
