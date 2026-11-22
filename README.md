# BLUE THREAD: THE LAST BLUE

Jeu 3D Godot 4.7 (rendu Compatibility, web + mobile) — Team SUP'ANANAS (SUP'COM),
Green Hackathon 2026, Swedish-Tunisian Games & Innovation Days.

Tunisie, 2060. Yassine, 12 ans, masque à gaz et bouteille d'oxygène, restaure trois rivages
— Gabès (papier), Skhira (textile), Sidi Mansour (PET) — en collectant, triant dans 5 bacs
(PAPER, TEXTILE, PET, RESIDUAL, SPECIAL) et recyclant, jusqu'à rendre la mer bleue à sa grand-mère Mima.

- Lancer : ouvrir le dossier dans Godot 4.7.2, F5 (`scenes/Main.tscn`).
- Jouer en ligne : https://eya-manaa2.itch.io/blue-thread-connected-ocean
- Docs : `docs/INSTALL_AND_RUN.md`, `docs/ARCHITECTURE.md`, `docs/QA_CHECKLIST.md`, `docs/ASSET_MANIFEST.md`
- Base de données : `database/schema.sql` (v1) + `database/migrations/002_five_bins.sql` (5 bacs, additive)

La clé Supabase présente dans `autoload/OnlineService.gd` est la clé **publique** (publishable) :
les tables sont verrouillées (RLS) et le jeu ne passe que par des fonctions limitées.
Ne jamais ajouter de clé secrète / service_role dans le dépôt.
