extends RefCounted
## The recorded lines of the script (Game Jam: dialogues/script-v2.md, audio/script-voix.md), found
## by their number. A line's file sits in this folder, named <number>_<who> (.ogg, .wav or .mp3),
## for example M2-15_girl.mp3. A cutscene asks for "M2-15" and gets that file, or nothing if it is
## not there yet: the cutscene then waits the line's fallback time in silence.
##
## To use another take of a line, give it the plain name: M1-05_ws2_b.mp3 becomes M1-05_ws2.mp3.

const DIR := "res://experiments/voices/"

## Who says each line, as written in its file name.
const WHO := {
    "M1-01": "ws1", "M1-02": "ws2", "M1-03": "ws1", "M1-04": "web-smith", "M1-05": "ws2",
    "M1-06": "web-smith", "M1-07": "ws2", "M1-08": "web-smith", "M1-09": "web-smith",
    "M1-10": "ws1", "M1-11": "ws2", "M1-12": "ws1",
    "M2-01": "bug-smoke", "M2-02": "la-bande", "M2-03": "web-smith", "M2-04": "bug-smoke",
    "M2-05": "web-smith", "M2-06": "bug-smoke", "M2-07": "web-smith", "M2-08": "bug-smoke",
    "M2-09": "bug-smoke", "M2-10": "web-smith",
    "M2-11": "bug-smoke", "M2-12": "web-smith", "M2-13": "bug-smoke", "M2-14": "web-smith",
    "M2-15": "girl", "M2-16": "web-smith", "M2-17": "girl", "M2-18": "web-smith", "M2-19": "girl",
    "M2-20": "web-smith", "M2-21": "girl", "M2-22": "bug-smoke", "M2-23": "web-smith",
    "M2-24": "web-smith", "M2-25": "web-smith", "M2-26": "web-smith", "M2-27": "web-smith",
    "M2-28": "girl", "M2-29": "bug-smoke", "M2-30": "la-bande", "M2-31": "web-smith",
    "M3-01": "unc", "M3-02": "web-smith", "M3-03": "unc", "M3-04": "web-smith", "M3-05": "unc",
    "M3-06": "unc", "M3-07": "unc", "M3-08": "unc", "M3-09": "web-smith",
    "M3-10": "young-spider", "M3-11": "web-smith", "M3-12": "web-smith", "M3-13": "web-smith",
    "M3-14": "young-spider",
    "FIN-01": "girl", "FIN-02": "web-smith", "FIN-03": "girl", "FIN-04": "girl",
    "FIN-05": "bug-smoke", "FIN-06": "web-smith",
}


## The recording of line `id` (like "M2-15"), or null if its file is not in the folder.
static func stream(id: String) -> AudioStream:
    var base := DIR + id + "_" + str(WHO.get(id, ""))
    for ext in [".ogg", ".wav", ".mp3"]:
        if ResourceLoader.exists(base + ext):
            return load(base + ext)
    return null
