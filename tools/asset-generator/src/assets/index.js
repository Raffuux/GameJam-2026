// Asset catalog. Every factory returns a fresh THREE.Object3D at real scale
// (1 unit = 1 cm), standing on y = 0 and facing +Z.
// Animated assets expose `object.userData.update(timeSeconds, speed)`.
import * as nature from './nature.js';
import * as objects from './objects.js';
import * as insects from './insects.js';
import * as gangs from './gangs.js';
import * as city from './city.js';
import * as habitats from './habitats.js';

export * from './nature.js';
export * from './objects.js';
export * from './insects.js';
export * from './gangs.js';
export * from './city.js';
export * from './habitats.js';
export { PALETTE } from './common.js';

export const CATALOG = [
  { id: 'grass_clump', label: 'Touffe d\'herbe', category: 'nature', create: nature.createGrassClump },
  { id: 'clover', label: 'Trèfle', category: 'nature', create: nature.createClover },
  { id: 'dandelion', label: 'Pissenlit', category: 'nature', create: nature.createDandelion },
  { id: 'mushroom', label: 'Champignon', category: 'nature', create: nature.createMushroom },
  { id: 'pebble', label: 'Caillou', category: 'nature', create: nature.createPebble },
  { id: 'twig', label: 'Brindille', category: 'nature', create: nature.createTwig },
  { id: 'fallen_leaf', label: 'Feuille morte', category: 'nature', create: nature.createFallenLeaf },
  { id: 'acorn', label: 'Gland', category: 'nature', create: nature.createAcorn },
  { id: 'soda_can', label: 'Canette', category: 'object', create: objects.createSodaCan },
  { id: 'soda_can_lying', label: 'Canette couchée', category: 'object', create: () => objects.createSodaCan({ lying: true }) },
  { id: 'bottle_cap', label: 'Capsule', category: 'object', create: objects.createBottleCap },
  { id: 'pencil', label: 'Crayon', category: 'object', create: objects.createPencil },
  { id: 'coin', label: 'Pièce', category: 'object', create: objects.createCoin },
  { id: 'toy_brick', label: 'Brique de jouet', category: 'object', create: objects.createToyBrick },
  { id: 'paperclip', label: 'Trombone', category: 'object', create: objects.createPaperclip },
  { id: 'fly', label: 'Mouche', category: 'insect', create: insects.createFly },
  { id: 'mantis', label: 'Mante religieuse', category: 'insect', create: insects.createMantis },
  { id: 'ant', label: 'Fourmi', category: 'insect', create: insects.createAnt },
  { id: 'ladybug', label: 'Coccinelle', category: 'insect', create: insects.createLadybug },
  { id: 'beetle', label: 'Scarabée rhinocéros', category: 'insect', create: insects.createBeetle },
  { id: 'bee', label: 'Abeille', category: 'insect', create: insects.createBee },
  { id: 'caterpillar', label: 'Chenille', category: 'insect', create: insects.createCaterpillar },
  { id: 'spider', label: 'Araignée', category: 'insect', create: insects.createSpider },
  { id: 'road_straight', label: 'Rue droite', category: 'city', create: city.createRoadStraight },
  { id: 'road_cross', label: 'Carrefour', category: 'city', create: city.createRoadCross },
  { id: 'bank', label: 'Banque', category: 'city', create: city.createBank },
  { id: 'building_tower', label: 'Tour boîte de céréales', category: 'city', create: city.createTowerBuilding },
  { id: 'building_box', label: 'Immeuble carton', category: 'city', create: city.createBoxBuilding },
  { id: 'building_carton', label: 'Immeuble brique de lait', category: 'city', create: city.createCartonBuilding },
  { id: 'fire_hydrant', label: "Bouche d'incendie", category: 'city', create: city.createFireHydrant },
  { id: 'street_lamp', label: 'Lampadaire allumette', category: 'city', create: city.createStreetLamp },
  { id: 'trash_bin', label: 'Poubelle', category: 'city', create: city.createTrashBin },
  { id: 'dumpster', label: 'Benne', category: 'city', create: city.createDumpster },
  { id: 'trash_bag', label: 'Sac poubelle', category: 'city', create: city.createTrashBag },
  { id: 'crumpled_paper', label: 'Papier froissé', category: 'city', create: city.createCrumpledPaper },
  { id: 'cigarette_butt', label: 'Mégot', category: 'city', create: city.createCigaretteButt },
  { id: 'plastic_bottle', label: 'Bouteille plastique', category: 'city', create: city.createPlasticBottle },
  { id: 'spider_web', label: 'Toile (Tisseuses)', category: 'zone', create: city.createSpiderWeb },
  { id: 'warehouse', label: 'Entrepôt sardines (Prieurs)', category: 'zone', create: city.createWarehouse },
  { id: 'puddle', label: 'Flaque des docks (Prieurs)', category: 'zone', create: city.createPuddle },
  { id: 'anthill', label: 'Fourmilière (Colonie)', category: 'zone', create: city.createAnthill },
  { id: 'scaffolding', label: 'Échafaudage (Colonie)', category: 'zone', create: city.createScaffolding },
  { id: 'habitat_tisseuses', label: 'Repaire aux toiles (Tisseuses)', category: 'habitat', create: habitats.createWebLair },
  { id: 'habitat_prieurs', label: 'Nid des mantes (Prieurs)', category: 'habitat', create: habitats.createMantisNest },
  { id: 'habitat_nuee', label: 'Décharge (Nuée)', category: 'habitat', create: habitats.createFlyDump },
  { id: 'habitat_colonie', label: 'Fourmilière (Colonie)', category: 'habitat', create: habitats.createAntMound },
];

// Gang members, flags, graffiti tags and territory markers for each gang.
const memberFactory = { spider: insects.createSpider, mantis: insects.createMantis, fly: insects.createFly, ant: insects.createAnt };
for (const gang of Object.values(gangs.GANGS)) {
  CATALOG.push(
    { id: `${gang.species}_${gang.id}`, label: `Membre · ${gang.label}`, category: 'gang', gang: gang.id, create: (o) => gangs.applyGang(memberFactory[gang.species](o), gang.id) },
    { id: `flag_${gang.id}`, label: `Drapeau · ${gang.label}`, category: 'gang', gang: gang.id, create: () => gangs.createGangFlag(gang.id) },
    { id: `tag_${gang.id}`, label: `Tag · ${gang.label}`, category: 'gang', gang: gang.id, create: () => gangs.createGangTag(gang.id) },
    { id: `marker_${gang.id}`, label: `Borne · ${gang.label}`, category: 'gang', gang: gang.id, create: (o) => gangs.createTerritoryMarker(gang.id, o) },
  );
}

export function createAsset(id, options) {
  const entry = CATALOG.find((e) => e.id === id);
  if (!entry) throw new Error(`Unknown asset "${id}"`);
  return entry.create(options);
}

// Advance every animated asset under `root`.
export function updateAssets(root, time, speed = 1) {
  root.traverse((o) => o.userData.update?.(time, speed));
}
