# Spider Jam — Game Jam 2026

Une araignée qui apprend à tisser des toiles, dans un monde ouvert au ras du sol (ambiance *Grounded*), peuplé d'insectes qui marchent, volent et conduisent.

## Assets

### Bestiaire 3D (`assets/bestiaire/`)
Visionneuse des créatures low-poly : ouvrir `assets/bestiaire/index.html` dans un navigateur (connexion nécessaire pour charger Three.js).

| Créature | Rôle en jeu | Taille réelle | Modes animés |
|---|---|---|---|
| Épeire (*Araneus diadematus*) | Héroïne | 15 mm | repos, marche, au bout du fil |
| Mouche verte (*Lucilia sericata*) | Proie | 10 mm | repos, marche, vol |
| Mante religieuse (*Mantis religiosa*) | Prédatrice | 70 mm | affût, marche, frappe |
| Fourmi rousse (*Formica rufa*) | Habitante | 7 mm | repos, marche, porte une miette |
| Coccinelle (*Coccinella septempunctata*) | Passante | 7 mm | repos, marche, envol |
| Abeille (*Apis mellifera*) | Livreuse | 13 mm | repos, marche, vol |

Les modèles sont générés en code (`creatures.js`) : chaque fonction construit la bête à partir de primitives facettées, avec des pivots nommés (`Leg_R1`, `Wing_L_flap`, `Arm_R`, `Antenna_L`, `Head`…).

### Modèles exportés (`assets/models/*.glb`)
Pose de repos, facettes conservées, prêts pour Godot / Unity / Unreal / Blender.
Échelle : l'araignée mesure 1,8 unité de long et les autres sont à l'échelle réelle relative (la mante fait ~8,4 unités).
Avant = +Z, haut = +Y. Les animations ne sont pas exportées ; les pivots nommés permettent de les refaire dans le moteur.

Régénérer après modification de `creatures.js` :

```sh
npm i -D playwright && npx playwright install chromium
node tools/export-glb.mjs
```
