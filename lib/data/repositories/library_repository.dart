import '../../core/constants/app_constants.dart';
import '../local/downloads_repository.dart';
import '../models/book_config.dart';
import '../models/book_group.dart';
import '../remote/github_library_repository.dart';

/// Une page à afficher dans le lecteur : soit un fichier local, soit une
/// URL distante (si le livre n'a pas été téléchargé mais qu'une connexion
/// est disponible). Correspond au double chemin `getImagesFromIndexedDB()`
/// / `getImagesFromServerDB()` dans loadImages() côté JS.
class ViewerPage {
  final String? localPath;
  final String? remoteUrl;
  const ViewerPage({this.localPath, this.remoteUrl});
  bool get isLocal => localPath != null;
}

/// Point d'entrée unique pour obtenir le catalogue et les pages d'un livre,
/// en combinant la source distante (GitHub) et le stockage local
/// (téléchargements). Reproduit la logique de repli de loadImages() :
/// 1. essayer le stockage local (lecture hors-ligne) ;
/// 2. sinon, si connecté, streamer directement depuis GitHub.
class LibraryRepository {
  final GithubLibraryRepository remote;
  final DownloadsRepository downloads;

  LibraryRepository({required this.remote, required this.downloads});

  Future<List<BookGroup>> fetchCatalog({
    bool forceRefresh = false,
    void Function(int done, int total)? onProgress,
  }) =>
      remote.fetchCatalog(forceRefresh: forceRefresh, onProgress: onProgress);

  /// Résout la config d'un livre en essayant, dans l'ordre :
  ///  1. le catalogue distant déjà en cache mémoire, ou un appel réseau
  ///     frais (source de vérité prioritaire quand disponible) ;
  ///  2. si ça échoue (hors-ligne, catalogue jamais chargé cette
  ///     session...) ET que le livre est téléchargé : son config.json
  ///     PERSISTÉ localement lors du téléchargement (voir
  ///     DownloadsRepository.saveBookConfig) — c'est ce qui manquait et
  ///     causait l'affichage RTL de TOUS les livres téléchargés dès que le
  ///     catalogue n'était plus en cache ;
  ///  3. en tout dernier recours seulement (livre jamais téléchargé ET
  ///     injoignable) : un config par défaut.
  Future<BookConfig> fetchBookConfig(String group, String book) async {
    final fromRemote = await remote.fetchBookConfigOrNull(group, book);
    if (fromRemote != null) return fromRemote;

    final fromLocal = await downloads.getLocalBookConfig(group, book);
    if (fromLocal != null) return fromLocal;

    return BookConfig.empty(book);
  }

  /// Retourne les pages d'un livre, en local si téléchargé, sinon en
  /// distant (nécessite une connexion). Toujours en ordre naturel de page
  /// (page 1 -> page N) ; c'est l'UI (viewer) qui gère le sens RTL/LTR via
  /// `reverse:` sur le PageView plutôt que par un ré-ordonnancement de la
  /// liste (voir MAPPING_FONCTIONNALITES.md §3).
  Future<List<ViewerPage>> getBookPages(String group, String book) async {
    final localPaths = await downloads.getLocalImagePaths(group, book);
    if (localPaths.isNotEmpty) {
      return localPaths.map((path) => ViewerPage(localPath: path)).toList();
    }

    final remoteImages = await remote.listBookImages(group, book);
    return remoteImages.map((img) => ViewerPage(remoteUrl: img.rawUrl)).toList();
  }

  Future<bool> isBookDownloaded(String group, String book) =>
      downloads.isBookDownloaded(group, book);

  /// Détermine si un livre est en RTL (arabe), utilisé pour orienter le
  /// PageView du lecteur.
  bool isArabicLang(String lang) => lang == AppConstants.langArabic;
}
