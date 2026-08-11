<div align="center">

<img src="assets/icon/icon_legacy_1024.png" alt="Durus 2.0" width="96">

# Durus 2.0

**Bibliothèque mobile du Coran et des livres de Cheikh Ahmadou Bamba Khadimou Rassoul**

Portage natif Flutter/Android du site PHP **Xassidati** — lecture 100% hors-ligne,
sens RTL/LTR automatique, collections personnalisées.

`com.tdg.durus2` · Flutter · Android

[![Latest release](https://img.shields.io/github/v/release/taysirdigitalgroup/durus2?label=derni%C3%A8re%20version)](../../releases/latest)
[![License](https://img.shields.io/badge/license-propri%C3%A9taire-blue.svg)](#licence)

[Télécharger l'APK](../../releases/latest) · [Cartographie fonctionnelle détaillée](MAPPING_FONCTIONNALITES.md)

</div>

---

## Sommaire

- [Aperçu](#aperçu)
- [Fonctionnalités](#fonctionnalités)
- [Installation (utilisateur)](#installation-utilisateur)
- [Mise en route (développeur)](#mise-en-route-développeur)
- [Icône de lancement](#icône-de-lancement)
- [Architecture](#architecture)
- [Dépôt distant des livres](#dépôt-distant-des-livres)
- [Journal des correctifs récents](#journal-des-correctifs-récents)
- [Pièges connus / environnement de build](#pièges-connus--environnement-de-build)
- [Licence](#licence)

---

## Aperçu

Durus 2.0 est une application Android qui donne accès, **sans connexion après
téléchargement**, à l'ensemble du catalogue de livres religieux distribué par
Taysir Digital Group : le Coran (rivayat Warsh, découpé par Juz ou en un seul
volume) et plusieurs centaines de Qasà-id, avec traductions (français, wolof,
anglais...).

C'est un portage complet du site PHP `Xassidati` vers une app native mono-
utilisateur, sans compte ni backend : tout ce qui était auparavant synchronisé
via MySQL devient local (SQLite embarqué + fichiers sur l'appareil). Le détail
exhaustif de cette conversion (fonctionnalité par fonctionnalité, ce qui a été
repris, simplifié ou exclu) est documenté dans
**[`MAPPING_FONCTIONNALITES.md`](MAPPING_FONCTIONNALITES.md)**.

## Fonctionnalités

- 📖 **Lecture Coran & Qasà-id** — rendu image par image, zoom, navigation par
  numéro de page.
- 🔄 **Sens de lecture RTL/LTR automatique** — déterminé par la vraie langue de
  chaque livre (champ `lang` de son `config.json`), jamais devinée depuis le nom
  du dossier.
- 📥 **Lecture 100% hors-ligne** — téléchargement des livres à la demande,
  aucune re-téléchargement si déjà présent (référencement, pas duplication).
- 🗂️ **Collections personnalisées** — organisation libre, réorganisation par
  glisser-déposer, **lecture groupée en continu** de tous les livres d'une
  collection.
- 🔖 **Marque-page** — reprise de lecture immédiate au lancement de l'app.
- 🔍 **Recherche instantanée** — nom latin ou arabe, insensible aux accents et
  harakats, surlignage adaptatif (y compris des noms sacrés).
- 🌗 **Thème sombre** — bleu nuit moderne plutôt que noir pur.
- ℹ️ **Page développeur** — présentation de Taysir Digital Group, contacts,
  soutien (PayPal / Wave / Orange Money).

## Installation (utilisateur)

1. Télécharger le dernier APK depuis la page
   **[Releases](../../releases/latest)**.
2. Autoriser l'installation depuis une source inconnue si Android le demande
   (`Paramètres → Sécurité`).
3. Ouvrir le fichier téléchargé puis **Installer**.

## Mise en route (développeur)

Ce dépôt contient tout le code applicatif (`lib/`), les assets d'icône
(`assets/icon/`) et une configuration `android/` de référence. `gradlew` /
`gradlew.bat` / le jar du wrapper Gradle ne sont **pas commités** (générés par
Flutter) — la méthode la plus sûre pour démarrer est donc de laisser votre
script habituel créer l'ossature Android, puis d'y déposer le code de ce dépôt.

```bash
# 1. Génère un projet vierge correctement configuré (Gradle/AGP/Kotlin TDG)
~/0-apps/tdg-flutter-template/bin/tdg-flutter-create.sh durus2
cd durus2

# 2. Remplace le contenu par celui de ce dépôt, SAUF android/
#    (le script vient déjà de configurer android/ correctement)
rm -rf lib pubspec.yaml
cp -r /chemin/vers/ce/dépôt/lib .
cp /chemin/vers/ce/dépôt/pubspec.yaml .
cp -r /chemin/vers/ce/dépôt/assets .
cp /chemin/vers/ce/dépôt/MAPPING_FONCTIONNALITES.md .

# 3. Vérifie que android/app/build.gradle.kts a bien
#    namespace = "com.tdg.durus2" / applicationId = "com.tdg.durus2"
#    (déjà le cas si généré avec --org com.tdg durus2)

flutter pub get
flutter run
```

Les fichiers `android/` fournis dans ce dépôt (`settings.gradle.kts`,
`gradle.properties`, `gradle-wrapper.properties`, `app/build.gradle.kts`,
`AndroidManifest.xml`, `MainActivity.kt`, `styles.xml`,
`launch_background.xml`) reprennent la configuration de référence TDG, avec
`namespace`/`applicationId` déjà positionnés sur `com.tdg.durus2`. Ils servent
de **référence / fallback** si vous préférez repartir de `flutter create`
manuellement plutôt que du script : dans ce cas, remplacez les fichiers
générés par ceux-ci.

> 💡 Testez `flutter build apk --debug` dès la première mise en route, avant
> d'ajouter d'autres dépendances.

### Signer et publier une release

Voir la checklist complète dans [`RELEASE.md`](RELEASE.md) (génération du
keystore, `key.properties`, build signé, publication sur GitHub Releases).

## Icône de lancement

Les ressources Android générées automatiquement sont **volontairement absentes**
d'`android/app/src/main/res/` : elles doivent être régénérées localement plutôt
que commitées. Les fichiers source se trouvent dans `assets/icon/`
(`icon_legacy_1024.png`, `ic_foreground_adaptive.png`,
`ic_background_adaptive.png` — cadre bleu conservé, marge blanche externe
retirée), et `pubspec.yaml` contient déjà la configuration
`flutter_launcher_icons` correspondante. Une fois `flutter pub get` effectué :

```bash
dart run flutter_launcher_icons
```

génère tous les fichiers nécessaires dans `android/app/src/main/res/`.

## Architecture

```
lib/
 ├─ core/
 │   ├─ constants/app_constants.dart      # Toutes les constantes (GitHub, cache, DB, UI)
 │   ├─ theme/app_theme.dart
 │   └─ utils/
 │        ├─ text_utils.dart              # Normalisation, détection RTL, surlignage, noms sacrés
 │        └─ natural_sort.dart            # Tri naturel façon strnatcmp
 ├─ data/
 │   ├─ models/                           # book_config, book_entry, book_group, collection, bookmark...
 │   ├─ remote/
 │   │    └─ github_library_repository.dart   # API Git Trees + raw.githubusercontent.com
 │   ├─ local/
 │   │    ├─ app_database.dart                # sqflite : collection, collection_content, bookmark
 │   │    ├─ downloads_repository.dart         # fichiers images + config.json persisté + progression
 │   │    ├─ collections_repository.dart
 │   │    └─ bookmark_repository.dart
 │   └─ repositories/
 │        └─ library_repository.dart           # Orchestration cache réseau → config locale → défaut
 ├─ features/
 │   ├─ home/                             # main_screen (écran unique) + home_shell
 │   ├─ library/                          # sidebar, recherche, navigation par groupe/livre
 │   ├─ viewer/                           # lecteur (PageView, navigation, RTL/LTR)
 │   ├─ collections/                      # picker + réorganisation (ReorderableListView)
 │   ├─ download/                         # download_controller (téléchargement + progression)
 │   └─ info/                             # page développeur / à propos
 └─ main.dart
```

L'app suit une logique **« One Page »** : un seul écran (`MainScreen`) avec un
tiroir (bibliothèque + recherche) et une zone de lecture permanente — pas de
navigation séparée pour ouvrir un livre.

Pour la correspondance complète avec chaque fonctionnalité du site PHP
d'origine (recherche, marque-page, téléchargement, collections...), voir
**[`MAPPING_FONCTIONNALITES.md`](MAPPING_FONCTIONNALITES.md)**.

## Dépôt distant des livres

Le catalogue et les pages des livres sont lus depuis
[`github.com/taysirdigitalgroup/xassidati-datas`](https://github.com/taysirdigitalgroup/xassidati-datas)
(branche `main`), avec la même arborescence que l'ancien serveur PHP :

```
<groupe>/<livre>/config/config.json
<groupe>/<livre>/images/*.ext
```

Toutes les constantes (dépôt, branche, URLs, TTL de cache, noms de
fichiers/dossiers) sont centralisées dans
`lib/core/constants/app_constants.dart`.

## Journal des correctifs récents

- **Bug RTL/LTR corrigé à la racine** — la langue d'un livre est désormais
  **toujours** lue depuis son vrai `config.json` (champ `"lang"`), plus jamais
  devinée depuis le nom de dossier (souvent translittéré en latin même pour un
  livre arabe, ex. `"Al Quran - Juz-u 01"`). Le `config.json` d'un livre
  téléchargé est également **persisté en local**, pour rester correct même
  hors-ligne ou quand le cache du catalogue distant a expiré. Pour une
  collection, la langue du **premier** livre (selon sa position actuelle) est
  re-vérifiée à l'ouverture pour rester cohérente après une réorganisation.
- **Performance** — le catalogue complet (noms latin/arabe et langue réels) est
  chargé une seule fois avec une concurrence limitée puis mis en cache disque ;
  les listes utilisent `Selector` plutôt que `Consumer` complet pour éviter des
  reconstructions inutiles ; le rendu des pages utilise `InteractiveViewer`
  (plus léger que `photo_view`).
- **One Page** — un seul écran (`MainScreen`) avec tiroir (bibliothèque +
  recherche) et zone de lecture permanente.
- **Marque-page visible à l'ouverture** — une bannière « Continuer la lecture »
  apparaît dès le lancement si un marque-page existe.
- **Duplication/référencement illimité** — ajouter un livre déjà téléchargé à
  une (autre) collection ne re-télécharge ni ne duplique jamais les images :
  seule une référence est ajoutée en base.
- **Thème** — surlignage de recherche adaptatif (fini le jaune illisible en
  sombre), mode sombre en bleu nuit moderne plutôt que noir.
- **Page développeur** — présentation de Taysir Digital Group, contacts,
  soutien (PayPal / Wave / Orange Money), accessible via l'icône ⓘ de l'AppBar.
- **Icône de lancement** — ressources générées retirées d'`android/` ; la
  configuration `flutter_launcher_icons` reste dans `pubspec.yaml`, prête à
  être relancée (`dart run flutter_launcher_icons`).

## Pièges connus / environnement de build

- Ne pas laisser `flutter create` régénérer des fichiers Gradle plus récents
  (AGP 9.x / Kotlin 2.3.x) : toujours revenir aux versions de référence
  (**AGP 8.11.1 / Kotlin 2.2.20 / Gradle 8.14.1**), voir
  `FLUTTER_DEV_ENV_CONFIGS.md`.
- `sqflite` / `path_provider` / `http` / `shared_preferences` / `url_launcher`
  / `package_info_plus` sont des plugins stables et bien maintenus : aucun
  piège connu similaire à `ffmpeg_kit_flutter` ou `record` pour ce projet.
- Tester `flutter build apk --debug` dès la première mise en route, avant
  d'ajouter d'autres dépendances.

## Licence

Projet propriétaire — **Taysir Digital Group**. Tous droits réservés.
