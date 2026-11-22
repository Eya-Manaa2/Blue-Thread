# Manifeste des ressources

| Ressource | Origine |
|---|---|
| `assets/ui/coast_2060.jpg`, `boy_reference.jpg`, `bins_reference.jpg` | images de référence fournies par l'équipe (redimensionnées) |
| `assets/intro/slide_01..05.jpg`, `assets/ui/menu_bg.jpg`, `memory_bg.jpg`, `matte_*.png`, `boy_portrait.png` | dérivées de ces références (recadrage, étalonnage, vignette) par `tools/gen_assets.py` |
| `assets/icons/*.png`, `assets/ui/logo.png` | dessinées procéduralement par `tools/gen_assets.py` |
| `assets/fonts/FiraSans-*.ttf` | Fira Sans, licence SIL OFL (`OFL_FiraSans.txt`) ; arabe du logo rendu avec DejaVu Sans |
| Modèles 3D, mer, ciel, fumées | 100 % procéduraux (code GDScript + shaders) |
| Sons | procéduraux (`scripts/sfx.gd`, nature uniquement, pas de musique) |
| Vidéo d'intro | **aucune** fournie ; `assets/video/intro.ogv` est optionnelle |
| `assets/story/*.jpg` (intro, cartes de chapitre) | images fournies par l'équipe le 22/11 (recadrées 1280 px) |
| `assets/ui/matte_skhira.png` | dérivée de « Port industriel au coucher du soleil(1).png » (fond du niveau 2) |
| `assets/ui/matte_sidi.png` | dérivée de « Coucher de soleil sur une côte industrielle(1).png » (fond du niveau 3) |
| `assets/ui/logo_official.png` | dérivé de « Logo arabe bleu avec aiguille et vagues(1).png » |
| `assets/references/` | originaux fournis (ignorés par Godot via `.gdignore`, non versionnés sur GitHub) |
| Voix | **aucune** : la réplique de mort et les dialogues sont des sous-titres |
