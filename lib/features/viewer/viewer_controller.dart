import 'package:flutter/foundation.dart';

import '../../data/local/bookmark_repository.dart';
import '../../data/local/collections_repository.dart';
import '../../data/models/book_config.dart';
import '../../data/models/bookmark.dart';
import '../../data/repositories/library_repository.dart';

enum ViewerLoadState { idle, loading, loaded, empty, error }

/// Association entre une plage de pages "globales" (pour la lecture
/// groupée d'une collection) et le livre auquel elles appartiennent.
/// Permet d'afficher les bonnes infos (nomLatin/nomArabe/auteur, tirées de
/// son PROPRE config.json) au fil de la lecture, et de retrouver le numéro
/// de page LOCAL au livre pour un marque-page cohérent.
class _PageOwner {
  final String group;
  final String book;
  final BookConfig config;
  final int startIndex; // index global (0-based) où commencent les pages de ce livre

  const _PageOwner({
    required this.group,
    required this.book,
    required this.config,
    required this.startIndex,
  });
}

/// Contrôle l'état du lecteur : livre simple OU lecture groupée d'une
/// collection entière (équivalents loadImages() et loadCollection() côté
/// JS), la navigation page à page (goToPage()), et le marque-page.
///
/// Simplification volontaire par rapport au JS d'origine : la liste
/// [pages] est TOUJOURS en ordre naturel de page (page 1 en premier).
/// La lecture RTL/LTR est gérée uniquement par [isArabic], consommé par
/// le ViewerScreen pour orienter le PageView (`reverse: isArabic`).
///
/// [isArabic] est déterminé :
///  - pour un livre seul : depuis SON PROPRE config.json (jamais deviné
///    depuis le nom de dossier, qui est souvent une translittération
///    latine même pour un livre en arabe) ;
///  - pour une collection : depuis le config.json du PREMIER livre (selon
///    sa position actuelle), re-vérifié fraîchement au moment de l'ouverture
///    pour éviter toute incohérence après une réorganisation.
class ViewerController extends ChangeNotifier {
  final LibraryRepository libraryRepository;
  final CollectionsRepository collectionsRepository;
  final BookmarkRepository bookmarkRepository;

  ViewerController({
    required this.libraryRepository,
    required this.collectionsRepository,
    required this.bookmarkRepository,
  });

  ViewerLoadState state = ViewerLoadState.idle;
  String? errorMessage;

  /// Message d'erreur présentable à l'utilisateur : masque les détails
  /// techniques (ex. "SocketException: Failed host lookup...",
  /// "ClientException...") derrière un message simple et compréhensible
  /// quand il s'agit visiblement d'un problème de réseau — typiquement en
  /// cliquant sur un livre non téléchargé alors qu'on est hors ligne.
  String get friendlyErrorMessage {
    final raw = errorMessage ?? '';
    final looksLikeNetworkIssue = raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Connection') ||
        raw.contains('Failed host lookup') ||
        raw.contains('TimeoutException') ||
        raw.contains('HandshakeException') ||
        raw.contains('HttpException');

    if (looksLikeNetworkIssue) {
      return "Pas de connexion Internet disponible pour ouvrir ce livre.\n"
          "Vérifiez votre connexion, ou téléchargez ce livre pour le consulter hors ligne.";
    }
    return "Une erreur est survenue lors de l'ouverture de ce livre.\nVeuillez réessayer.";
  }

  List<ViewerPage> pages = [];
  bool isArabic = false;

  /// Groupe/livre "principaux" actuellement affichés. En lecture groupée,
  /// ce sont ceux du livre courant (celui de la page affichée), voir
  /// [_pageOwners] / [currentBookConfig].
  String? currentGroup;
  String? currentBook;
  String? currentLang;

  /// Renseigné uniquement en mode "lecture groupée" d'une collection.
  int? currentCollectionId;
  String? currentCollectionTitle;

  List<_PageOwner> _pageOwners = [];

  int currentPage = 1;
  Bookmark? bookmark;

  /// Incrémenté à chaque "ouverture" effective d'un livre ou d'une
  /// collection (affichage simple ou retour à un marque-page) — mais PAS
  /// lors d'une simple navigation de page à page. Consommé par le lecteur
  /// pour déclencher, une fois, la flèche de sens de lecture clignotante.
  int openEventToken = 0;

