# 22/11/2026 — Voix off, sons plus doux, jeu plus léger, visage de Mima

## Son
- **Vent supprimé** : plus de boucle de vent ni de bourrasques (ni à l'intro, ni en jeu, ni aux paliers). Les mouches sont supprimées aussi.
- Ambiance discrète : bourdonnement d'usine très bas (Gabès 0,10 / Skhira 0,05 / Sidi Mansour 0,015), mer plus douce, grincements rares et lointains, oiseaux et mouettes moins fréquents et beaucoup plus bas, feuillage et cigales presque inaudibles (seulement quand la côte revit).
- Bruitages d'interface adoucis (échec, mauvais bac, bip d'oxygène, bon tri).
- **Petite musique d'ambiance** : arpèges de piano lents (Do, La mineur, Fa, Sol), très bas, avec leurs propres lecteurs (ils ne coupent jamais un bruitage). Coupée pendant l'intro et pendant la scène de mort.
- `sfx.gd` ne génère plus les sons inutilisés (vent, mouches, bourrasque, alarme) : démarrage un peu plus rapide.

## Voix off (nouveau : `scripts/Voice.gd`)
- Les phrases de l'intro et tous les dialogues (Mima, le joueur, la fin) sont **lus à voix haute** avec la synthèse vocale de l'appareil (`DisplayServer.tts_*` ; `audio/general/text_to_speech=true`).
- Une voix par rôle : narrateur (voix grave, débit posé), Mima (voix féminine, lente), le joueur (voix claire, plus aiguë). Les voix « Natural / Online / Google » sont préférées quand elles existent.
- Intro : chaque phrase attend la fin de la précédente, et le plan attend la fin de la dernière phrase (avec un garde-fou si la voix ne répond pas).
- **V** : couper / remettre la voix (message à l'écran). Sans voix disponible, le jeu se comporte comme avant (sous-titres seuls).
- Honnêteté : aucune voix n'est enregistrée ni générée par le projet ; le timbre dépend de Windows ou du navigateur du joueur (Edge et Chrome ont les voix les plus naturelles).

## Intro : histoire plus claire (8 plans)
1. Golfe de Gabès, 2060 : fumées et déchets ont rendu la mer grise, l'air n'est plus respirable.
2. Les enfants ne sortent qu'avec une bouteille d'oxygène, qui ne dure pas ; un garçon garde espoir.
3–5. Mima se souvient de la mer bleue (le souvenir est maintenant raconté par sa voix) et voudrait la revoir.
6. La promesse du petit-fils.
7. **Nouveau plan « mission »** : trois rivages (Gabès, Skhira, Sidi Mansour) ; ramasser les déchets avant la fin de l'oxygène, les trier dans les bons bacs, les recycler, et la mer redevient bleue.
8. Titre, sur l'image de la mer bleue.

## Performance (le jury joue lui-même)
- **Fusion des décors statiques** (`Mats.merge`) : palmiers, oliviers, buissons, fleurs, arbres morts, filets, barils, grues, épave, barques, complexe industriel → un maillage par matériau (un palmier : 46 appels de dessin → 3).
- **Personnages** (`Mats.merge_direct`) : pièces rigides du garçon fusionnées par membre (jambes, bras, torse, tête, masque restent animés séparément) : environ 120 → une cinquantaine d'objets.
- Bacs de tri, établi, bornes d'oxygène, objets à ramasser fusionnés ; les lumières des bacs éteintes sont désactivées.
- Ciel / brouillard / lumières / shaders recalculés **seulement quand la restauration change** (avant : à chaque image, ce qui recalculait l'éclairage du ciel en continu) ; carte d'éclairage du ciel 64 px.
- Ombres : 2 passes au lieu de 4 sur ordinateur, 1 passe sur navigateur ; atlas 2048 ; distance 45 m (34 m web).
- Navigateur : pas de glow, mer moins subdivisée. MSAA 2× gardé sur ordinateur, coupé sur mobile web.
- Caméra de jeu plus réactive (suit le joueur sans traîne) ; les plans de cinématique gardent leurs mouvements lents.
- Mesuré dans l'éditeur (PC de l'équipe, RTX 3050, Gabès au début) : **593 → 470 appels de dessin**, et environ 290 en marchant sur la plage ; 140–145 FPS (limité par l'écran). Le mode démo (J au menu) affiche ce compteur en haut à gauche. Pas encore mesuré sur un portable sans carte graphique ni sur téléphone.

## Mima
- Les deux « boules » des joues et la boule du menton sont supprimées : joues simplement rosées, à fleur de peau ; menton arrondi par un volume intérieur.
- Nez plus fin (sans narines sombres), yeux un peu plus grands, sillons nez-bouche retirés (ils ressemblaient à des moustaches), sourire plus doux.
- **Tête agrandie (×1,6)** pour le même style « gros visage expressif » que le petit-fils : son visage paraissait minuscule dans le foulard.
