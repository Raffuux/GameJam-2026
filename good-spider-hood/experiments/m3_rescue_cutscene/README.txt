M3 RESCUE CUTSCENE (MISSION 3, THE YOUNG SPIDER IN DANGER)
==========================================================
Played in real time at the big rock at the end of rock lane B (the landmark rock nearest
rock_b_end), then straight into the play mode: the rescue is gameplay. Run m3_rescue_game.tscn
(F6). About 15 seconds. Escape skips it.

What happens (lines M3-10 and M3-11)
------------
1. Day. Web Smith wanders along the foot of the rock.
2. A cry from above: a young weaver hangs from the rock's top edge on one thread, swinging over
   the drop. "Help! I can't hold on!" (M3-10).
3. Wide: the rock, the thread, the hero small at its foot.
4. Close on him: "Damn, somebody do somethin'!" He looks left, right... "Ain't nobody comin'.
   Aight. Jump, Smith." (M3-11). The camera becomes the play camera.

The young spider keeps hanging and swinging afterwards (for the rescue gameplay).

Tuning
------
NEAR         the junction whose nearest landmark rock is used
HANG         the length of the young spider's thread
YOUNG_MODEL, YOUNG_SIZE  the young spider (for now the bandana jumping spider at 55 %, until
             his own design is in)

Files
-----
m3_rescue_cutscene.gd   the scene (extends ../cutscene_kit/mission_cutscene.gd); finds the rock's
                        ledge from its mesh
m3_rescue_game.gd/.tscn play_game.tscn + the cutscene
