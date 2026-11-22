# Architecture

Flux : `Main` > `MainMenu` > `IntroVideo` (.ogv ou diaporama) > `LevelController` x3 (Gabès, Skhira, Sidi Mansour) > `Ending` > stats / rejouer.
`RestorationPreview` (menu) montre chaque rivage à 0 / 33 / 67 / 100 %.

| Fichier | Rôle |
|---|---|
| `autoload/GameState.gd` | score (+10 tri juste, -5 et -1 cœur tri faux, +10 collecte, +15 étape), 3 cœurs, oxygène (0,45/s, 0,12/s en démo), restauration LOCALE 0-100, stats, actions clavier |
| `autoload/OnlineService.gd` | Supabase : `submit_sort` (v1, conservé), `submit_sort_v2`, `complete_level_v2`, lecture `get_ocean_stats_v2` (repli v1 si migration absente) ; chemin `fetch()` du navigateur sur le web |
| `scripts/data/GameData.gd` | 5 bacs, 27 objets, 3 niveaux (étapes, dialogues, faits), fin, diapos — généré par `tools/gen_data.py` avec le SQL |
| `scripts/Main.gd` | orchestration, écran de chargement, contrats : `GameState.sort_completed` > `OnlineService.submit_sort_v2` ; `global_progress_changed` > `set_ocean_progress()` du décor |
| `scripts/game/LevelController.gd` | phases INTRO > COLLECT > TO_STATION > SORT > PUZZLE > REWARD > RESULTS, recharges O2, réapparition, pause, F2 jury |
| `scripts/world/LevelWorld.gd` | terrain, mer (shader), ciel, fond peint, fumées, décor propre à chaque rivage ; API `configure_level`, `set_local_restoration`, `set_ocean_progress`, `height_at` |
| `scripts/world/Boy.gd` | Yassine (hérite de `player.gd`) : masque à gaz, tuyau annelé, bouteille O2, veste, gants, genouillères, bottes, montre ; `remove_mask()` |
| `scripts/world/FiveBinStation.gd` | 5 bacs à roulettes (couvercles animés, icônes, étiquettes, surbrillance) |
| `scripts/world/ItemFactory.gd`, `Grandma.gd`, `Mats.gd` | modèles procéduraux des objets/récompenses, Mima, boîte à outils 3D |
| `scripts/ui/*` | `UiKit` (polices Fira incluses), `GameHUD`, `StoryDialog`, `RecyclingPuzzle`, `ResultsPanel`, `Modal`, `MainMenu`, `IntroVideo`, `HUD` réseau repliable |
| `shaders/` | `sea`, `terrain`, `beam` (compatibles WebGL2) |

Deux valeurs distinctes : restauration **locale** (histoire, 0 > 33 > 67 > 100) et océan **global** (serveur, tous les joueurs,
+2 % par tri juste, +5 % par niveau fini). La valeur globale n'agit que sur le large (mouettes), jamais sur l'histoire.

Sauvegardes des anciennes versions : `backups/` (Main, HUD, OnlineService, project.godot, export_presets).
Jeu historique conservé : `main.tscn` + `scripts/street_game.gd`.