  int get totalPages => pages.length;

  /// Config.json (nomLatin/nomArabe/auteur/...) du livre correspondant à la
  /// page actuellement affichée — toujours la source de vérité pour les
  /// infos affichées, comme demandé.
  BookConfig? get currentBookConfig {
    final owner = _ownerForPage(currentPage);
    return owner?.config;
  }

  /// Groupe/livre RÉELS de la page actuellement affichée (utile même en
  /// lecture groupée, où [currentGroup]/[currentBook] restent à `null`).
  /// Sert notamment au bouton "localiser dans la bibliothèque".
  String? get currentPageGroup => _ownerForPage(currentPage)?.group;
  String? get currentPageBook => _ownerForPage(currentPage)?.book;

  _PageOwner? _ownerForPage(int page) {
    if (_pageOwners.isEmpty) return null;
    for (var i = _pageOwners.length - 1; i >= 0; i--) {
      if (page - 1 >= _pageOwners[i].startIndex) return _pageOwners[i];
    }
    return _pageOwners.first;
  }

  /// Charge le marque-page dès le démarrage de l'app (sans ouvrir de
  /// livre), pour permettre d'afficher immédiatement le bouton "Continuer
  /// la lecture" sur l'écran d'accueil si un marque-page existe déjà.
  Future<void> loadBookmarkOnly() => _refreshBookmark();

  /// Équivalent loadImages() : charge un livre unique (local si
  /// téléchargé, sinon distant). La langue est toujours relue depuis le
  /// config.json réel du livre (jamais depuis le nom de dossier).
  Future<void> openBook(String group, String book, {int? jumpToPage}) async {
    if (group == currentGroup && book == currentBook && currentCollectionId == null) {
      if (jumpToPage != null) goToPage(jumpToPage);
      openEventToken++;
      notifyListeners();
      return; // déjà affiché
    }

    state = ViewerLoadState.loading;
    currentGroup = group;
    currentBook = book;
    currentCollectionId = null;
    currentCollectionTitle = null;
    notifyListeners();

    try {
      final config = await libraryRepository.fetchBookConfig(group, book);
      currentLang = config.lang;
      isArabic = config.isArabic;

      final loadedPages = await libraryRepository.getBookPages(group, book);
      pages = loadedPages;
      _pageOwners = [_PageOwner(group: group, book: book, config: config, startIndex: 0)];

      state = pages.isEmpty ? ViewerLoadState.empty : ViewerLoadState.loaded;
      currentPage = (jumpToPage != null && jumpToPage >= 1 && jumpToPage <= pages.length)
          ? jumpToPage
          : 1;
      if (state == ViewerLoadState.loaded) openEventToken++;
      await _refreshBookmark();
    } catch (e) {
      errorMessage = e.toString();
      state = ViewerLoadState.error;
    }
    notifyListeners();
  }

