# Personne C — Réseau, données, interface et mise en ligne (de A à Z)

Déjà prêt dans le projet :

| Fichier | Rôle |
|---|---|
| `database/schema.sql` | Tables, catalogue des 10 objets, fonctions `submit_sort` et `get_ocean_stats`, sécurité |
| `autoload/OnlineService.gd` | Envoi des tris + lecture de l'océan toutes les 2,5 s, file d'attente si le réseau coupe, mesure du temps d'aller-retour |
| `scenes/ui/HUD.tscn` + `scripts/ui/HUD.gd` | CONNECTÉ / HORS LIGNE, dernière synchro, océan global, aller-retour HTTP, statistiques (Tab), « 5G vérifiée » (F9) |
| `scenes/Main.tscn` + `scripts/Main.gd` | Assemble les scènes de A et B, branche les deux contrats ; monde de test + banc d'essai réseau (F1) tant que A et B ne sont pas prêts |
| `export_presets.cfg` | Export Web prêt (threads désactivés → aucun réglage spécial chez itch.io) |

La scène principale du projet est maintenant `scenes/Main.tscn`. L'ancien jeu solo reste dans `main.tscn` (clic droit > Exécuter la scène).

---

## H0 → H1 : créer la base Supabase (15 min)

1. Va sur **supabase.com** → *Start your project* → connecte-toi (GitHub ou e-mail).
2. **New project** : nom `blue-thread`, région **West EU (Paris)** ou Frankfurt, note le mot de passe de la base quelque part.
3. Attends ~2 min que le projet soit prêt.
4. Menu de gauche **SQL Editor** → *New query* → colle **tout** `database/schema.sql` → **Run**. Il doit afficher *Success*.
5. **Table Editor** : tu dois voir `item_catalog` (10 lignes), `sort_events` (vide), `ocean_resets`.

## H1 → H2 : brancher Godot (10 min)

6. Supabase → **Project Settings → API Keys** : copie
   - la **Project URL** (`https://xxxx.supabase.co`, visible aussi dans *Data API*)
   - la clé **publishable** (`sb_publishable_…`) — ou, si ton projet n'a que les anciennes clés, la clé **anon public**.
   - **JAMAIS** la clé *secret* / *service_role*.
7. Ouvre `autoload/OnlineService.gd` et remplace les deux lignes :
   ```
   const SUPABASE_URL := "https://xxxx.supabase.co"
   const SUPABASE_KEY := "sb_publishable_..."
   ```
   (ou envoie-les-moi et je les colle).
8. **Redémarre l'éditeur Godot** une fois (Projet > Recharger le projet actuel) pour qu'il reconnaisse `OnlineService`.
9. **F5**. Le HUD en haut à droite doit passer à **● CONNECTÉ**, « Océan global : 0 % ».
10. Banc d'essai (F1) : choisis `pet_bottle`, clique **pet** → « Réponse serveur : JUSTE », océan **4 %**.
    Puis `pet_bottle` → **cotton** → « FAUX (bon bac : pet) », l'océan **ne bouge pas**.
11. Supabase → Table Editor → `sort_events` : tes 2 lignes sont là, `is_correct` calculé par le serveur. ✅ **Preuve H2.**

## H2 → H4 : deux onglets, même océan

12. Menu « Débogage > Personnaliser les instances d’exécution… » → active et mets **2** instances, puis F5. Trie dans une fenêtre → l'autre voit l'océan monter en moins de 3 s. ✅ **Preuve H4.**

## Contrats avec A et B (à leur envoyer tel quel)

**Personne A** — dans `autoload/GameState.gd` (autoload nommé `GameState`) :
```gdscript
signal sort_completed(item_id: String, selected_bin: String, reaction_ms: int)
# après chaque clic sur un bac :
GameState.sort_completed.emit("pet_bottle", "pet", 1840)
```
Identifiants exacts : `cotton_shirt, jeans, fleece, sport_leggings, pet_bottle, pet_tray, blended_sweater, blended_socks, oily_bottle, paint_stained_shirt` ; bacs : `cotton, polyester, pet, mixed, reject`.
(Le signal peut aussi être sur un nœud de `SortingStation.tscn` : Main le trouve tout seul.)

