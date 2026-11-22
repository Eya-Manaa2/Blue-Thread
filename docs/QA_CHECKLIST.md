# QA — état réel (21/11/2026)

Légende : OK = vu fonctionner dans Godot 4.7.2 sur le PC ; À TESTER = écrit mais pas encore vérifié.

| Élément | État |
|---|---|
| Ouverture du projet, aucune erreur de script (seulement des avertissements) | OK |
| Menu : fond, logo, boutons, mode jury, statut serveur en ligne | OK |
| Intro diaporama (Ken Burns, sous-titres, points, PASSER) | OK |
| Gabès : chargement, HUD (cœurs, score, air, objectif, restauration), dialogue radio de Mima, déplacement, bacs | OK |
| Pastille réseau repliable « ONLINE · Shared ocean » | OK |
| Boutons « Choose a shore » du menu | À REVOIR (clics non pris en compte pendant le test ; écran de chargement ajouté depuis) |
| Collecte des 5 objets, recharge O2, plus d'air > -1 cœur | À TESTER |
| Tri bonus (boutons, touches 1-5, clic sur les bacs 3D, conseils d'erreur) | À TESTER |
| Atelier de recyclage (5 types d'étapes) | À TESTER |
| Récompense, résultats, enchaînement Skhira > Sidi Mansour | À TESTER |
| Fin avec Mima, retrait du masque, statistiques, rejouer | À TESTER |
| Aperçu de restauration 0/33/67/100 | À TESTER |
| Migration SQL 002 appliquée dans Supabase | NON FAIT |
| Export web + itch.io | NON FAIT |
| Coupure réseau (4G/5G/Wi-Fi) : jeu en pause + écran CONNECTION LOST, reprise auto au retour du réseau | À TESTER (code ajouté le 22/11) |
| Preuve 5G | NON FAIT (capture du téléphone requise ; rien n'est simulé) |
