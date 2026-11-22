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
