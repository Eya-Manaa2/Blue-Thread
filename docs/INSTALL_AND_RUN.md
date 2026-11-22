# BLUE THREAD: THE LAST BLUE — Installer et lancer

## Dans Godot (PC)
1. Ouvrir Godot 4.7.2 > projet `Documents/blue-thread` (rendu **Compatibility**).
2. F5 lance `scenes/Main.tscn` (point d'entrée inchangé).
3. Commandes : WASD / ZQSD / flèches ou joystick tactile (moitié gauche de l'écran) ;
   Espace / E / clic = continuer ; 1-5 = choisir un bac ; Échap = pause.
4. Mode jury : bouton **JURY DEMO MODE** dans le menu (ou touche J). En jeu, **F2** saute la phase en cours ;
   l'air descend lentement et on ne perd pas son dernier cœur. Sur le web : ajouter `?demo=1` à l'URL.
5. HUD réseau : pastille en haut à droite (clic ou N = détails, Tab = statistiques serveur, F9 = « 5G vérifiée »
   uniquement après vérification réelle du réseau).

## Base de données (Supabase) — à faire une fois
1. Supabase > SQL Editor > New query.
2. Coller `database/migrations/002_five_bins.sql` > Run. La migration est **additive et relançable** :
   elle crée `item_catalog_v2`, `sort_events_v2`, `submit_sort_v2`, `complete_level_v2`, `get_ocean_stats_v2`
   et ne touche à aucune table ni fonction existante.
3. Vérifier : `select public.get_ocean_stats_v2();`
4. Avant le jury, remettre l'océan partagé à 0 : `insert into public.ocean_resets default values;`
Tant que la migration n'est pas appliquée, le jeu lit l'ancien océan (v1) et la pastille affiche « schema v1 ».

## Export web (itch.io)
Projet > Exporter > Web > chemin vers un **nouveau dossier** (ex. `exports/web5/index.html`), compresser le contenu
du dossier en zip, téléverser sur itch.io (Kind: HTML, 1280x720, mobile friendly, SharedArrayBuffer désactivé).

## Vidéo d'intro (optionnelle)
Déposer une vidéo Theora `assets/video/intro.ogv` : elle remplace automatiquement le diaporama.
Aucune vidéo n'est fournie ni générée par le projet.
