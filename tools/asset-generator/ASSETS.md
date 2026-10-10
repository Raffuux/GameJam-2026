# Assets du décor

Assets low-poly procéduraux en Three.js, style jardin vu à hauteur d'araignée (à la Grounded).

## Conventions

- **Échelle** : 1 unité = 1 cm, tailles réelles. L'araignée joueuse fait environ 1 unité.
- **Repère** : chaque asset est posé sur `y = 0` et regarde vers `+Z`.
- **Code** : `src/assets/` ; chaque fonction `createXxx(options)` renvoie un `THREE.Object3D` neuf.
  Les options acceptent un `seed` pour varier les touffes, cailloux, etc. de façon reproductible.
- **Animation** : les insectes exposent `object.userData.update(tempsSecondes, vitesse)`
  (vitesse 0 = à l'arrêt, 1 = marche). `updateAssets(scene, t)` les anime tous.
- **Modèles .glb** : `npm run export:glb` régénère `assets/models/<id>.glb` à la racine du repo (donc `res://assets/models/` dans Godot). Les insectes y ont leur
  animation cuite en boucle (`walk`, `hover` pour l'abeille, `swarm` pour les essaims, `burn` pour les feux). Les drapeaux sont statiques dans le .glb.

## Style sale et texturé

Tous les assets passent par `src/assets/grit.js` : palette assombrie et désaturée, et une vraie texture
de matière choisie selon le matériau (`src/assets/textures.js`) : béton/pierre, carton, bois, métal brossé,
plastique rayé ou peau/chitine. L'ombrage est lisse (normales adoucies), sauf au-delà de 70° où les arêtes restent nettes (`GRIT.crease`). Elle est projetée à taille constante (1 répétition = 4 cm), donc les
détails ont la même taille sur une mouche et sur un immeuble. Par-dessus : taches, saleté au pied des
objets, coulures sur ce qui est haut et rouille sur le métal, dans les couleurs de sommets (COLOR_0).
Dans les .glb, les textures sont intégrées (une par matière) : rien à régler dans Godot. Les réglages
sont en haut de `grit.js` (`GRIT`).

### Créatures : style pixel-art du jeu

Les insectes (et les membres de gang) suivent le style de l'araignée sauteuse de good-spider-hood
(`src/assets/pixel.js`) : formes lisses, pattes épaisses avec des articulations rondes, petites textures
pixel-art (fourrure mouchetée, bandes claires aux articulations) en filtrage « nearest ». Chaque matériau
reçoit une rampe de 5 couleurs tirée de sa couleur. Les variantes de l'araignée sauteuse elle-même
(durag, joint, tatouages, fille) sont dans `tools/spider-variants/` et `assets/spider_variants/`.

## Utilisation dans Godot 4

Le code Three.js sert d'outil de génération : le jeu utilise les .glb.

1. Les .glb sont déjà dans `assets/models/`, que Godot voit comme `res://assets/models/`.
2. Glisser un .glb dans une scène. 1 unité glTF = 1 cm réel, donc l'araignée fait environ 1 m dans Godot
   et la tour boîte de céréales environ 36 m. Les assets reposent sur le sol à l'origine et regardent vers +Z.
3. Pour les insectes, l'`AnimationPlayer` importé contient l'animation `walk` (ou `hover`) : activer la
   boucle dans l'onglet Import (Animation > Loop Mode) ou appeler `$AnimationPlayer.play("walk")`.
4. Pour les collisions, dans l'onglet Import, choisir Physics > Generate sur les meshes (convexe pour
   les petits objets, trimesh pour les bâtiments et les rues).

```js
import { createAsset, updateAssets } from './src/assets/index.js';
scene.add(createAsset('mantis'));
// dans la boucle de rendu
updateAssets(scene, clock.elapsedTime, 1);
```

## Aperçu

`npm install` puis `npm run dev` ouvre le « Jardin des assets » : un diorama avec le jardin, un pâté de
maisons de la ville et les territoires des gangs. Clique un nom pour zoomer dessus.

## Planches de design

`sheet.html` affiche une planche de design (vues de face, profil, dos, dessus, trois-quarts, gros plan sur
le signe de gang, palette et notes) : `sheet.html?id=spider`, `?id=mantis_prieurs`, `?gang=nuee` ou
`?lineup` (chaque espèce avec chaque signe de gang). Les PNG rendus sont dans `assets/designs/`.
Pour les régénérer : `npx vite --port 4176` puis `node scripts/design-sheets.mjs ../../assets/designs`
(avec `playwright-core` et un Chromium).

## Première série

| Catégorie | Assets |
|---|---|
| Végétation | touffe d'herbe, trèfle, pissenlit, champignon, caillou, brindille, feuille morte, gland |
| Objets du quotidien | canette (debout / couchée), capsule, crayon, pièce, brique de jouet, trombone |
| Insectes animés | mouche, mante religieuse, fourmi, coccinelle, scarabée rhinocéros, abeille, chenille, araignée |
| Ville | rue droite et carrefour (tuiles 20 × 20 cm, 2 voies), banque, tour boîte de céréales, immeuble carton, immeuble brique de lait, bouche d'incendie, lampadaire allumette, poubelle, benne, sac poubelle, papier froissé, mégot, bouteille plastique |
| Props de zones | toile (Tisseuses), entrepôt boîte de sardines et flaque (docks des Prieurs), fourmilière et échafaudage en bâtons de glace (chantier de la Colonie) ; la Nuée utilise bennes, sacs et déchets |
| Habitats des gangs | repaire aux toiles géantes des Tisseuses (`habitat_tisseuses`), nid des mantes avec oothèques des Prieurs (`habitat_prieurs`), décharge à mouches de la Nuée avec essaim animé (`habitat_nuee`), grande fourmilière en aiguilles de pin de la Colonie avec porte principale vers +Z (`habitat_colonie`) |
| Zones sales et feux | bidon en feu (`fire_can`) et feu de poubelle (`trash_fire`) avec flammes animées (clip `burn`), fumée, braises et une lumière ponctuelle orange (`fire_light`, KHR_lights_punctual → OmniLight3D dans Godot) ; tas de déchets (`litter_pile`), poubelle renversée (`spilled_bin`), tache d'huile (`oil_stain`), déchets brûlés (`burnt_trash`) |
| Gangs | un membre habillé, un drapeau, un tag graffiti et une borne de territoire par gang |

## Gangs et territoires

Définis dans `src/assets/gangs.js` (`GANGS`). Chaque membre porte un look de gang : un tatouage tête de
mort sur le dos (avec l'emblème du gang), une chaîne en or avec pendentif tête de mort et un durag satiné.
Les gangs « couleurs » (à la Bloods et Crips) ont en plus un bandana et un durag à leur couleur ; les gangs
« tatouage » portent un durag neutre et laissent parler l'encre.

| Gang | Espèce | Style | Couleur | Tatouage | Durag |
|---|---|---|---|---|---|
| Les Tisseuses | araignée | tatouage | violet | tête de mort blanche sur toile violette | noir |
| Les Prieurs | mante religieuse | couleurs (bandana) | rouge | tête de mort noire sur griffes rouges | rouge |
| La Nuée | mouche | couleurs (bandana) | bleu | tête de mort blanche sur œil composé bleu | bleu |
| La Colonie | fourmi | tatouage | orange | tête de mort et chevrons orange | kaki |

Les pièces s'appellent `gang_tattoo`, `gang_chain`, `gang_durag` et `gang_bandana` dans les .glb.

```js
import { createMantis, applyGang, createGangFlag, createGangTag, createTerritoryMarker } from './src/assets/index.js';
const soldat = applyGang(createMantis(), 'prieurs');
const drapeau = createGangFlag('prieurs');      // flotte avec updateAssets
const tag = createGangTag('nuee', { size: 4 }); // à coller sur une canette, un caillou...
const borne = createTerritoryMarker('tisseuses');
```

`applyGang` marche sur toute créature qui a des `userData.anchors` (araignée, mante, mouche, fourmi).

## Ce qui manque encore

- Les toiles d'araignée (fil, toile en construction, toile terminée) et une version joueur de l'araignée.
- « Véhicules » façon GTA : insectes montables ou PNJ qui conduisent (coccinelle voiture, scarabée camion, chenille bus).
- Gros repères humains en fond (vrais immeubles, voitures géantes, chaussure, arrosoir) et feux de circulation.
- Décor de sol en masse : tapis d'herbe instancié, terre, flaques, gouttes de rosée.
- Autres créatures : escargot, limace, ver de terre, sauterelle, papillon, guêpe, moustique.
- Sons et particules (pollen, poussière) ; dans Godot, de vraies particules de fumée rendraient mieux que les boules de fumée cuites dans les feux.
