# BLUE THREAD — الخيط الأزرق
Sidi Bou Saïd, 2100. Équipe SUP'ANANAS — Green Hackathon 2026

## Lancer le jeu
1. Décompresse le zip.
2. Copie TOUT son contenu dans ton dossier de projet `BlueThread` (accepte de remplacer `project.godot`).
3. Ouvre le projet dans Godot 4.7, attends la fin de l'import, puis appuie sur **F5**.

## Commandes
- Déplacer : ZQSD (AZERTY) / WASD (QWERTY) / flèches, ou joystick tactile (moitié gauche de l'écran)
- Lancer le déchet du haut de la pile dans le bac le plus proche : **Espace**, **E** ou le bouton LANCER
- Passer une réplique : Entrée ou clic — Passer l'intro : Échap

## Ce que contient le jeu
- Intro cinématique (vol au-dessus de la ville grise, titre « 2100 »), dialogues Jedda / Yassine / Am Hédi
- Ramassage automatique, pile qui oscille sur le dos (6 max)
- 4 bacs (jaune plastique & métal, bleu papier, vert verre, marron organique), 2 stations dans la rue
- Erreur de tri : le bac recrache le déchet + carte « Le savais-tu ? »
- Combos en darija : Behi ! / Behi barcha ! / Ya3tik essa7a ! / Tbarkallah 3lik ! / Rak m3allem !
- La ville reprend ses couleurs : portes bleues (25 %), bougainvilliers et jasmin (50 %), chats (75 %), lanternes (80 %+), les tas de déchets fondent
- Le fil bleu guide le joueur (vers le déchet le plus proche, ou vers les bacs quand la pile est pleine)
- Chehili : toutes les 45 s, tempête de sable, nouveaux déchets, le vent arrache le haut de la pile
- 2 objets rares dorés (bouteille de 2026, bocal de 2026) → flashback sépia dans le présent
- Bou Kornine à l'horizon, la mer qui redevient bleue dans la scène finale, écran de fin + Rejouer
- Paysage sonore 100 % naturel, sans musique, fabriqué par code (aucun fichier audio) :
  - ville polluée : vent lugubre, mouches, mer lointaine et étouffée
  - au fil des tris : bruissement des feuilles (25 %+), moineaux sur les toits, cigales (45 %+), mouettes au-dessus de la mer (55 %+), miaulements quand les chats reviennent
  - la mer est spatialisée : on l'entend de plus en plus fort en approchant de la terrasse
  - bruitages par matière : tintement du verre, clang de la canette, froissement du plastique, « poc » du carton, « splotch » de l'organique
  - pas sur les pavés, rafales du Chehili, grosse vague et mouettes dans la scène finale
  - le jeu met 1 à 2 secondes à démarrer : c'est le temps de fabriquer les sons

## Réglages rapides (en haut de `scripts/main.gd`)
- `GOAL` : nombre de bons tris pour finir (30 ; mets 12 pour une démo courte devant le jury)
- `MAX_STACK`, `START_TRASH`, `CHEHILI_EVERY`

## Enregistrer le trailer
Godot a un mode « Movie Maker » : icône de clap en haut à droite de l'éditeur.
Dans Projet > Paramètres du projet > Editor > Movie Writer, choisis un fichier de sortie `trailer.avi`, puis lance le jeu : tout est enregistré image par image.

## À déclarer au jury (article 8 du règlement)
Le code a été écrit avec l'aide d'une IA générative pendant le hackathon. Déclarez aussi toute musique, voix ou modèle 3D externe que vous ajoutez.
