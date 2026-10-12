INTRO CUTSCENE (MISSION 1, OPENING)
===================================
The first cutscene, played in real time on the sunny forest streets with the real models, then
straight into the third-person play mode. Run intro_game.tscn (F6), or make it the main scene.
About 30 seconds. Escape skips it.

What happens (mission 1, lines M1-01 to M1-08)
------------
1. Cinema bars slide in. The camera follows Web Smith up Spider Hood Boulevard (main_entry) from
   behind.
2. He stops at the next crossing (n3_1) and waits to cross, looking down the cross street.
3. The Tisseuses' lowrider (the Pimpmobile at traffic size, painted purple, clear windows) comes
   along the cross street (h1_1 .. h1_4) head-on to the camera and stops in front of him.
4. Over his shoulder: WS1 (the driver) and WS2 (beside her) mock him (M1-01 to M1-03).
5. Reverse shot from the car: he talks back (M1-04). Wide: "You, spida." They laugh (M1-05).
6. Close on him: he can weave (M1-06). Over his shoulder: "Show us then" (M1-07).
7. He turns his back on them and walks off, "Keep your eight eyes open" (M1-08); the camera slides
   behind him and becomes the play camera. The lowrider stays parked at the crossing: they watch
   him try (the weaving gameplay). The closing scene is m1_end_cutscene.

Lines and voices
----------------
Each line is a numbered line of the script (Game Jam: dialogues/script-v2.md). Its recording is
played from experiments/voices/, found by its number (M1-01 to M1-08, see voice_lines.gd).
Without the file the line lasts its fallback time in silence (LINES / lines at the top of the
script). With it, the line lasts as long as the recording.

Files
-----
intro_cutscene.gd   the scene: shots, hero, lowrider, leaves, bars, hand-over to play_game.gd
intro_game.gd/.tscn play_game.tscn + the cutscene
models/spider_tisseuses.glb  the Tisseuses gang member (from the Game Jam asset set)
Uses unchanged: play_game.gd (yaw, pitch, prompt, _update_camera), spider_player.gd (move_input,
heading, model.snap_feet), sunny_forest.gd (camera, minimap, traffic, road_network) and
assets/vehicles/pimpmobile/pimpmobile_glass.tscn. Nothing outside this folder is edited.

Frames without a screen: append -- --cutscene-shots=<folder> to save one image every half second.
