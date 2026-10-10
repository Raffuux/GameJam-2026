# La map : Spider Hood

Une ville d'insectes façon GTA, nichée au fond d'une ruelle entre des immeubles humains.
Projet **Godot 4.4** (renderer Compatibility, exportable en web). Ouvrir `project.godot` puis F5.

Échelle : **1 unité = 1 cm**, l'araignée fait environ 1,5 cm. La ville fait 12 m x 12 m.

![Carte des territoires](docs/map/carte.png)

![Vue d'ensemble](docs/map/vue-ensemble.png)

## Les quartiers et les gangs

Grille de 4 x 4 pâtés de maisons séparés par des rues (avec trottoirs, passages piétons et marquages).
Chaque quartier est teinté de la couleur de son gang sur le radar et sur la carte (touche **M**).

| Quartier | Gang | Couleur | Ce qu'on y trouve |
|---|---|---|---|
| Le Centre-Ville | neutre | beige | la Banque Centrale (colonnes en crayons, piles de pièces), les plus hautes tours, le parc avec une fontaine-capsule et la bouche d'incendie géante |
| La Toile (nord-ouest) | Les Tisseuses (araignées) | violet | ruelles serrées, immeubles sombres, néons, toiles tendues entre les toits (on peut marcher dessus) |
| Le Port de la Flaque (nord-est) | Les Prieurs (mantes) | rouge | une flaque d'eau sur laquelle on marche, pontons en bâtons de glace, conteneurs en boîtes d'allumettes, entrepôts |
| La Décharge (sud-est) | La Nuée (mouches) | bleu | la benne à ordures géante, sacs poubelle, part de pizza, trognon de pomme, cabanes en bâche |
| Le Chantier (sud-ouest) | La Colonie (fourmis) | orange | immeuble en construction à escalader, grue, briques, tas de sable, fourmilières, cônes |

Partout : lampadaires, bouches d'incendie, canettes, capsules, mégots, boulettes de papier, drapeaux et tags de gang.
En fond : murs de briques de la ruelle, une épicerie au sud, et un skyline de gratte-ciel dans la brume dorée.

## Jouer

- **ZQSD / WASD** bouger, **Maj** sprint, **Espace** sauter, **souris** caméra, **molette** zoom
- Pousser contre n'importe quel mur pour **grimper** ; lâcher les touches pour rester accroché ; Espace pour sauter du mur
- **E** accroche un fil, **E** encore le tend : il devient une passerelle sur laquelle on marche
- **M** carte des territoires, **Échap** libère la souris
- 25 **pièces** à trouver (5 par quartier), souvent sur les toits

## Code

| Fichier | Rôle |
|---|---|
| `scripts/city/layout.gd` | le plan : quartiers, gangs, couleurs, quel pâté est spécial |
| `scripts/city/city.gd` | construit la ville (rues, immeubles par quartier, lieux spéciaux, fond) |
| `scripts/city/props.gd` | mobilier urbain et déchets, un objet par fonction |
| `scripts/city/builder.gd` | primitives avec collisions, fils de soie |
| `scripts/player/spider.gd` | déplacement, escalade, fils |
| `scripts/ui/hud.gd` | radar, nom du quartier, compteurs, carte |

Tout est généré en code au lancement avec une graine fixe : la ville est identique à chaque partie.

### Brancher les modèles du bestiaire

- `assets/models/epeire.glb` sert de joueuse (sinon une araignée en primitives).
- `mante`, `mouche`, `fourmi` et `epeire` sont placés comme membres de gangs dans leur territoire.
- Si ces fichiers existent dans `assets/models/`, ils remplacent les primitives sans changer les collisions :
  `benne.glb`, `bouche_incendie.glb`, `canette.glb`, `sac_poubelle.glb`, `capsule.glb`.

### Captures automatiques

```sh
godot --path . -- --shots=/tmp/shots
```

Lance une série de vues de chaque quartier, la carte, et des tests d'escalade, de trottoir et de fil, puis quitte.

Avec `-- --shots=/tmp/shots --overview`, il fait plutôt des vues aériennes de toute la ville.

## Pistes pour la suite

- Véhicules insectes (scarabée, coccinelle) sur les rues
- Gangs qui patrouillent et réagissent quand on entre dans leur territoire
- Missions de livraison et prise de territoire
