/// app_constants.dart
///
/// TOUTES les constantes de l'application Xassidati sont centralisées ici :
/// dépôt distant des livres (xassidati-datas), URLs GitHub, paramètres de
/// cache, noms de fichiers/dossiers locaux, schéma de base de données,
/// et quelques réglages d'UI/lecture.
///
/// Ne JAMAIS coder en dur une URL GitHub, un nom de table SQLite ou un nom
/// de dossier ailleurs dans le code : tout doit référencer cette classe.
library;

class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // Informations générales de l'application
  // ---------------------------------------------------------------------
  static const String appName = 'Durus 2.0';
  static const String appDescription =
      'Durus 2.0 - Bibliothèque du Coran et des Livres de Cheikh Ahmadou Bamba Khadimou Rassoul';
  static const String androidPackageName = 'com.tdg.durus2';

  // ---------------------------------------------------------------------
  // Dépôt distant des livres (xassidati-datas)
  // Structure attendue dans le dépôt (identique à l'ancien serveur PHP) :
  //   <groupe>/<livre>/config/config.json
  //   <groupe>/<livre>/images/<n>.<png|jpg|jpeg|gif|webp|bmp|avif|tif|tiff>
  // ---------------------------------------------------------------------
  static const String githubOwner = 'taysirdigitalgroup';
  static const String githubRepo = 'xassidati-datas';
  static const String githubBranch = 'main';

  /// Base des URLs de contenu brut (images, config.json).
  /// Exemple final : $githubRawBaseUrl/<groupe>/<livre>/images/3.webp
  static String get githubRawBaseUrl =>
      'https://raw.githubusercontent.com/$githubOwner/$githubRepo/$githubBranch';

  /// API "Git Trees" (liste récursive de TOUS les fichiers du dépôt en un
  /// seul appel). Remplace le scandir() récursif du PHP côté serveur.
  static String get githubTreeApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/git/trees/$githubBranch?recursive=1';

  /// API de contenu pour un dossier précis (utilisée en secours si l'arbre
  /// complet est trop volumineux ou pour rafraîchir un seul livre).
  static String githubContentsApiUrl(String path) =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/contents/$path?ref=$githubBranch';

  /// Extensions d'images de pages supportées (identique à isSupportedBookImage côté PHP).
  static const List<String> supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'avif',
    'tif',
    'tiff',
  ];

  /// Nom du fichier de configuration d'un livre dans le dépôt distant.
  static const String bookConfigFileName = 'config.json';
  static const String bookConfigSubDir = 'config';
  static const String bookImagesSubDir = 'images';

  // ---------------------------------------------------------------------
  // Cache du catalogue distant (arbre GitHub)
  // ---------------------------------------------------------------------
  static const String catalogCacheFileName = 'xassidati_catalog_cache.json';
  static const Duration catalogCacheTtl = Duration(hours: 12);
  // v2 : la clé a été changée car la v1 ne mettait en cache que la liste
  // plate des chemins de fichiers (List<String>), format incompatible avec
  // le cache v2 qui contient le catalogue complet (groupes + config.json
  // réels). Garder l'ancienne clé aurait fait planter le cast au premier
  // lancement après mise à jour ("String is not a subtype of Map").
  static const String prefsCatalogCacheKey = 'xassidati_catalog_cache_json_v2';
  static const String prefsCatalogCacheTimestampKey = 'xassidati_catalog_cache_ts_v2';

  // ---------------------------------------------------------------------
  // Stockage local des livres téléchargés (lecture hors-ligne)
  // ---------------------------------------------------------------------
  static const String localBooksRootDirName = 'xassidati/books';

  /// Nom de la collection créée automatiquement au premier lancement.
  static const String defaultCollectionTitle = 'Dìwàn 1';
  static const int defaultCollectionId = 1;

  /// Mémorise la dernière collection consultée sur l'écran "Mes
  /// collections", pour la présélectionner au lieu de toujours revenir à
  /// la première de la liste.
  static const String prefsLastSelectedCollectionKey = 'durus2_last_selected_collection_id';

  // ---------------------------------------------------------------------
  // Base de données locale (SQLite via sqflite)
  // ---------------------------------------------------------------------
  static const String databaseFileName = 'xassidati.db';
  static const int databaseVersion = 3;

  static const String tableCollection = 'collection';
  static const String tableCollectionContent = 'collection_content';
  static const String tableBookmark = 'bookmark';

  // colonnes communes
  static const String colId = 'id';
  static const String colCollectionId = 'collection_id';
  static const String colCollectionTitle = 'collection_title';
  static const String colGroupName = 'group_name';
  static const String colBook = 'book';
  static const String colPosition = 'position';
  static const String colArabicName = 'arabic_name';
  static const String colNomLatin = 'nom_latin';
  static const String colAuthor = 'author';
  static const String colTranslator = 'translator';
  static const String colVoice = 'voice';
  static const String colLang = 'lang';
  static const String colTrans = 'trans';
  static const String colType = 'type';
  static const String colUpdatedAt = 'updated_at';
  static const String colPage = 'page';

  // ---------------------------------------------------------------------
  // Langues / directions de lecture
  // ---------------------------------------------------------------------
  static const String langArabic = 'ar';
  static const String langOther = 'noar';

  // ---------------------------------------------------------------------
  // Mise en évidence des noms sacrés dans les titres/recherche
  // (mêmes listes que highlightElementSacredNames() côté JS)
  // ---------------------------------------------------------------------
  static const List<String> allahVariants = [
    'الله',
    'allah',
    'allahu',
    'بالله',
    'والله',
    'تالله',
    'لله',
  ];

  static const List<String> prophetNameVariants = [
    'محمد',
    'mouhammad',
    'mouhammadun',
    'mouhammadoun',
    'mouhammadan',
    'mouhammadin',
    'muhammadu',
    'muhammadan',
    'muhammadin',
    'muhammadun',
    'mouhamad',
    'mahomet',
    'mohammed',
    'mohamed',
    'mohammad',
    'muhammad',
    'muhamad',
  ];

  static const List<String> khadimVariants = [
    'خديم',
    'khadim',
    'khadimi',
    'khadimu',
    'khadimou',
    'xadim',
    'الخديم',
  ];

  // ---------------------------------------------------------------------
  // Réglages du lecteur
  // ---------------------------------------------------------------------
  static const double viewerMinScale = 1.0;
  static const double viewerMaxScale = 5.0;
  static const int downloadConcurrentRequests = 4;

  // ---------------------------------------------------------------------
  // Concurrence pour la récupération des config.json (catalogue complet)
  // ---------------------------------------------------------------------
  static const int catalogConfigConcurrentRequests = 12;

  // ---------------------------------------------------------------------
  // Taysir Digital Group (TDG) — page "Développeur / À propos"
  // ---------------------------------------------------------------------
  static const String tdgCompanyName = 'TAYSIR DIGITAL GROUP';
  static const String tdgShortName = 'TDG';
  static const String tdgTagline = 'Vos rêves, nos défis';
  static const String tdgLogoAsset = 'assets/tdg/logo_tdg.png';

  /// Icône (transparente) affichée en petit dans l'en-tête de l'app, à
  /// côté du titre "Durus 2.0".
  static const String appIconAsset = 'assets/icon/ic_foreground_adaptive.png';

  static const String developerName = 'Aliou Mbengue';
  static const String developerTitle = 'PDG / CEO';

  static const String tdgPhoneDisplay = '+221 76 455 03 58';
  static const String tdgPhoneDial = '+221764550358';
  static const String tdgEmail = 'taysirdigitalgroup@gmail.com';
  static const String tdgWebsite = 'https://taysirdigitalgroup.github.io';

  static const String donatePaypalUrl = 'https://paypal.me/MBENGUE28';
  static const String donatePaypalLabel = 'paypal.me/MBENGUE28';

  static const String donateWaveUrl = 'https://pay.wave.com/m/M_sn_DoZfd98ruV_6/c/sn/';
  static const String donateWaveLabel = 'pay.wave.com · Taysir Digital Group';
  static const String donateWaveNumberDisplay = '+221 76 455 03 58';
  static const String donateWaveNumberDial = '+221764550358';

  static const String donateOrangeMoneyNumberDisplay = '+221 77 664 70 80';
  static const String donateOrangeMoneyNumberDial = '+221776647080';
}