**Personne B** — dans `scenes/Environment3D.tscn`, un nœud dont le script contient :
```gdscript
func set_ocean_progress(percent: float) -> void:   # 0 à 100
```
Main l'appelle automatiquement à chaque mise à jour du serveur.

Dès que `SortingStation.tscn` et `Environment3D.tscn` existent dans `scenes/`, Main les charge (le monde de test et le banc d'essai disparaissent ; F1 ramène le banc).

## H4 → H6 : première version en ligne (itch.io)

13. Godot → **Éditeur > Gérer les modèles d'export > Télécharger et installer** (une fois, connexion internet nécessaire).
14. **Projet > Exporter** → preset **Web** déjà prêt → **Exporter le projet** → `exports/web/index.html`.
15. Test rapide : bouton **« Exécuter dans le navigateur »** (icône HTML5 en haut à droite de l'éditeur).
16. Compresse le **contenu** de `exports/web/` en `.zip` (`index.html` doit être à la racine du zip).
17. **itch.io** → crée un compte → *Upload new project* :
    - Kind of project : **HTML**
    - Upload le zip → coche **« This file will be played in the browser »**
    - Viewport : **1280 × 720**, coche **Fullscreen button**
    - Visibility : **Public** (ou *Restricted* + mot de passe pour le jury)
18. Ouvre l'URL sur un 2ᵉ appareil (téléphone) → les deux voient le même océan. ✅ **Preuve H6.**

## H6 → H8 : statistiques et fin

19. Touche **Tab** : panneau « Statistiques en direct » (tris, précision, joueurs, temps de réaction, matières les plus difficiles) — tout vient de la base.
20. Teste au doigt sur téléphone (banc d'essai et boutons).

## H8 → H9 : preuve 5G

21. Téléphone : **Wi-Fi coupé**, vérifie que la barre affiche **5G** (capture d'écran de la barre d'état).
22. Ouvre l'URL itch.io sur le téléphone. Si le navigateur du téléphone peine en 3D : active le **point d'accès mobile** et connecte le PC dessus.
23. Dans le jeu, le HUD montre l'aller-retour HTTP réel (ms). **Seulement après vérification**, appuie sur **F9** → « Connexion : 5G vérifiée ».
    Ne jamais annoncer « 5G » si ce n'est pas vérifié ; l'aller-retour mesuré ne prouve pas à lui seul que la 5G est plus rapide que la 4G.

## H9 → H12 : gel, vidéo, QR code, démo

24. **Plus aucune nouvelle fonctionnalité.** Export final, mise à jour du zip sur itch.io.
25. **Vidéo de secours 60 s** : Win + Alt + R (Xbox Game Bar) pendant une partie + l'onglet Supabase.
26. **QR code** de l'URL itch.io (n'importe quel générateur, ou demande-moi).
27. **Juste avant le jury**, remets l'océan à 0 % (SQL Editor) :
    ```sql
    insert into public.ocean_resets default values;
    ```
28. Pendant la démo, garde ouvert Supabase → `sort_events` (rafraîchir) : le jury voit les vraies lignes arriver.
    Requête utile : `select * from public.sort_events order by created_at desc limit 20;`

## Si ça casse

| Symptôme | Cause probable | Solution |
|---|---|---|
| HUD « NON CONFIGURÉ » | URL/clé pas remplies | étape 7 |
| HUD « HORS LIGNE », erreur 401/403 | mauvaise clé ou script SQL pas lancé | recopier la clé *publishable*, relancer `schema.sql` |
| Erreur 404 sur `rpc/submit_sort` | fonctions absentes | relancer `schema.sql` |
| Écran noir dans le navigateur | WebGL / export | rendu Compatibility (déjà réglé), threads désactivés (déjà réglé), tester dans Chrome sur PC |
| Réseau coupé pendant la démo | — | le jeu continue, le HUD dit « progression partagée en pause », les tris partent dès le retour du réseau |
