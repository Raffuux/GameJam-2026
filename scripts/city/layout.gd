extends RefCounted
## Plan de la ville d'insectes. 1 unité = 1 cm, l'araignée fait environ 1 cm.
## Vue de dessus : +x vers l'est, -z vers le nord. La ville fait 12 m x 12 m, coincée
## entre les immeubles des humains, au pied d'une ruelle.

const HALF := 600.0
const ROAD_W := 40.0
const ROADS := [-300.0, 0.0, 300.0]
const CURB_H := 4.0
const SPAWN := Vector3(10.0, 0.0, 60.0)

## Les quartiers. "gang" vide = territoire neutre.
const ZONES := {
	"centre": {
		"name": "Le Centre-Ville", "gang": "", "tagline": "Territoire neutre",
		"color": Color("d8d2c2"),
	},
	"tisseuses": {
		"name": "La Toile", "gang": "Les Tisseuses", "tagline": "Territoire des Tisseuses (araignées)",
		"color": Color("8e44ad"),
	},
	"prieurs": {
		"name": "Le Port de la Flaque", "gang": "Les Prieurs", "tagline": "Territoire des Prieurs (mantes)",
		"color": Color("d63a2f"),
	},
	"nuee": {
		"name": "La Décharge", "gang": "La Nuée", "tagline": "Territoire de la Nuée (mouches)",
		"color": Color("2f6fd6"),
	},
	"colonie": {
		"name": "Le Chantier", "gang": "La Colonie", "tagline": "Territoire de la Colonie (fourmis)",
		"color": Color("e8862a"),
	},
}

## Quel quartier occupe chaque pâté de maisons. BLOCKS[j][i], j = ligne (0 au nord), i = colonne (0 à l'ouest).
const BLOCKS := [
	["tisseuses", "tisseuses", "prieurs", "prieurs"],
	["tisseuses", "centre", "centre", "prieurs"],
	["colonie", "centre", "centre", "nuee"],
	["colonie", "colonie", "nuee", "nuee"],
]

## Pâtés spéciaux : le reste est rempli d'immeubles selon le quartier.
const SPECIAL := {
	Vector2i(1, 1): "bank",
	Vector2i(2, 2): "park",
	Vector2i(3, 0): "puddle",
	Vector2i(3, 3): "dumpster",
	Vector2i(0, 3): "construction",
}


static func block_index(v: float) -> int:
	return clampi(int(floor((v + HALF) / 300.0)), 0, 3)


static func zone_at(x: float, z: float) -> String:
	return BLOCKS[block_index(z)][block_index(x)]


static func zone_of_block(i: int, j: int) -> String:
	return BLOCKS[j][i]


## Rectangle (x, z) du pâté, sans les demi-rues autour.
static func block_rect(i: int, j: int) -> Rect2:
	var x0 := -HALF + i * 300.0 + (ROAD_W / 2.0 if i > 0 else 0.0)
	var x1 := -HALF + (i + 1) * 300.0 - (ROAD_W / 2.0 if i < 3 else 0.0)
	var z0 := -HALF + j * 300.0 + (ROAD_W / 2.0 if j > 0 else 0.0)
	var z1 := -HALF + (j + 1) * 300.0 - (ROAD_W / 2.0 if j < 3 else 0.0)
	return Rect2(x0, z0, x1 - x0, z1 - z0)
