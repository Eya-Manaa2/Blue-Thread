# QA — état réel (22/11/2026, 03 h 57)

Légende : OK = vu fonctionner dans Godot 4.7.2 sur le PC (fenêtre de jeu, éditeur) ; À TESTER = écrit mais pas encore vérifié à l'écran.

| Élément | État |
|---|---|
| Ouverture du projet, lancement F5, aucune erreur de script (avertissements seulement) | OK |
| Menu : « Choose a shore », « Jury demo mode » et pied de page retirés ; reste PLAY / PREVIEW / statut serveur | OK |
| Profil : champ « What should we call you? », erreur « Use letters, spaces, apostrophes or hyphens only. » pour « E1 », START grisé tant que nom + avatar manquent, START actif ensuite | OK |
| 6 aperçus 3D distincts (garçon peau foncée, garçon peau claire, rousse, blonde, foulard, bouclée), halo de sélection | OK |
| Profil enregistré puis pré-rempli au relancement (nom + avatar) | OK |
| Intro illustrée (nouvelles images, répliques une par une, nom Mima) puis carte « CHAPTER 1 · GABÈS » | OK |
| HUD « KEEPER: EYA », chronomètre, oxygène : chrono et air baissent ensemble de 1/s (180 s / 100 % → 2:58 / 97 % ; 2:47 / 86 %) | OK |
| Objet piège (canette) : « -5 s · NOT PAPER: METAL DRINK CAN » + explication, ne compte pas (0/5) | OK |
| Recharge O2 : « AIR REFILLED », jauge réelle remise à 100 | OK |
| Barils et branches bloquent le joueur | OK pour les barils/branche droite ; une branche ronde pouvait être escaladée → collision remplacée par une boîte de 1,1 m (correctif à revérifier à l'écran) |
| Mort à 0 % : contrôles gelés, chrono figé, effondrement au sol, désaturation + vignette, « Mima... I have failed you. » avec le nom et le portrait, puis MISSION FAILED / Your promise is not over. | OK (1er essai : caméra proche dans un obstacle → choix d'angle par rayon ajouté, à revérifier) |
| Retry from checkpoint : retour à l'entrée, air 100 %, chrono remis, cœurs gardés, couleurs normales | OK |
| Mode jury (J au menu, F2) : collecte sautée, bonus de temps | OK |
| Tri bonus, établi avec les objets réellement ramassés, étapes PAPER/TEXTILE/PET | À TESTER (test interrompu : PC utilisé) |
| Récompense, résultats, cartes de chapitre 2 et 3, fonds Skhira / Sidi Mansour | À TESTER |
| Fin : répliques exactes, Mima en personne, carte finale | À TESTER |
| CONTINUE après relance | À TESTER |
| Clic sur une carte d'avatar | OK, mais dans la fenêtre de jeu intégrée à l'éditeur, le premier clic après un changement de fenêtre est parfois perdu (comportement de la fenêtre de débogage, pas du jeu) |
| Coupure réseau : écran CONNECTION LOST | À TESTER sur téléphone |
| Export web + itch.io de cette version | NON FAIT |
| Preuve 5G | NON FAIT (capture du téléphone requise ; rien n'est simulé) |
