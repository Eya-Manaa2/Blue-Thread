# Architecture

Flux : `Main` > `MainMenu` (PLAY / CONTINUE) > `ProfileSetup` (nom + 6 avatars) > `IntroVideo` (histoire illustrée + carte titre) > carte de chapitre > `LevelController` x3 (Gabès, Skhira, Sidi Mansour, carte de chapitre entre chaque) > carte épilogue > `Ending` (carte finale) > stats / rejouer.
`RestorationPreview` (menu) montre chaque rivage à 0 / 33 / 67 / 100 %.

| Fichier | Rôle |
|---|---|
| `autoload/GameState.gd` | score (+10 tri juste, -5 et -1 cœur tri faux, +10 collecte, +15 étape), 3 cœurs, oxygène **1 unité/s** (float, `maxf(air - 1.0*delta, 0)`), profil local (nom validé 2-20 caractères, avatar 0-5), inventaire réel par niveau, sauvegarde `user://blue_thread_save.cfg`, restauration LOCALE 0-100, stats, actions clavier |
| `autoload/OnlineService.gd` | Supabase : `submit_sort` (v1, conservé), `submit_sort_v2`, `complete_level_v2`, lecture `get_ocean_stats_v2` (repli v1 si migration absente) ; chemin `fetch()` du navigateur sur le web |
| `scripts/data/GameData.gd` | 5 bacs, 27 objets triables + objets de recette / pièges (hors serveur), 6 avatars, 3 niveaux (collecte, pièges, tri bonus, étapes PAPER 4 / TEXTILE 5 / PET 7, dialogues), scènes d'intro, chapitres, fin — généré par `tools/gen_data.py` (+ `tools/levels_part.gd.txt`) ; le SQL généré est inchangé |
| `scripts/Main.gd` | orchestration, écran de chargement, contrats : `GameState.sort_completed` > `OnlineService.submit_sort_v2` ; `global_progress_changed` > `set_ocean_progress()` du décor |
| `scripts/game/LevelController.gd` | phases INTRO > COLLECT (5 utiles + 3 pièges -5 s, chronomètre 3 min) > TO_STATION > SORT > WORKBENCH (objets réellement ramassés sur l'établi) > PUZZLE > REWARD > RESULTS ; DEAD (mort unique, effondrement, caméra proche, désaturation, « Mima... I have failed you. », MISSION FAILED, reprise au point de contrôle) ; obstacles physiques ; pause ; F2 jury |
| `scripts/world/LevelWorld.gd` | terrain, mer (shader), ciel, fond peint, fumées, décor propre à chaque rivage ; API `configure_level`, `set_local_restoration`, `set_ocean_progress`, `height_at` |
| `scripts/world/Boy.gd` | le gardien (hérite de `player.gd`, même squelette/contrôleur pour les 6 avatars) : peau, cheveux ou foulard selon l'avatar, même équipement ; `remove_mask()`, `collapse()`, `revive()` |
| `scripts/world/LevelWorld.gd` (obstacles) | `add_obstacles()` : 9 barils rouillés (StaticBody3D + cylindre) et 6 branches (StaticBody3D + boîte 1,1 m), loin des points importants |
| `scripts/ui/ProfileSetup.gd` | « What should we call you? », 6 aperçus 3D (SubViewport), START actif seulement si nom valide + avatar |
| `scripts/world/FiveBinStation.gd` | 5 bacs à roulettes (couvercles animés, icônes, étiquettes, surbrillance) |
| `scripts/world/ItemFactory.gd`, `Grandma.gd`, `Mats.gd` | modèles procéduraux des objets/récompenses, Mima, boîte à outils 3D |
| `scripts/ui/*` | `UiKit` (polices Fira incluses), `GameHUD`, `StoryDialog`, `RecyclingPuzzle`, `ResultsPanel`, `Modal`, `MainMenu`, `IntroVideo`, `HUD` réseau repliable |
| `shaders/` | `sea`, `terrain`, `beam` (compatibles WebGL2) |

Deux valeurs distinctes : restauration **locale** (histoire, 0 > 33 > 67 > 100) et océan **global** (serveur, tous les joueurs,
+2 % par tri juste, +5 % par niveau fini). La valeur globale n'agit que sur le large (mouettes), jamais sur l'histoire.

Sauvegardes des anciennes versions : `backups/` (Main, HUD, OnlineService, project.godot, export_presets).
Jeu historique conservé : `main.tscn` + `scripts/street_game.gd`.
