SUNSET CUTSCENE
===============
The second cutscene, played in real time in the clearing at the dead end of the rock lane
(rock_a_end), then straight into the third-person play mode. Run sunset_game.tscn (F6).
About 35 seconds. Escape skips it.

What happens
------------
1. Golden hour. Cinema bars slide in. The camera pushes in down the lane on the crew sitting in a
   circle: the jumping spider (the player) with a joint in his mouth, and five friends: durag, cap,
   bandana, girl, skull.
2. Close on the hero smoking, the sunset behind him: a long pull, the tip flares, smoke.
3. Wide: his friend in the durag tells him to stop sleeping on it and pass it (line_1). He turns
   and passes it over; they laugh (laugh_1).
4. The camera rises above the grass: in fast motion (about 4 s) the sun sets behind the trees and
   the moon rises.
5. Back on the crew at night, each friend with a joint of a different size, laughing (laugh_2).
6. The camera settles behind the hero and becomes the play camera. The bars slide out and the
   radar comes back.

It stays night afterwards (moonlight). The crew stays sitting in the clearing. No text and no
radar on screen during the scene. Traffic is frozen while it plays, and cars near the clearing are
moved elsewhere first.

Lines and voices
----------------
The lines are not written yet. Each one is a timed slot (LINES at the top of sunset_cutscene.gd:
who speaks and for how long). Drop a voice file in voices/ named line_1, laugh_1 or laugh_2
(.ogg, .wav or .mp3) and it plays in its slot. A longer recording is waited for: the slot stretches to its length.

Tuning
------
CREW       who sits where, their accessory and the size of their joint in the last shot
SKY_KEYS   sky, fog, sun, moon and ambient colours for sunset, sun on the horizon, and night
RING       how wide the circle is

Files
-----
sunset_cutscene.gd   the scene: shots, crew, joints and smoke, sky and time of day, bars,
                     hand-over to play_game.gd
sunset_game.gd/.tscn play_game.tscn + the cutscene
models/spider_*.glb  the jumping spider variants from the Game Jam asset set (durag, bandana,
                     girl, skull, and the joint one, which wears the cap)
The cap, the hero's joint and the smaller joints are built in code.
Uses unchanged: play_game.gd (yaw, pitch, prompt, _update_camera), spider_player.gd (move_input,
heading, model), sunny_forest.gd (camera, post, minimap, traffic, road_network, SunnyEnvironment,
WarmSun). Nothing outside this folder is edited.

Frames without a screen: append -- --cutscene-shots=<folder> to save one image every half second.
