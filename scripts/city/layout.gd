extends RefCounted
## Plan de la ville d'insectes. 1 unité = 1 cm, l'araignée fait environ 1,5 cm.
## Vue de dessus : +x vers l'est, -z vers le nord. La ville fait 12 m x 12 m, coincée
## entre les murs d'une ruelle humaine. Les rues sont des tracés courbes, les quartiers
## ont des frontières irrégulières : rien n'est aligné sur une grille.

const HALF := 600.0
const SPAWN := Vector3(25.0, 0.0, 150.0)

## Les quartiers. "gang" vide = territoire neutre. "seed" = cœur du quartier, "weight" < 1 = quartier plus étendu.
const ZONES := {
	"centre": {
		"name": "Le Centre-Ville", "gang": "", "tagline": "Territoire neutre",
		"color": Color("d8d2c2"), "seed": Vector2(10, -20), "weight": 0.92,
	},
	"tisseuses": {
		"name": "La Toile", "gang": "Les Tisseuses", "tagline": "Territoire des Tisseuses (araignées)",
		"color": Color("8e44ad"), "seed": Vector2(-430, -420), "weight": 1.0,
	},
	"prieurs": {
		"name": "Le Port de la Flaque", "gang": "Les Prieurs", "tagline": "Territoire des Prieurs (mantes)",
		"color": Color("d63a2f"), "seed": Vector2(420, -400), "weight": 1.0,
	},
	"nuee": {
		"name": "La Décharge", "gang": "La Nuée", "tagline": "Territoire de la Nuée (mouches)",
		"color": Color("2f6fd6"), "seed": Vector2(430, 420), "weight": 1.0,
	},
	"colonie": {
		"name": "Le Chantier", "gang": "La Colonie", "tagline": "Territoire de la Colonie (fourmis)",
		"color": Color("e8862a"), "seed": Vector2(-430, 410), "weight": 1.0,
	},
}

## Les rues : [nom, largeur, points de passage]. Les tracés sont lissés en courbes.
const ROADS := [
	["Grande Avenue", 46.0, [Vector2(-40, -640), Vector2(-10, -300), Vector2(40, -80), Vector2(20, 130), Vector2(-30, 350), Vector2(10, 640)]],
	["Boulevard des Toiles", 38.0, [Vector2(-420, 640), Vector2(-300, 260), Vector2(-60, 60), Vector2(200, -120), Vector2(640, -250)]],
	["Rue du Nord", 28.0, [Vector2(-640, -190), Vector2(-320, -240), Vector2(0, -265), Vector2(290, -210), Vector2(640, -160)]],
	["Rue du Sud", 28.0, [Vector2(-640, 170), Vector2(-320, 150), Vector2(0, 250), Vector2(300, 230), Vector2(640, 260)]],
	["Rue de l'Est", 30.0, [Vector2(230, -640), Vector2(265, -300), Vector2(310, 60), Vector2(255, 360), Vector2(300, 640)]],
	["Rue de l'Ouest", 26.0, [Vector2(-300, -640), Vector2(-335, -250), Vector2(-270, 40), Vector2(-305, 255)]],
	# ruelles tortueuses de La Toile
	["Ruelle des Fils", 16.0, [Vector2(-640, -470), Vector2(-500, -455), Vector2(-430, -520), Vector2(-335, -500)]],
	["Ruelle Sombre", 16.0, [Vector2(-500, -640), Vector2(-470, -540), Vector2(-500, -380), Vector2(-430, -320), Vector2(-335, -330)]],
	["Impasse de l'Araignée", 14.0, [Vector2(-640, -320), Vector2(-560, -350), Vector2(-500, -380)]],
	# petites rues
	["Rue du Parc", 22.0, [Vector2(20, 130), Vector2(110, 175), Vector2(220, 170), Vector2(310, 60)]],
	["Allée des Bennes", 20.0, [Vector2(300, 640), Vector2(380, 520), Vector2(520, 540), Vector2(640, 500)]],
	["Rue des Briques", 20.0, [Vector2(-640, 300), Vector2(-520, 260), Vector2(-420, 300), Vector2(-360, 400)]],
	["Quai des Mantes", 22.0, [Vector2(265, -300), Vector2(330, -330), Vector2(330, -560), Vector2(400, -600), Vector2(640, -580)]],
	["Passage de la Banque", 18.0, [Vector2(-335, -250), Vector2(-250, -40), Vector2(-60, 60)]],
]

## Lieux spéciaux : position, rayon réservé (aucun immeuble ordinaire dedans).
const SITES := {
	"bank": {"pos": Vector2(-150, -120), "r": 105.0},
	"park": {"pos": Vector2(150, 60), "r": 85.0},
	"puddle": {"pos": Vector2(470, -420), "r": 125.0},
	"dumpster": {"pos": Vector2(450, 400), "r": 115.0},
	"construction": {"pos": Vector2(-490, 450), "r": 105.0},
}
const PUDDLE_R := 110.0


static func zone_at(x: float, z: float) -> String:
	# Voronoï pondéré + ondulations : des frontières qui serpentent comme de vrais quartiers.
	var wobble := sin(x * 0.013 + z * 0.007) * 45.0 + sin(z * 0.021 - x * 0.011) * 30.0
	var best := ""
	var best_d := INF
	for id in ZONES:
		var zd: Dictionary = ZONES[id]
		var d: float = Vector2(x, z).distance_to(zd["seed"]) * zd["weight"]
		if id != "centre":
			d += wobble
		if d < best_d:
			best_d = d
			best = id
	return best


## Courbe lissée (Catmull-Rom) d'une rue, échantillonnée tous les `step` unités environ.
static func sample_road(points: Array, step: float = 6.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, n - 1)]
		var segs := maxi(2, int(p1.distance_to(p2) / step))
		for s in segs:
			var t := s / float(segs)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out
