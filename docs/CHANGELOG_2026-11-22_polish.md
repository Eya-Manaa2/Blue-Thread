# Changelog: final cinematic and gameplay polish (22/11, second pass)

Base: GitHub commit `7feac80`. The previous version is kept in the git history, which serves as the backup.
No interface redesign: same UiKit, same fonts, same layout. The online part is unchanged apart from the request optimisations below. `database/migrations/002_five_bins.sql` is produced byte for byte.

| File | Change |
|---|---|
| `scripts/Main.gd` | New order: menu → **cinematic intro** → name and avatar selection → Gabès → … The intro never replays between levels. **SKIP INTRO** leads to avatar selection, never straight into gameplay. **Sea map** between shores. Hidden jury shortcut: F3 in the menu (demo mode only) jumps to the ending. |
| `scripts/ui/IntroVideo.gd` + `GameData.INTRO_SCENES` | Short intro of about **36 s** in 7 shots: 2060 coast, the grandson, Mima ("When I was young…"), flashback of the blue sea, "I wish I could see it again…", "I promise, Mima. I'll bring the blue back.", title card **BLUE THREAD — THE LAST BLUE** in English. Speaker label **GRANDSON**. One sentence per shot, subtitles synchronised. Sound for each shot. |
| `autoload/GameState.gd`, `GameData` | Oxygen: `air = maxf(air - delta / 0.7, 0)`, so one unit every 0.7 s (100 units ≈ 70 s). **2 refills for the whole adventure** (`refills_remaining`, saved, never restored by a restart or a checkpoint). |
| `scripts/game/LevelController.gd` | Stations: one refill per charge, only when air is below 75 %; "EMPTY" when none are left. Shorter walking distances. Low-air beep. Distractor and wrong-sort sounds. **End-of-level restoration**: camera on the coast, sea turning blue, plants growing in turn with sparkles, hopeful music. Highlight halo on the item to sort; flat items are tilted towards the camera. |
| `scripts/ui/GameHUD.gd` | "O2 REFILLS LEFT: n / 2" shown in the same panel. |
| `scripts/ui/RecyclingPuzzle.gd` + steps in `GameData` | **No more multiple-choice questions.** Each step = name + one short sentence + "ACTION: …". Paper 4 steps (collection, pulping, cleaning/de-inking by action, drying and rolling), textile 5, PET 6. Machine sound when a step is done. |
| `scripts/world/ItemFactory.gd`, `GameData` | Simple, recognisable sorting items: newspaper, notebook, cardboard box, sweater, scarf, T-shirt, water bottle, soda bottle, used tissue, broken mug, **used battery (SPECIAL)**. Newly modelled. |
| `scripts/world/LevelWorld.gd` | Removed: white houses, white marabout, coloured blobs, **fallen branches** (and their collisions), driftwood. Obstacles = 12 rusty barrels (StaticBody3D). Added shrubs and flowers. Gentle sway of vegetation. `play_restoration()` for the end of a level. Brighter sky, less haze. Dead trees near the camera are hidden. |
| `shaders/sea.gdshader`, `shaders/terrain.gdshader` | Restored sea is much bluer (turquoise near the shore, deep blue offshore), less glare. Sand less white. |
| `scripts/world/Grandma.gd` | **New Mima**, procedural, same style as the grandson: expressive eyes, eyelids that blink, soft wrinkles, embroidered tied headscarf, shawl, embroidered dress, hands. Animations: breathing, blinking, head following a target, smile, taking the grandson's hand. |
| `scripts/game/Ending.gd` | **5-shot ending** on the restored Sidi Mansour shore (terrace above the sea): flyover, "The blue... it's back.", "I kept my promise, Mima.", close-up and holding hands, "You didn't just bring back the sea... you brought back hope.", shot towards the sea, then **BLUE THREAD — THE LAST BLUE / Every small action can begin a brighter future.** Mima's portrait appears in the dialogue box. |
| `scripts/ui/SeaMap.gd` (new) | **Map of the Gulf of Gabès between shores**: a small boat sails from one port to the next; the sea clears behind it and the oil slicks fade; the whole sea turns bluer little by little. **The shore score decides the distance** (the route swings further offshore). The trail is saved. |
| `scripts/sfx.gd` | New procedural sounds (no external file): industrial hum, alarm, O2 beep, breathing, metal creak, chime, failure sound, refill hiss, machine, piano, music pads. Ambience for each shore (heavy industry in Gabès, softer in Skhira, birds in Sidi Mansour). Sounds for death, level complete and restoration. |
| `autoload/OnlineService.gd` | Polling every 3.5 s instead of 2.5 s, timeouts of 6 s, **duplicate sorts ignored** (same sort within 0.5 s). Local feedback never waits for the server. |
| `assets/ui/logo.png`, `tools/gen_assets.py` | **Arabic subtitle removed** from the logo; the Arabic logo `logo_official.png` is no longer shown anywhere (file kept). The English title stays. |

## Limits (honest)
- No voices: subtitles only. The music is short procedural original sound (piano and pads).
- Mima remains a procedural model; no rigged model is used.
- No intro video (.ogv) is provided: the intro uses the illustrated shots.
- 5G is not tested or simulated.