  /// Équivalent loadCollection() : concatène les pages de tous les livres
  /// d'une collection, dans l'ordre de leur position, et applique le sens
  /// de lecture du PREMIER livre (selon sa position ACTUELLE) à l'ensemble
  /// — son config.json est re-téléchargé pour être certain que la langue
  /// utilisée est la plus à jour, y compris après une réorganisation.
  ///
  /// [jumpToGroup]/[jumpToBook]/[jumpToLocalPage] permettent de restaurer
  /// un marque-page posé pendant une lecture groupée : on retrouve le
  /// livre ciblé dans la collection (même après une éventuelle
  /// réorganisation) et on calcule sa page GLOBALE actuelle à partir de sa
  /// page LOCALE mémorisée.
  Future<void> openCollection(
    int collectionId, {
    String? jumpToGroup,
    String? jumpToBook,
    int? jumpToLocalPage,
  }) async {
    state = ViewerLoadState.loading;
    currentGroup = null;
    currentBook = null;
    currentCollectionId = collectionId;
    notifyListeners();

    try {
      final books = await collectionsRepository.getBooksInCollection(collectionId);
      if (books.isEmpty) {
        pages = [];
        _pageOwners = [];
        state = ViewerLoadState.empty;
        notifyListeners();
        return;
      }

      final collection = await collectionsRepository.getCollectionById(collectionId);
      currentCollectionTitle = collection?.title ?? '';

      // Re-vérifie la langue du 1er livre (position la plus basse) depuis
      // son VRAI config.json, pour éviter toute incohérence après une
      // réorganisation de la collection.
      final firstBook = books.first;
      final firstConfig = await libraryRepository.fetchBookConfig(firstBook.group, firstBook.book);
      isArabic = firstConfig.isArabic;
      currentLang = firstConfig.lang;

      final allPages = <ViewerPage>[];
      final owners = <_PageOwner>[];

      for (final book in books) {
        final config = await libraryRepository.fetchBookConfig(book.group, book.book);
        final bookPages = await libraryRepository.getBookPages(book.group, book.book);
        owners.add(_PageOwner(
          group: book.group,
          book: book.book,
          config: config,
          startIndex: allPages.length,
        ));
        allPages.addAll(bookPages);
      }

      pages = allPages;
      _pageOwners = owners;
      state = pages.isEmpty ? ViewerLoadState.empty : ViewerLoadState.loaded;

      if (jumpToGroup != null && jumpToBook != null && jumpToLocalPage != null) {
        _PageOwner? target;
        for (final o in owners) {
          if (o.group == jumpToGroup && o.book == jumpToBook) {
            target = o;
            break;
          }
        }
        currentPage = target != null
            ? (target.startIndex + jumpToLocalPage).clamp(1, pages.isEmpty ? 1 : pages.length)
            : 1;
      } else {
        currentPage = 1;
      }

      if (state == ViewerLoadState.loaded) openEventToken++;
      await _refreshBookmark();
    } catch (e) {
      errorMessage = e.toString();
      state = ViewerLoadState.error;
    }
    notifyListeners();
  }

  /// Équivalent goToPage().
  void goToPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > totalPages) return;
    currentPage = pageNumber;
    notifyListeners();
    _refreshBookmark();
  }

  void nextPage() => goToPage(currentPage + 1);
  void previousPage() => goToPage(currentPage - 1);
  void firstPage() => goToPage(1);
  void lastPage() => goToPage(totalPages);

  /// Équivalent markPageBtn : enregistre le marque-page global, avec le
  /// numéro de page LOCAL au livre couramment affiché (pas l'index global
  /// de la collection), et l'id de la collection en cours le cas échéant
  /// — ce qui permet de restaurer exactement la même collection ET la
  /// même page lors du retour au marque-page.
  Future<void> markCurrentPage() async {
    final owner = _ownerForPage(currentPage);
    if (owner == null) return;
    final localPage = currentPage - owner.startIndex;

    await bookmarkRepository.setBookmark(
      group: owner.group,
      book: owner.book,
      lang: owner.config.lang,
      page: localPage,
      collectionId: currentCollectionId,
    );
    await _refreshBookmark();
  }

  /// Équivalent showMarkedPageBtn : revient au livre/page mémorisés — ou,
  /// si le marque-page a été posé pendant une lecture groupée, rouvre
  /// EXACTEMENT cette collection à la bonne page.
  Future<void> goToBookmark() async {
    final bm = bookmark;
    if (bm == null) return;
    if (bm.collectionId != null) {
      await openCollection(
        bm.collectionId!,
        jumpToGroup: bm.group,
        jumpToBook: bm.book,
        jumpToLocalPage: bm.page,
      );
    } else {
      await openBook(bm.group, bm.book, jumpToPage: bm.page);
    }
  }

  bool get isCurrentPageBookmarked {
    final bm = bookmark;
    final owner = _ownerForPage(currentPage);
    if (bm == null || owner == null) return false;
    final localPage = currentPage - owner.startIndex;
    return bm.matches(owner.group, owner.book, localPage, currentCollectionId);
  }

  Future<void> _refreshBookmark() async {
    bookmark = await bookmarkRepository.getBookmark();
    notifyListeners();
  }

  void reset() {
    pages = [];
    _pageOwners = [];
    currentGroup = null;
    currentBook = null;
    currentCollectionId = null;
    currentCollectionTitle = null;
    currentPage = 1;
    state = ViewerLoadState.idle;
    notifyListeners();
  }
}
