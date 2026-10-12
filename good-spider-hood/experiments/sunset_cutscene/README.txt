SUNSET CUTSCENE
===============
The second cutscene, played in real time in the clearing at the dead end of the rock lane
(rock_a_end), then straight into the third-person play mode. Run sunset_game.tscn (F6).
About 35 seconds. Escape skips it.

What happens (mission 2, lines M2-01 to M2-10)
------------
1. Golden hour. Cinema bars slide in. The camera pushes in down the lane on the gang sitting in a
   circle: Web Smith (the player) and Bug Smoke (the durag), a blunt in his mouth, with four
   friends (cap, bandana, girl, skull).
2. Two-shot: Bug Smoke gives him grief for the web (M2-01); the gang laughs (M2-02).
3. Close-ups, back and forth: weaving is his dream (M2-03); they are jumping spiders, not orb
   weavers (M2-04); he wishes he had a chance (M2-05).
4. Two-shot: "That's just life" (M2-06). Bug Smoke passes him the blunt (it arcs over).
5. He worries how they'll eat if they're all high (M2-07); "Quit whinin'" (M2-08). A long pull.
6. "...'cause you drivin'" (M2-09). He coughs, "Shit." (M2-10). They laugh.
7. The camera rises above the grass: in fast motion the sun sets and the moon rises.
8. Back on the gang at night, each friend with a joint, laughing. The camera settles behind the
   hero and becomes the play camera.

Lines and voices
----------------
Each line is a numbered line of the script (Game Jam: dialogues/script-v2.md). Its recording is
played from experiments/voices/, found by its number (M2-01 to M2-10, see voice_lines.gd).
These ten are not recorded yet: drop M2-01_bug-smoke.mp3 and the others in experiments/voices/.
Without the file the line lasts its fallback time in silence (LINES / lines at the top of the
script). With it, the line lasts as long as the recording.

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
