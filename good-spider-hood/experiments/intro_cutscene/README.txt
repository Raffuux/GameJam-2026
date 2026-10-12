INTRO CUTSCENE
==============
The first cutscene, played in real time on the sunny forest streets with the real models, then
straight into the third-person play mode. Run intro_game.tscn (F6), or make it the main scene.
About 30 seconds. Escape skips it.

What happens
------------
1. Cinema bars slide in. The camera follows the jumping spider up Spider Hood Boulevard
   (main_entry) from behind.
2. He stops at the next crossing (n3_1) and waits to cross, looking down the cross street.
3. The Tisseuses' lowrider (the Pimpmobile at traffic size, painted purple, clear windows) comes
   along the cross street (h1_1 .. h1_4) head-on to the camera and stops in front of him.
4. Over his shoulder: the three Tisseuses in the car look at him (lines 1 and 2).
5. Reverse shot from the car: the hero (line 3).
6. Wide shot: they laugh, the car bounces on its hydraulics, then drives off and blows up the
   dead leaves.
7. He turns back down the boulevard, walks past the camera, and the camera slides behind him and
   becomes the play camera. The bars slide out and the radar comes back.

No text and no radar on screen during the scene. Traffic is frozen while it plays, and cars near the
crossing are moved elsewhere first.

Lines and voices
----------------
The lines are not written yet. Each one is a timed slot (LINES at the top of intro_cutscene.gd:
who speaks and for how long). Drop a voice file in voices/ named line_1, line_2, line_3 or laugh
(.ogg, .wav or .mp3) and it plays in its slot. A longer recording is waited for: the slot stretches to its length.

Files
-----
intro_cutscene.gd   the scene: shots, hero, lowrider, leaves, bars, hand-over to play_game.gd
intro_game.gd/.tscn play_game.tscn + the cutscene
models/spider_tisseuses.glb  the Tisseuses gang member (from the Game Jam asset set)
Uses unchanged: play_game.gd (yaw, pitch, prompt, _update_camera), spider_player.gd (move_input,
heading, model.snap_feet), sunny_forest.gd (camera, minimap, traffic, road_network) and
assets/vehicles/pimpmobile/pimpmobile_glass.tscn. Nothing outside this folder is edited.

Frames without a screen: append -- --cutscene-shots=<folder> to save one image every half second.
