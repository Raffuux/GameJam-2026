# Assets du décor

Assets low-poly procéduraux en Three.js, style jardin vu à hauteur d'araignée (à la Grounded).

## Conventions

- **Échelle** : 1 unité = 1 cm, tailles réelles. L'araignée joueuse fait environ 1 unité.
- **Repère** : chaque asset est posé sur `y = 0` et regarde vers `+Z`.
- **Code** : `src/assets/` ; chaque fonction `createXxx(options)` renvoie un `THREE.Object3D` neuf.
  Les options acceptent un `seed` pour varier les touffes, cailloux, etc. de façon reproductible.
- **Animation** : les insectes exposent `object.userData.update(tempsSecondes, vitesse)`
  (vitesse 0 = à l'arrêt, 1 = marche). `updateAssets(scene, t)` les anime tous.
- **Modèles .glb** : `npm run export:glb` régénère `public/models/<id>.glb` (statiques, sans animation)
  pour Blender, Godot ou Unity.

```js
import { createAsset, updateAssets } from './src/assets/index.js';
scene.add(createAsset('mantis'));
// dans la boucle de rendu
updateAssets(scene, clock.elapsedTime, 1);
```

## Aperçu

`npm install` puis `npm run dev` ouvre le « Jardin des assets » : un diorama avec tous les assets,
clique un nom pour zoomer dessus.

## Première série

| Catégorie | Assets |
|---|---|
| Végétation | touffe d'herbe, trèfle, pissenlit, champignon, caillou, brindille, feuille morte, gland |
| Objets du quotidien | canette (debout / couchée), capsule, crayon, pièce, brique de jouet, trombone |
| Insectes animés | mouche, mante religieuse, fourmi, coccinelle, scarabée rhinocéros, abeille, chenille |

## Ce qui manque encore

- L'araignée joueuse et ses toiles (fils, toile terminée, toile en construction).
- « Véhicules » façon GTA : insectes montables ou PNJ qui conduisent (coccinelle voiture, scarabée camion, chenille bus).
- Gros repères de map : arrosoir, tuyau d'arrosage, pot de fleurs, bac à sable, ballon, chaussure, pelouse tondue vs friche.
- Décor de sol en masse : tapis d'herbe instancié, terre, flaques, gouttes de rosée.
- Autres créatures : escargot, limace, ver de terre, sauterelle, papillon, guêpe, moustique.
- Sons, particules (pollen, poussière) et textures si on veut sortir du flat shading.
