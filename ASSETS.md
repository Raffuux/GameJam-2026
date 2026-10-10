# Assets du décor

Assets low-poly procéduraux en Three.js, style jardin vu à hauteur d'araignée (à la Grounded).

## Conventions

- **Échelle** : 1 unité = 1 cm, tailles réelles. L'araignée joueuse fait environ 1 unité.
- **Repère** : chaque asset est posé sur `y = 0` et regarde vers `+Z`.
- **Code** : `src/assets/` ; chaque fonction `createXxx(options)` renvoie un `THREE.Object3D` neuf.
  Les options acceptent un `seed` pour varier les touffes, cailloux, etc. de façon reproductible.
- **Animation** : les insectes exposent `object.userData.update(tempsSecondes, vitesse)`
  (vitesse 0 = à l'arrêt, 1 = marche). `updateAssets(scene, t)` les anime tous.
- **Modèles .glb** : `npm run export:glb` régénère `public/models/<id>.glb`. Les insectes y ont leur
  animation cuite en boucle (`walk`, ou `hover` pour l'abeille). Les drapeaux sont statiques dans le .glb.

## Utilisation dans Godot 4

Le code Three.js sert d'outil de génération : le jeu utilise les .glb.

1. Copier `public/models/*.glb` dans le projet Godot (par exemple `res://assets/models/`).
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

## Première série

| Catégorie | Assets |
|---|---|
| Végétation | touffe d'herbe, trèfle, pissenlit, champignon, caillou, brindille, feuille morte, gland |
| Objets du quotidien | canette (debout / couchée), capsule, crayon, pièce, brique de jouet, trombone |
| Insectes animés | mouche, mante religieuse, fourmi, coccinelle, scarabée rhinocéros, abeille, chenille, araignée |
| Ville | rue droite et carrefour (tuiles 20 × 20 cm, 2 voies), banque, tour boîte de céréales, immeuble carton, immeuble brique de lait, bouche d'incendie, lampadaire allumette, poubelle, benne, sac poubelle, papier froissé, mégot, bouteille plastique |
| Props de zones | toile (Tisseuses), entrepôt boîte de sardines et flaque (docks des Prieurs), fourmilière et échafaudage en bâtons de glace (chantier de la Colonie) ; la Nuée utilise bennes, sacs et déchets |
| Gangs | un membre habillé, un drapeau, un tag graffiti et une borne de territoire par gang |

## Gangs et territoires

Définis dans `src/assets/gangs.js` (`GANGS`). Deux gangs affichent leur couleur avec un bandana,
deux portent un tatouage sur le dos.

| Gang | Espèce | Signature | Couleur | Emblème |
|---|---|---|---|---|
| Les Tisseuses | araignée | tatouage | violet | toile |
| Les Prieurs | mante religieuse | couleurs (bandana) | rouge | griffes en V |
| La Nuée | mouche | couleurs (bandana) | bleu | œil composé |
| La Colonie | fourmi | tatouage | orange | chevrons |

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
- Sons, particules (pollen, poussière) et textures si on veut sortir du flat shading.
