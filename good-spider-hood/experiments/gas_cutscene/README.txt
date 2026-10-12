GAS STATION CUTSCENE
====================
The third cutscene, played in real time at the BUG OIL gas station, then straight into the
third-person play mode. Run gas_game.tscn (F6). About 30 seconds. Escape skips it.

The station is placed by this scene beside the top street (h0_4, halfway along, on its south side,
forecourt onto the street). Its grass is cleared (blades hidden, collision removed for the spider
and the cars).

What happens
------------
1. Cinema bars slide in. The hero's car (a red Pimpmobile) comes along the street and passes in
   front of the station.
2. It turns in and rolls up to the pumps, head-on to the camera.
3. He gets out by the driver's door, walks to the pump island and fills up ("fuel" sound slot).
4. A girl spider (the girl variant: heels, lashes, bow) walks out of the shop toward him.
5. Their eyes meet: close on her, close on him.
6. Side two-shot: his one line (line_1), she giggles (giggle).
7. The camera settles behind him and becomes the play camera. The bars slide out and the radar
   comes back. The car stays at the pump as a parked car: F gets back in.

No text and no radar on screen during the scene. Traffic is frozen while it plays, and cars near
the station are moved elsewhere first. The hero's car is one of the traffic cars, taken off the
traffic and parked at the end.

Lines and voices
----------------
The lines are not written yet. Each one is a timed slot (LINES at the top of gas_cutscene.gd:
who speaks and for how long). Drop a file in voices/ named fuel, line_1 or giggle (.ogg, .wav or
.mp3) and it plays in its slot. If it is longer, raise its duration in LINES.

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
models/spider_girl.glb  the girl jumping spider variant (from the Game Jam asset set)
Uses unchanged: play_game.gd (yaw, pitch, prompt, parked, _update_camera), player_car.gd,
spider_player.gd (move_input, heading, model, set_active), sunny_forest.gd (camera, minimap,
traffic, road_network, grass blades and collision), traffic.gd (cars, _place, _release).
Nothing outside this folder is edited.

Frames without a screen: append -- --cutscene-shots=<folder> to save one image every half second.
