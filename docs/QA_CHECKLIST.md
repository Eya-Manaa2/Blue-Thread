# QA — état réel (22/11/2026, 06 h 00, après la passe « polish »)

Légende : OK = vu fonctionner dans Godot 4.7.2 sur le PC ; À TESTER = écrit mais pas vérifié à l'écran.

| Élément | État |
|---|---|
| Lancement F5, aucune erreur de script | OK |
| Menu : START ADVENTURE, logo sans texte arabe, titre anglais conservé | OK |
| Ordre : menu → intro → choix nom/avatar → Gabès | OK |
| Intro ~36 s, 7 plans, « GRANDSON », sous-titres courts, carte « BLUE THREAD — THE LAST BLUE » | OK |
| SKIP INTRO (Échap) → choix de l'avatar (pas le niveau) | OK |
| Oxygène : 99 % → 89 % en ~7 s (1 unité / 0,7 s) | OK |
| Recharge : refusée au-dessus de 75 % (message), acceptée en dessous → « 1 / 2 », compteur gardé entre les niveaux | OK |
| Recharges épuisées → station « EMPTY » | À TESTER |
| Mort / « Mima... I have failed you. » / reprise (déjà validé à la passe précédente ; logique inchangée) | OK (passe précédente) |
| Objets à trier : journal lisible, mouchoir, t-shirt, pile ; confirmation serveur | OK |
| Atelier : plus de QCM ; « COLLECTION / phrase / ACTION » ; nettoyage par action (taches) ; PET en 6 étapes | OK |
| Fin de rivage : caméra vers la côte, « SHORE RESTORED », plantes et étincelles | OK (effet discret à 33 %, net à 67 % et 100 %) |
| Carte marine : bateau, sillage bleu, distance selon le score, sillage conservé d'un voyage à l'autre | OK |
| Maisons blanches, marabout, tas colorés, branches tombées : absents | OK |
| Mer finale nettement plus bleue | OK |
| Herbe en brins fins (au lieu de grands triangles) | OK |
| Mima refaite (foulard noué, yeux, rides, sourire, main tendue) + portrait dans le dialogue | OK |
| Fin en 5 plans, répliques exactes, carte finale, statistiques | OK |
| Sons (ambiance, carillon, échec, bip O2, recharge, machine, musique) | Déclenchés dans le code ; à juger à l'oreille (le test se fait sans écouter le son) |
| Réseau : tris confirmés par le serveur, anti-doublon | OK (tris confirmés à l'écran) |
| Coupure réseau sur téléphone (CONNECTION LOST) | À TESTER sur téléphone |
| Export web + itch.io | voir rapport de livraison |
| Preuve 5G | NON FAIT (rien n'est simulé) |

## 22/11 — voix off / son / performance (vérifié dans l'éditeur Godot sur le PC de l'équipe)
- [x] Intro : 8 plans, sous-titres, indication « VOICE-OVER · press V to mute » (voix Windows détectée), rythme réglé sur la lecture des phrases, Échap -> profil.
- [x] Aperçus des 6 avatars corrects après la fusion des maillages.
- [x] Gabès : compteur démo 470 appels de dessin au départ, ~290 sur la plage, 140+ FPS ; marche, ramassage, pénalité objet inutile OK.
- [x] Aperçu de restauration Skhira et Sidi Mansour à 100 % : grues, épave, barques, oliviers OK.
- [x] Fin (F3 en démo) : Mima avec la nouvelle tête, dialogues OK.
- [ ] À écouter par l'équipe : la voix off et la nouvelle ambiance (je ne peux pas entendre le son à distance).
- [ ] À tester : version web sur un portable du jury (Chrome/Edge), et sur téléphone.
