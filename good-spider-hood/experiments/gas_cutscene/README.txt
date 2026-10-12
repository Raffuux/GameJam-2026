GAS STATION CUTSCENE
====================
The third cutscene, played in real time at the BUG OIL gas station, then straight into the
third-person play mode. Run gas_game.tscn (F6). About 30 seconds. Escape skips it.

The station is placed by this scene beside the top street (h0_4, halfway along, on its south side,
forecourt onto the street). Its grass is cleared (blades hidden, collision removed for the spider
and the cars).

What happens (mission 2, lines M2-11 to M2-22)
------------
1. Cinema bars slide in. Web Smith's car (a red Pimpmobile, clearer windows) comes along the
   street, Bug Smoke beside him and two of the gang in the back, and passes the station.
2. It turns in and rolls up to the pumps, head-on to the camera.
3. He gets out by the driver's door, walks to the pump island and fills up ("fuel" sound).
4. A weaver (the girl variant: heels, lashes, bow) walks out of the shop.
5. Through the windscreen: Bug Smoke, "look at that fine weaver" (M2-11). Close on Web Smith:
   "she a 8... Imma show you how it's done" (M2-12). Bug Smoke: "Go 'head, Casanova" (M2-13).
6. He walks over to her on the open side of the forecourt. Two-shot: "Ayo, shawty" (M2-14),
   "...What." (M2-15). Close-ups back and forth (M2-16 to M2-19). Two-shot: "Gimme one minute"
   (M2-20), "One minute. Go." (M2-21).
7. Through the windscreen: Bug Smoke whispers "he cookin'... or he finna get cooked" (M2-22).
8. The camera settles behind him and becomes the play camera (the weaving gameplay). The car stays
   at the pump as a parked car, the gang inside: F gets back in. The closing scene is
   m2_turned_down_cutscene.

Lines and voices
----------------
Each line is a numbered line of the script (Game Jam: dialogues/script-v2.md). Its recording is
played from experiments/voices/, found by its number (M2-11 to M2-22, see voice_lines.gd).
Without the file the line lasts its fallback time in silence (LINES / lines at the top of the
script). With it, the line lasts as long as the recording.
The pump is a sound, not a line: a file named fuel (.ogg, .wav or .mp3) in this folder's voices/.

Tuning
------
STREET, ALONG   which street the station stands on, and how far along it
CAR_STOP, HERO_SPOT, PUMP, SHOP_DOOR, GIRL_SPOT, WATCH, TWO_SHOT, PLAY_FROM
                spots on the station, in its centimetres (x right, z toward the street)

Files
-----
gas_cutscene.gd      the scene: station placement and grass, car drive, hero, girl, shots,
                     bars, hand-over to play_game.gd (car parked as play_game.parked)
gas_game.gd/.tscn    play_game.tscn + the cutscene
models/gas_station.glb  BUG OIL station (from the rounded buildings set)
models/spider_girl.glb  the girl jumping spider variant (from the Game Jam asset set), the weaver
                     until her own design is in. The gang uses the sunset scene's models.
Uses unchanged: play_game.gd (yaw, pitch, prompt, parked, _update_camera), player_car.gd,
spider_player.gd (move_input, heading, model, set_active), sunny_forest.gd (camera, minimap,
traffic, road_network, grass blades and collision), traffic.gd (cars, _place, _release).
Nothing outside this folder is edited.

Frames without a screen: append -- --cutscene-shots=<folder> to save one image every half second.
