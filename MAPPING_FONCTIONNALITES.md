# Xassidati — Cartographie PHP (PWA) → Flutter (Android)

Ce document liste **toutes** les fonctionnalités du site PHP `Xassidati` et leur
équivalent prévu côté app Flutter. Sont **volontairement exclus** : l'authentification
(login/register/mot de passe/PHPMailer) et les GIF de démo (`processing.gif`,
`showDemoBtn`, etc.), non pertinents pour une app mobile mono-utilisateur hors-ligne.

Conséquence architecturale majeure : comme il n'y a plus de compte utilisateur ni de
serveur PHP, **tout ce qui était "synchronisé avec MySQL" devient purement local**
(SQLite embarqué + fichiers sur le stockage de l'appareil). Il n'y a plus de notion
"connecté / hors-ligne" pour les données utilisateur — seule la disponibilité d'Internet
pour **récupérer le catalogue et télécharger de nouveaux livres** reste pertinente.

---

## 0. Changement de source des livres

| PHP (legacy) | Flutter (nouveau) |
|---|---|
| Livres stockés dans `assets/documents/books/<groupe>/<livre>/{config/config.json, images/*.ext}` sur le serveur du site | Même arborescence, mais hébergée sur le dépôt GitHub **`xassidati-datas`** (branche par défaut). Toutes les URLs sont construites depuis `raw.githubusercontent.com` |
| `scandir()` récursif côté PHP pour lister groupes/livres | Appel à l'API **Git Trees** de GitHub (`GET /repos/{owner}/xassidati-datas/git/trees/{branch}?recursive=1`), résultat mis en cache localement (TTL configurable) pour reconstruire la même hiérarchie côté Dart |
| Téléchargement d'image = lecture fichier local par Apache | Téléchargement d'image = `GET` sur l'URL `raw.githubusercontent.com/.../images/xx.webp`, écrite dans le stockage applicatif (`getApplicationDocumentsDirectory()/xassidati/books/<groupe>/<livre>/images/`) |

Toutes ces constantes (`owner`, `repo`, `branch`, base URL raw, URL API tree, TTL cache,
noms de fichiers/dossiers) sont centralisées dans `lib/core/constants/app_constants.dart`.

---

## 1. Catalogue des livres (liste / sidebar)

| Fonctionnalité PHP/JS | Fichier source | Équivalent Flutter |
|---|---|---|
| Lister tous les groupes + livres, avec tri "arabe d'abord" puis alphabétique naturel | `rqt_books_all_get.php` (`getBooks()`) | `GithubLibraryRepository.fetchCatalog()` — reproduit exactement la même logique de tri (regex `\p{Arabic}` équivalent Dart `RegExp(r'\p{Script=Arabic}', unicode: true)`, tri naturel `strnatcmp` via un comparateur Dart maison) |
| Lire `config.json` d'un livre (nom latin/arabe, auteur, traducteur, voix, langue, transcription, type) | `rqt_book_config_get.php` | `BookConfig.fromJson()`, chargé soit depuis le cache catalogue soit à la demande |
| Détection langue arabe (RTL) si absente du config, via regex sur le nom de dossier | `rqt_books_all_get.php` | `TextUtils.looksArabic(String)` |
| Affichage de la liste groupée, pliable/dépliable par groupe | `renderBooks()`, `.bookList-header` toggle | `ExpansionTile` (ou équivalent custom) par groupe dans `LibrarySidebar` |
| Style "livre déjà téléchargé" (surbrillance verte, bouton téléchargement/suppression) | `refreshDownloadedBookOpacity()` | `Consumer` sur `DownloadsRepository` : couleur de fond + icône dynamique par tuile |
| Mise en surbrillance du livre en cours de lecture | `active-book-highlight` | état `currentGroup/currentBook` observé par le sidebar |
| Onglets "Tous les livres" / "Livres téléchargés" | `#bookTabs` (Bootstrap tabs) | `TabBar`/`TabBarView` dans `LibrarySidebar` |

## 2. Recherche

| Fonctionnalité | Source | Flutter |
|---|---|---|
| Recherche instantanée (nom latin + nom arabe), insensible aux accents/harakat | `cherchBooks()`, `normalizeText()` | `TextUtils.normalize()` (supprime diacritiques latins + harakats arabes, ponctuation) + filtrage en mémoire sur le catalogue déjà chargé |
| Détection direction du champ de recherche (RTL si le texte tapé commence en arabe) | `adjustSearchDirection()` | `Directionality`/`textDirection` dynamique sur le `TextField` de recherche |
| Surlignage du mot recherché dans les résultats (sans casser le HTML) | `highlightSerchedWord()`, `highlightSearchedWordProperly()` | `RichText`/`TextSpan` construits par `TextUtils.buildHighlightedSpans()` |
| Surlignage des "noms sacrés" (Allah en rouge, Prophète ﷺ en bleu, Khadimou Rassoul en vert) | `highlightElementSacredNames()` | Même logique portée dans `TextUtils.sacredNameColor()`, appliquée systématiquement (recherche ou non) sur les titres |
| Annulation des recherches obsolètes (race condition) via token incrémental | `currentSearchToken` | Un simple `int _searchToken` + vérification avant `notifyListeners()` dans `LibraryController` |
| Message "Aucun résultat pour «...»" | `cherchBooks()` | Widget d'état vide dans les résultats de recherche |

## 3. Lecteur de livre (viewer)

| Fonctionnalité | Source | Flutter |
|---|---|---|
| Affichage image par image dans un carrousel | `displayImagesInCarousel()` (Bootstrap Carousel) | `PageView.builder` plein écran avec `PhotoView`/`InteractiveViewer` pour le zoom |
| **Lecture RTL/LTR selon la langue du livre** | Logique d'index inversé (`goToPage`, `bookIsArabic`) | Simplifié : la liste d'images reste **toujours en ordre naturel de page (page 1 → page N)** ; seule la propriété `reverse:` du `PageView` (ou la `Directionality` ambiante) change selon `book.isArabic`. Résultat identique pour l'utilisateur, code bien plus simple et sans arithmétique d'index dupliquée à 6 endroits comme en JS |
| Saisie d'un numéro de page pour accès direct | `#pageInput`, `goToPage()` | Champ numérique + `pageController.jumpToPage(page - 1)`, bornes validées `[1, totalPages]` |
| Boutons précédent/suivant, premier/dernière page | `prevBtn/nextBtn/firstPageBtn/lastPageBtn` (x2 jeux de boutons) | Barre de navigation `PageNavigationBar` avec 4 actions, indépendantes de la langue (voir simplification ci-dessus) |
| Navigation clavier (flèches gauche/droite) | `handleArrowNavigation()` | Non prioritaire sur mobile (pas de clavier physique en usage courant) ; peut être ajouté via `RawKeyboardListener` si un clavier Bluetooth est branché |
| Bascule portrait/paysage du visualiseur | `#toggle-orientation` | `SystemChrome.setPreferredOrientations()` + bouton dans l'AppBar du viewer |
| Désactivation des boutons de nav pendant la transition | `slide.bs.carousel` / `slid.bs.carousel` | Non nécessaire (PageView Flutter ne pose pas ce problème de double-clic) |
| Affichage nom du livre (latin + arabe) sous le lecteur, cliquable | `metaBookSection` | `BookInfoBar` sous le `PageView`, tap → bottom sheet avec auteur/traducteur/voix |
| Flèche indicative du sens de lecture | `showNavigationDirectionArrow()` | Icône chevron dans `PageNavigationBar`, orientée selon `isArabic` |
| Image par défaut si livre introuvable / hors-ligne sans téléchargement | `defaultPage` | Widget d'état "livre indisponible hors connexion" avec bouton retour |

## 4. Marque-page (bookmark)

> Dans le PHP, le marque-page est **unique et global par utilisateur** (une seule ligne
> `group/book/lang/page` dans la table `users`), pas un marque-page par livre.
> On conserve ce même comportement simple côté Flutter (un seul "reprendre la lecture").

| Fonctionnalité | Source | Flutter |
|---|---|---|
| Enregistrer la page courante comme marque-page | `rqt_marked_page_set.php`, bouton `markPageBtn` | `BookmarkRepository.setBookmark(group, book, lang, page)` → table SQLite `bookmark` (ligne unique, id fixe) |
| Lire le marque-page courant | `rqt_marked_page_get.php`, `loadBookmark()` | `BookmarkRepository.getBookmark()` |
| Bouton "Retour à la page marquée" | `showMarkedPageBtn` | Action dans `PageNavigationBar`, ouvre directement group/book/page mémorisés |
| Icône dynamique (page marquée = icône pleine) | `updateBookmarkButton()` | `ValueListenableBuilder` sur le bookmark courant comparé à la page affichée |
| Confirmation avant d'écraser un marque-page existant | popovers `#popoverContent`/`confirmYes/confirmNo` | `showDialog` de confirmation standard Material |
| Synchronisation multi-appareils (`rqt_marked_page_sync.php`) | — | **Exclu** (nécessitait un compte) ; peut être réintroduit plus tard via un export/import JSON manuel si besoin |

## 5. Téléchargement & lecture hors-ligne

| Fonctionnalité | Source | Flutter |
|---|---|---|
| Lister les images d'un livre à télécharger | `rqt_books_group_images_get.php` / `rqt_book_download.php` (quasi identiques) | `GithubLibraryRepository.listBookImages(group, book)` → chemins raw GitHub, triés naturellement |
| Télécharger et stocker les images (IndexedDB `images` store, clé = chemin) | `storeBookImagesInIndexedDB()` | `DownloadsRepository.downloadBook()` : `GET` de chaque image → écriture fichier dans `.../books/<groupe>/<livre>/images/<n>.<ext>` + barre de progression |
| Stocker les métadonnées du livre téléchargé (collection, position, config) | IndexedDB `metadata` store | Table SQLite `collection_content` (voir §6) |
| Éviter de re-télécharger une image déjà présente | `checkImageInIndexedDB()` | Vérification `File.exists()` avant chaque `GET` |
| Lecture hors-ligne : préférer le stockage local, fallback réseau si dispo | `loadImages()` (IndexedDB puis serveur) | `LibraryRepository.getBookImages()` : lit d'abord le dossier local ; si absent, télécharge à la volée en streaming pour affichage (sans forcément persister) si connexion dispo |
| Suppression d'un livre téléchargé (fichiers + métadonnées) | `deleteBookImagesFromIndexedDB()` | `DownloadsRepository.deleteBook()` : suppression récursive du dossier + lignes SQLite associées |
| Mise à jour groupée des images déjà téléchargées (nouvelle version distante) | `updateBookImagesInIndexedDb()` | `DownloadsRepository.refreshOutdatedBooks()` (comparaison optionnelle par nombre de pages / hash) |
| Bouton "dupliquer" un livre téléchargé (le réinsérer à une autre position dans une collection) | `bookDuplicateButton`, `downloadBookImages(..., duplicatedBook = true)` | Action "Dupliquer dans la collection" sur la tuile d'un livre téléchargé |
| Mode PWA / service worker / cache statique | `service-worker.js`, `manifest.json` | **Non applicable** (app native) — remplacé par le cache disque classique Android |

## 6. Collections personnalisées & organisation

| Fonctionnalité | Source | Flutter |
|---|---|---|
| Une collection par défaut "Dìwàn 1" créée automatiquement | `rqt_user_collection_last_update_get.php` | Création auto d'une collection `Dìwàn 1` (id fixe) au premier lancement |
| Lister les collections de l'utilisateur | `rqt_user_collection_list_get.php` | `CollectionsRepository.getAll()` (table SQLite `collection`) |
| Créer une nouvelle collection au moment du téléchargement (modal de choix) | `promptUserForCollection()` | `CollectionPickerDialog` (choisir une collection existante ou en créer une, dans le même flux que le téléchargement) |
| Ajouter un livre téléchargé à une collection, calcul automatique de la position | `rqt_user_collection_book_add_sync.php`, `addBookToUserCollection()` | `CollectionsRepository.addBook()` — `INSERT` SQLite avec `position = max+1` |
| Lister les livres d'une collection, triés par position | `rqt_user_collection_books_get.php` | `CollectionsRepository.getBooks(collectionId)` |
| Lister tous les livres téléchargés toutes collections confondues | `rqt_user_downloaded_books_get.php` | `CollectionsRepository.getAllDownloaded()` |
| Supprimer un livre d'une collection | `rqt_user_collection_book_delete.php` | `CollectionsRepository.removeBook()` |
| **Réorganisation par glisser-déposer** des livres dans une collection (poignées haut/milieu/bas) | `Hammer.js` + `dragHandle*`, `getDownloadedBookItemsOrder()`, `updateBookPositions()` | `ReorderableListView` natif Flutter (bien plus simple et fluide que le drag Hammer.js) dans `DownloadedBooksScreen`, avec persistance immédiate des positions en SQLite |
| Horodatage `collection_last_update` (utile à l'origine pour la sync serveur) | `updateCollectionLastUpdate()` | Conservé localement (colonne `updated_at`) à titre informatif / tri "récemment modifié", sync serveur supprimée |
| **Lecture groupée** : lire à la suite, dans un seul lecteur, tous les livres d'une collection (concaténation des pages) | `loadCollection()` | `ViewerController.openCollection(collectionId)` : concatène les listes d'images de chaque livre de la collection dans l'ordre des positions, applique RTL/LTR selon la langue du **premier** livre (identique au comportement PHP) |
| Renommer / supprimer une collection entière | *(non présent explicitement dans le PHP fourni, mais implicite via le modal de création)* | Ajout naturel côté Flutter : `CollectionsRepository.rename()/delete()` |

## 7. Fonctionnalités explicitement exclues

| Fonctionnalité PHP | Raison de l'exclusion |
|---|---|
| `rqt_auth.php` (login/register/mot de passe/activation) | Authentification hors périmètre demandé |
| Envoi d'e-mails (`xs-app-infos.php` + PHPMailer) | Lié à l'auth (bienvenue, reset mdp) |
| Sessions PHP (`$_SESSION['user']`) | Plus de notion de compte |
| Synchronisation serveur (`rqt_marked_page_sync.php`, `rqt_user_collection_*_sync/update.php` côté serveur) | Plus de backend MySQL ; tout devient local |
| `assets/images/covers/processing.gif`, `pre.png`, `pre1.png`, `pre2.png`, `#showDemoBtn` | GIFs/écrans de démonstration, non nécessaires en mobile |
| PWA (`manifest.json`, `service-worker.js`, bouton "Installer l'app") | Non pertinent, l'app est déjà installée nativement |
| `sitemap.xml` / `sitemap_get.php` / `robots.txt` | SEO web, non applicable |

---

## 8. Arborescence Flutter proposée

```
lib/
 ├─ core/
 │   ├─ constants/app_constants.dart      // TOUTES les constantes (GitHub, cache, DB, UI)
 │   ├─ theme/app_theme.dart
 │   └─ utils/
 │        ├─ text_utils.dart              // normalisation, RTL detect, surlignage, noms sacrés
 │        └─ natural_sort.dart            // tri naturel façon strnatcmp
 ├─ data/
 │   ├─ models/
 │   │    ├─ book_config.dart
 │   │    ├─ book_entry.dart
 │   │    ├─ book_group.dart
 │   │    ├─ collection.dart
 │   │    ├─ collection_book.dart
 │   │    └─ bookmark.dart
 │   ├─ remote/
 │   │    └─ github_library_repository.dart   // API Git Trees + raw.githubusercontent.com
 │   └─ local/
 │        ├─ app_database.dart                // sqflite : collection, collection_content, bookmark
 │        ├─ downloads_repository.dart         // fichiers images + progression
 │        └─ collections_repository.dart
 ├─ features/
 │   ├─ home/home_shell.dart
 │   ├─ library/
 │   │    ├─ library_controller.dart
 │   │    └─ widgets/ (sidebar, tuiles, barre de recherche)
 │   ├─ viewer/
 │   │    ├─ viewer_controller.dart
 │   │    ├─ viewer_screen.dart
 │   │    └─ widgets/page_navigation_bar.dart
 │   └─ collections/
 │        ├─ collection_picker_dialog.dart
 │        └─ downloaded_books_screen.dart      // ReorderableListView
 └─ main.dart
```

Nom de l'application : **Durus 2.0**. Package Android suivant la convention TDG : **`com.tdg.durus2`**.
Le dépôt distant des livres conserve le nom **`xassidati-datas`** (déjà créé sous
`github.com/taysirdigitalgroup/xassidati-datas`) — seul le nom de l'application
change, pas le nom du dépôt de contenu.
