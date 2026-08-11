# Durus 2.0 (`com.tdg.durus2`)

Application Flutter (Android) de lecture du Coran et des livres de Cheikh
Ahmadou Bamba Khadimou Rassoul — portage natif du site PHP `Xassidati`.

Voir **`MAPPING_FONCTIONNALITES.md`** pour la cartographie complète
PHP → Flutter (ce qui a été repris, simplifié, ou volontairement exclu).

## Mise en route (méthode recommandée, via le script TDG)

Ce livrable contient déjà tout le code applicatif (`lib/`), les assets
d'icône (`assets/icon/`) et une configuration `android/` de référence.
Cependant, `gradlew` / `gradlew.bat` / le jar du wrapper Gradle ne peuvent
pas être générés en dehors d'un environnement Flutter réel — la méthode la
plus sûre est donc de laisser votre script habituel créer l'ossature
Android complète, puis d'y déposer le code de ce livrable :

```bash
# 1. Génère un projet vierge correctement configuré (Gradle/AGP/Kotlin TDG)
~/0-apps/tdg-flutter-template/bin/tdg-flutter-create.sh durus2
cd durus2

# 2. Remplace le contenu par celui de ce livrable, SAUF android/
#    (le script vient déjà de configurer android/ correctement)
rm -rf lib pubspec.yaml
cp -r /chemin/vers/ce/livrable/lib .
cp /chemin/vers/ce/livrable/pubspec.yaml .
cp -r /chemin/vers/ce/livrable/assets .
cp /chemin/vers/ce/livrable/MAPPING_FONCTIONNALITES.md .

# 3. Vérifie que android/app/build.gradle.kts a bien
#    namespace = "com.tdg.durus2" / applicationId = "com.tdg.durus2"
#    (déjà le cas si généré avec --org com.tdg durus2)

flutter pub get
flutter run
```

Les fichiers dans `android/` fournis avec ce livrable (`settings.gradle.kts`,
`gradle.properties`, `gradle-wrapper.properties`, `app/build.gradle.kts`,
`AndroidManifest.xml`, `MainActivity.kt`, `styles.xml`,
`launch_background.xml`) reprennent exactement votre configuration de
référence (`FLUTTER_DEV_ENV_CONFIGS.md`) avec `namespace`/`applicationId`
déjà positionnés sur `com.tdg.durus2` : ils servent de **référence /
fallback** si vous préférez repartir de `flutter create` manuellement
plutôt que du script (dans ce cas, remplacez les fichiers générés par
ceux-ci, comme indiqué dans la "Checklist manuelle" de votre doc).

## Icône de lancement

Les ressources Android générées automatiquement ont été retirées
d'`android/app/src/main/res/` à votre demande, pour que vous lanciez
vous-même la génération. Les fichiers sources sont dans `assets/icon/`
(`icon_legacy_1024.png`, `ic_foreground_adaptive.png`,
`ic_background_adaptive.png`, cadre bleu conservé, marge blanche externe
retirée) et `pubspec.yaml` contient déjà la config `flutter_launcher_icons`
correspondante. Une fois `flutter pub get` effectué, lancez :

```bash
dart run flutter_launcher_icons
```

pour générer tous les fichiers nécessaires dans `android/app/src/main/res/`.

## Dépôt distant des livres

Le catalogue et les pages des livres sont lus depuis
`github.com/taysirdigitalgroup/xassidati-datas` (branche `main`), avec la
même arborescence que l'ancien serveur PHP :
`<groupe>/<livre>/config/config.json` et `<groupe>/<livre>/images/*.ext`.
Toutes les constantes (dépôt, branche, URLs, cache, base de données) sont
centralisées dans `lib/core/constants/app_constants.dart`.

## Journal des correctifs / évolutions (retour utilisateur)

- **Bug RTL/LTR corrigé à la racine** : la langue d'un livre est désormais
  TOUJOURS lue depuis son vrai `config.json` (`"lang": "ar"`), plus jamais
  devinée depuis le nom de dossier (souvent translittéré en latin même pour
  un livre arabe, ex. "Al Quran - Juz-u 01"). Pour une collection, la
  langue du PREMIER livre (selon sa position actuelle) est re-vérifiée à
  l'ouverture pour rester cohérente après une réorganisation.
- **Performance** : le catalogue complet (avec vrais noms latin/arabe et
  langue) est chargé une seule fois avec une concurrence limitée puis mis
  en cache disque ; les listes utilisent désormais `Selector` au lieu de
  `Consumer` complet pour éviter des reconstructions inutiles ; le rendu
  des pages utilise `InteractiveViewer` (plus léger que `photo_view`).
- **One Page** : un seul écran (`MainScreen`) avec un Drawer (bibliothèque
  + recherche) et une zone de lecture permanente — il n'y a plus de
  navigation séparée pour lire un livre.
- **Marque-page visible à l'ouverture** : si un marque-page existe, une
  bannière "Continuer la lecture" apparaît dès le lancement de l'app.
- **Duplication/référencement illimité** : ajouter un livre déjà
  téléchargé à une (autre) collection ne retélécharge ni ne duplique
  jamais les images — seule une référence est ajoutée en base.
- **Thème** : surlignage de recherche adaptatif (fini le jaune illisible
  en sombre), mode sombre en bleu nuit moderne plutôt que noir.
- **Page Développeur** : présentation de Taysir Digital Group, contacts,
  soutien (PayPal/Wave/Orange Money), à retrouver via l'icône ⓘ de l'AppBar.
- **Icône de lancement** : les ressources générées manuellement ont été
  retirées d'`android/` ; la config `flutter_launcher_icons` reste dans
  `pubspec.yaml`, prête à être lancée par vous (`dart run flutter_launcher_icons`).


## Pièges connus à surveiller (voir FLUTTER_DEV_ENV_CONFIGS.md)

- Ne pas laisser `flutter create` régénérer des fichiers Gradle plus
  récents (AGP 9.x / Kotlin 2.3.x) : toujours revenir aux versions de
  référence (AGP 8.11.1 / Kotlin 2.2.20 / Gradle 8.14.1).
- `sqflite`/`path_provider`/`http`/`shared_preferences`/`url_launcher`/
  `package_info_plus` sont des plugins stables et bien maintenus : aucun
  piège connu similaire à `ffmpeg_kit_flutter` ou `record` pour ce projet.
- Tester `flutter build apk --debug` dès la première mise en route, avant
  d'ajouter d'autres dépendances.
