import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/text_utils.dart';
import '../../data/local/collections_repository.dart';
import '../../data/models/book_entry.dart';
import '../../data/models/book_group.dart';
import '../../data/models/collection.dart';
import '../../data/repositories/library_repository.dart';

/// Résultat de recherche : le livre trouvé + le groupe auquel il appartient
/// (repris de processGroupBooks() / cherchBooks()).
class BookSearchResult {
  final BookEntry book;
  final String group;
  const BookSearchResult(this.book, this.group);
}

enum LibraryLoadState { idle, loading, loaded, error }

/// Équivalent du chargement initial (loadBooksFromServer) + de la recherche
/// (cherchBooks/processGroupBooks) + du suivi des livres téléchargés
/// (refreshDownloadedBookOpacity), côté Flutter.
class LibraryController extends ChangeNotifier {
  final LibraryRepository libraryRepository;
  final CollectionsRepository collectionsRepository;

  LibraryController({
    required this.libraryRepository,
    required this.collectionsRepository,
  });

  LibraryLoadState state = LibraryLoadState.idle;
  String? errorMessage;

  /// Message d'erreur présentable à l'utilisateur : masque les détails
  /// techniques (ex. "ClientException: Connection closed before full
  /// header was received, url=https://api.github.com/...") derrière un
  /// message clair quand il s'agit visiblement d'un problème de réseau,
  /// et rappelle que les livres déjà téléchargés restent disponibles.
  String get friendlyErrorMessage {
    final raw = errorMessage ?? '';
    final looksLikeNetworkIssue = raw.contains('ClientException') ||
        raw.contains('SocketException') ||
        raw.contains('Connection') ||
        raw.contains('Failed host lookup') ||
        raw.contains('TimeoutException') ||
        raw.contains('HandshakeException');

    if (looksLikeNetworkIssue) {
      return "Pas de connexion Internet disponible pour charger le catalogue complet.\n"
          "Vos livres déjà téléchargés restent accessibles dans l'onglet « Téléchargés ».";
    }
    return 'Une erreur est survenue lors du chargement du catalogue.\nVeuillez réessayer.';
  }

  List<BookGroup> groups = [];
  List<CollectionBook> downloadedBooks = [];

  /// Index rapide (O(1)) "<group>::<book>" -> téléchargé, pour éviter un
  /// scan linéaire de downloadedBooks à chaque tuile de la liste (c'était
  /// une des causes de lenteur perçue avec un catalogue de plusieurs
  /// centaines de livres).
  Set<String> _downloadedKeys = {};

  /// Progression du tout premier chargement (récupération de tous les
  /// config.json distants) : ex. "128/240 livres chargés...".
  int loadProgressDone = 0;
  int loadProgressTotal = 0;

  String searchQuery = '';
  List<BookSearchResult> searchResults = [];

  int _searchToken = 0;

  Timer? _autoRefreshTimer;

  /// Livre actuellement affiché dans le lecteur (pour la surbrillance
  /// "active-book-highlight" dans le sidebar).
  String? currentGroup;
  String? currentBook;

  Future<void> loadInitial() async {
    state = LibraryLoadState.loading;
    loadProgressDone = 0;
    loadProgressTotal = 0;
    notifyListeners();

    // Charge D'ABORD les livres déjà téléchargés (entièrement local) :
    // ainsi l'onglet "Téléchargés" reste utilisable même si la tentative
    // de récupération du catalogue distant échoue juste après (hors-ligne).
    await refreshDownloadedBooks();

    try {
      groups = await libraryRepository.fetchCatalog(
        onProgress: (done, total) {
          loadProgressDone = done;
          loadProgressTotal = total;
          notifyListeners();
        },
      );
      state = LibraryLoadState.loaded;
    } catch (e) {
      errorMessage = e.toString();
      state = LibraryLoadState.error;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await refreshDownloadedBooks();
    try {
      groups = await libraryRepository.fetchCatalog(forceRefresh: true);
      state = LibraryLoadState.loaded;
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
      state = LibraryLoadState.error;
    }
    notifyListeners();
  }

  /// Démarre une actualisation périodique et silencieuse du catalogue (et
  /// des livres téléchargés) en arrière-plan, pour que les groupes/livres
  /// fraîchement ajoutés au dépôt distant finissent par apparaître même
  /// sans action explicite de l'utilisateur (le cache disque a une TTL de
  /// plusieurs heures). L'intervalle peut être assez éloigné : ce n'est
  /// qu'un filet de sécurité en complément du "tiré vers le bas" manuel.
  void startAutoRefresh({Duration interval = const Duration(minutes: 15)}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) => refreshSilently());
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Comme [refresh], mais sans jamais repasser par l'état "loading" (donc
  /// sans faire clignoter l'UI) : si la requête échoue (hors-ligne...), on
  /// conserve silencieusement le catalogue déjà affiché. Utilisable aussi
  /// bien par le minuteur d'actualisation automatique que par un retour au
  /// premier plan de l'app.
  Future<void> refreshSilently() async {
    try {
      final freshGroups = await libraryRepository.fetchCatalog(forceRefresh: true);
      groups = freshGroups;
      state = LibraryLoadState.loaded;
      errorMessage = null;
    } catch (_) {
      // Échec silencieux : on garde le catalogue déjà chargé.
    }
    await refreshDownloadedBooks();
    notifyListeners();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Équivalent refreshDownloadedBookOpacity() : recharge la liste des
  /// livres téléchargés pour mettre à jour l'état visuel du sidebar.
  Future<void> refreshDownloadedBooks() async {
    downloadedBooks = await collectionsRepository.getAllDownloadedBooks();
    _downloadedKeys = downloadedBooks.map((b) => '${b.group}::${b.book}').toSet();
    notifyListeners();
  }

  bool isDownloaded(String group, String book) => _downloadedKeys.contains('$group::$book');

  void setCurrentBook(String? group, String? book) {
    currentGroup = group;
    currentBook = book;
    notifyListeners();
  }

  /// Équivalent cherchBooks() + processGroupBooks(), avec le même principe
  /// de "token" pour ignorer les résultats d'une recherche obsolète.
  /// Recherche à la fois sur le nom latin ET le nom arabe (config.json).
  Future<void> search(String query) async {
    final token = ++_searchToken;
    searchQuery = query;

    if (query.trim().isEmpty) {
      searchResults = [];
      notifyListeners();
      return;
    }

    final normalizedQuery = TextUtils.normalize(query);
    final results = <BookSearchResult>[];

    for (final group in groups) {
      for (final book in group.books) {
        final nameMatch = TextUtils.normalize(book.displayName).contains(normalizedQuery);
        final arabicMatch = TextUtils.normalize(book.config.nomArabe).contains(normalizedQuery);
        if (nameMatch || arabicMatch) {
          results.add(BookSearchResult(book, group.name));
        }
      }
    }

    if (token != _searchToken) return; // recherche dépassée, on ignore le résultat
    searchResults = results;
    notifyListeners();
  }

  void clearSearch() {
    _searchToken++;
    searchQuery = '';
    searchResults = [];
    notifyListeners();
  }
}
