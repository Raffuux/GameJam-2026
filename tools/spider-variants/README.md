# Variantes de l'araignée sauteuse

`build_variants.py` reprend l'araignée sauteuse riggée de good-spider-hood
(`assets/spider/jumping_spider.blend`, non modifiée) et lui ajoute des accessoires
attachés à ses os. Les animations (idle, walk, jump) et l'IK procédural continuent
de marcher.

| Variante | Fichier | Ce qui change |
|---|---|---|
| durag | `jumping_spider_durag` | durag violet satiné avec un nœud et deux longues queues sur l'abdomen |
| joint | `jumping_spider_joint` | longue cigarette roulée dans les chélicères, bout incandescent, fumée et petite lumière |
| skull | `jumping_spider_skull` | tatouages tête de mort noir et gris peints dans l'atlas pixel-art (abdomen + carapace) |
| girl | `jumping_spider_girl` | talons aiguilles rouges aux 8 pattes, cils, nœud rose et 4 sacs à main sur les pattes avant |

Les fichiers sont dans `assets/spider_variants/` : un `.blend` par variante (Godot l'importe
directement, comme l'original : à copier à côté de `jumping_spider.blend` et à utiliser dans
`jumping_spider_ik.tscn` à la place du modèle), un `.glb` et une image de rendu.

Même style que l'original : formes lisses, petites textures pixel-art en filtrage « nearest ».
Les accessoires sont des objets parentés aux os (`body`, `abdomen`, `leg_*_tibia`,
`leg_*_tarsus`), donc des BoneAttachment3D dans Godot.

Régénérer (Blender 4.2+ ou le module `bpy`) :

    blender -b --python build_variants.py -- chemin/vers/jumping_spider.blend ../../assets/spider_variants [durag joint skull girl]
