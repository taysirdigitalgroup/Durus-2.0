import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/natural_sort.dart';
import '../models/book_config.dart';
import '../models/book_entry.dart';
import '../models/book_group.dart';

/// Un fichier "image de page" repéré dans l'arbre GitHub, avec son chemin
/// complet (utilisé pour construire l'URL raw et pour le tri naturel).
class RemoteBookImage {
  final String group;
  final String book;
  final String fileName;
  final String fullPath;

  const RemoteBookImage({
    required this.group,
    required this.book,
    required this.fileName,
    required this.fullPath,
  });

  String get rawUrl => '${AppConstants.githubRawBaseUrl}/${Uri.encodeFull(fullPath)}';
}

/// Reproduit côté Dart la logique serveur de :
///  - rqt_books_all_get.php (catalogue complet, tri arabe d'abord)
///  - rqt_book_config_get.php (config.json d'un livre)
///  - rqt_books_group_images_get.php / rqt_book_download.php (images d'un livre)
///
/// IMPORTANT : contrairement à une première version qui devinait la langue
/// RTL/LTR à partir du NOM DU DOSSIER (souvent translittéré en latin, donc
/// peu fiable — ex. "Al Quran - Juz-u 01" pour un livre en arabe), cette
/// version charge le VRAI config.json de chaque livre pour connaître son
/// vrai nomLatin / nomArabe / auteur / lang. C'est plus coûteux (autant de
/// requêtes que de livres) donc on le fait une seule fois avec une
/// concurrence limitée, puis on met en cache le résultat complet (pas
/// seulement l'arbre de fichiers) pour que les ouvertures suivantes de
/// l'app soient instantanées.
class GithubLibraryRepository {
  final http.Client _client;

  GithubLibraryRepository({http.Client? client}) : _client = client ?? http.Client();

  List<BookGroup>? _cachedCatalog;
  Map<String, List<RemoteBookImage>>? _imagesByBook; // clé = "<group>/<book>"

  /// Récupère le catalogue (groupes + livres, avec leur vrai config.json),
  /// en utilisant le cache disque tant que la TTL n'est pas dépassée, sauf
  /// si [forceRefresh] est vrai. [onProgress] permet d'afficher une
  /// progression ("32/210 livres...") lors du tout premier chargement.
  Future<List<BookGroup>> fetchCatalog({
    bool forceRefresh = false,
    void Function(int done, int total)? onProgress,
  }) async {
    if (_cachedCatalog != null && !forceRefresh) {
      return _cachedCatalog!;
    }

    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedJson = prefs.getString(AppConstants.prefsCatalogCacheKey);
      final cachedTs = prefs.getInt(AppConstants.prefsCatalogCacheTimestampKey);
      if (cachedJson != null && cachedTs != null) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedTs;
        if (age < AppConstants.catalogCacheTtl.inMilliseconds) {
          try {
            final groups = _deserializeCatalog(cachedJson);
            _imagesByBook ??= {};
            _cachedCatalog = groups;
            return groups;
          } catch (_) {
            // Cache corrompu ou d'un format incompatible (ex. ancienne
            // version de l'app) : on l'ignore silencieusement et on
            // effectue un chargement complet frais ci-dessous plutôt que
            // de faire planter le chargement du catalogue.
            await prefs.remove(AppConstants.prefsCatalogCacheKey);
            await prefs.remove(AppConstants.prefsCatalogCacheTimestampKey);
          }
        }
      }
    }

    final paths = await _fetchRepoTreePaths();
    final skeleton = _buildSkeletonFromTreePaths(paths);
    final groups = await _hydrateWithRealConfigs(skeleton, onProgress: onProgress);

    await prefs.setString(AppConstants.prefsCatalogCacheKey, _serializeCatalog(groups));
    await prefs.setInt(
      AppConstants.prefsCatalogCacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    _cachedCatalog = groups;
    return groups;
  }

  /// Actualisation incrémentale du catalogue (utilisée par le filet de
  /// sécurité périodique ET par le "tiré vers le bas" manuel) :
  ///  - si le cache est encore valide (< TTL) et [force] est faux, ne fait
  ///    STRICTEMENT AUCUN appel réseau et renvoie le catalogue déjà connu ;
  ///  - sinon, récupère juste l'arbre du dépôt (UN SEUL appel) et le
  ///    compare au catalogue déjà connu : les livres déjà présents
  ///    GARDENT leur config déjà chargée (aucune requête config.json
  ///    relancée pour eux), seuls les groupes/livres VRAIMENT nouveaux
  ///    voient leur config.json récupérée, et les groupes/livres qui ont
  ///    disparu du dépôt distant sont retirés silencieusement.
  ///
  /// Contrairement à [fetchCatalog]`(forceRefresh: true)` (qui rejoue
  /// l'hydratation complète, donc re-télécharge TOUS les config.json), ça
  /// ne "vide" jamais le catalogue déjà affiché : c'est une fusion, pas un
  /// remplacement.
  Future<List<BookGroup>> syncCatalog({
    bool force = false,
    void Function(int done, int total)? onNewBooksProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Base de comparaison : catalogue déjà en mémoire, sinon celui persisté
    // sur disque (même expiré — ça reste une bien meilleure base qu'un
    // catalogue vide, qui obligerait à tout re-télécharger).
    Map<String, Map<String, BookEntry>>? baseline;
    if (_cachedCatalog != null) {
      baseline = _asBaselineMap(_cachedCatalog!);
    } else {
      final cachedJson = prefs.getString(AppConstants.prefsCatalogCacheKey);
      if (cachedJson != null) {
        try {
          baseline = _asBaselineMap(_deserializeCatalog(cachedJson));
        } catch (_) {
          // Cache corrompu : on traitera ça comme un tout premier
          // chargement ci-dessous.
        }
      }
    }

    // Aucune base connue (tout premier lancement, ou cache corrompu) :
    // impossible de "diffuser" quoi que ce soit, on fait le chargement
    // initial complet habituel.
    if (baseline == null) {
      return fetchCatalog(forceRefresh: false);
    }

    if (!force) {
      final cachedTs = prefs.getInt(AppConstants.prefsCatalogCacheTimestampKey);
      final age = cachedTs == null
          ? null
          : DateTime.now().millisecondsSinceEpoch - cachedTs;
      if (age != null && age < AppConstants.catalogCacheTtl.inMilliseconds) {
        // Cache encore frais : rien à faire, aucun appel réseau.
        _cachedCatalog ??= _baselineToGroupList(baseline);
        return _cachedCatalog!;
      }
    }

    final paths = await _fetchRepoTreePaths();
    final skeleton = _buildSkeletonFromTreePaths(paths);

    _imagesByBook = {};
    final allEntries = <MapEntry<String, MapEntry<String, _RawBookData>>>[];
    skeleton.forEach((groupName, books) {
      books.forEach((bookFolder, data) {
        allEntries.add(MapEntry(groupName, MapEntry(bookFolder, data)));
      });
    });

    // Sépare les entrées déjà connues (réutilisées telles quelles, sans la
    // moindre requête réseau) des entrées vraiment nouvelles (config.json
    // à récupérer). Ce qui reste dans [baseline] à la fin de cette boucle,
    // ce sont précisément les groupes/livres qui ont disparu du dépôt
    // distant — on les laisse simplement de côté (suppression implicite).
    final results = <String, Map<String, BookEntry>>{};
    final newEntries = <MapEntry<String, MapEntry<String, _RawBookData>>>[];

    for (final entry in allEntries) {
      final groupName = entry.key;
      final bookFolder = entry.value.key;
      final data = entry.value.value;
      final key = '$groupName/$bookFolder';

      data.imagePaths.sortNaturalBy((p) => p.split('/').last);
      _imagesByBook![key] = data.imagePaths
          .map((p) => RemoteBookImage(
                group: groupName,
                book: bookFolder,
                fileName: p.split('/').last,
                fullPath: p,
              ))
          .toList();

      final existing = baseline[groupName]?[bookFolder];
      if (existing != null) {
        results.putIfAbsent(groupName, () => {});
        results[groupName]![bookFolder] = existing;
      } else {
        newEntries.add(entry);
      }
    }

    final total = newEntries.length;
    var done = 0;
    const batchSize = AppConstants.catalogConfigConcurrentRequests;
    for (var i = 0; i < newEntries.length; i += batchSize) {
      final batch = newEntries.skip(i).take(batchSize);
      await Future.wait(batch.map((entry) async {
        final groupName = entry.key;
        final bookFolder = entry.value.key;

        final config = await _fetchConfigJson(groupName, bookFolder, fallback: bookFolder);
        results.putIfAbsent(groupName, () => {});
        results[groupName]![bookFolder] = BookEntry(folder: bookFolder, group: groupName, config: config);

        done++;
        onNewBooksProgress?.call(done, total);
      }));
    }

    final groups = _sortedGroupList(results);

    await prefs.setString(AppConstants.prefsCatalogCacheKey, _serializeCatalog(groups));
    await prefs.setInt(
      AppConstants.prefsCatalogCacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    _cachedCatalog = groups;
    return groups;
  }

  Map<String, Map<String, BookEntry>> _asBaselineMap(List<BookGroup> groups) {
    final map = <String, Map<String, BookEntry>>{};
    for (final g in groups) {
      map[g.name] = {for (final b in g.books) b.folder: b};
    }
    return map;
  }

  List<BookGroup> _baselineToGroupList(Map<String, Map<String, BookEntry>> baseline) =>
      _sortedGroupList(baseline);

  /// Trie groupes et livres de la même façon que l'hydratation complète
  /// (arabe d'abord, puis ordre naturel) — factorisé pour être partagé
  /// entre [_hydrateWithRealConfigs] et [syncCatalog].
  List<BookGroup> _sortedGroupList(Map<String, Map<String, BookEntry>> results) {
    final groupList = <BookGroup>[];
    results.forEach((groupName, books) {
      final entries = books.values.toList();
      entries.sort((a, b) {
        if (a.isArabic && !b.isArabic) return -1;
        if (!a.isArabic && b.isArabic) return 1;
        return naturalCompare(a.displayName, b.displayName);
      });
      groupList.add(BookGroup(name: groupName, books: entries));
    });

    groupList.sort((a, b) {
      final aArabic = a.books.any((e) => e.isArabic);
      final bArabic = b.books.any((e) => e.isArabic);
      if (aArabic && !bArabic) return -1;
      if (!aArabic && bArabic) return 1;
      return naturalCompare(a.name, b.name);
    });

    return groupList;
  }

  /// Appelle l'API Git Trees (recursive=1) et retourne la liste de tous les
  /// chemins de fichiers "blob" du dépôt.
  Future<List<String>> _fetchRepoTreePaths() async {
    final uri = Uri.parse(AppConstants.githubTreeApiUrl);
    final response = await _client.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
    });

    if (response.statusCode != 200) {
      throw GithubLibraryException(
        'Impossible de récupérer le catalogue distant (HTTP ${response.statusCode}).',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final tree = (data['tree'] as List<dynamic>).cast<Map<String, dynamic>>();
    return tree
        .where((e) => e['type'] == 'blob')
        .map((e) => e['path'] as String)
        .toList(growable: false);
  }

  /// Reconstruit la hiérarchie groupe -> livres -> images à partir d'une
  /// liste plate de chemins de fichiers (sans encore charger config.json).
  Map<String, Map<String, _RawBookData>> _buildSkeletonFromTreePaths(List<String> paths) {
    final structure = <String, Map<String, _RawBookData>>{};

    for (final path in paths) {
      final segments = path.split('/');
      if (segments.length < 4) continue; // group/book/(config|images)/file

      final group = segments[0];
      final book = segments[1];
      final subDir = segments[2];
      final fileName = segments.sublist(3).join('/');

      final groupMap = structure.putIfAbsent(group, () => {});
      final bookData = groupMap.putIfAbsent(book, () => _RawBookData());

      if (subDir == AppConstants.bookConfigSubDir && fileName == AppConstants.bookConfigFileName) {
        bookData.configPath = path;
      } else if (subDir == AppConstants.bookImagesSubDir && _isSupportedImage(fileName)) {
        bookData.imagePaths.add(path);
      }
    }

    return structure;
  }

  /// Charge le VRAI config.json de chaque livre, avec une concurrence
  /// limitée (AppConstants.catalogConfigConcurrentRequests à la fois) pour
  /// ne pas saturer le réseau ni l'API GitHub.
  Future<List<BookGroup>> _hydrateWithRealConfigs(
    Map<String, Map<String, _RawBookData>> structure, {
    void Function(int done, int total)? onProgress,
  }) async {
    _imagesByBook = {};

    final allEntries = <MapEntry<String, MapEntry<String, _RawBookData>>>[];
    structure.forEach((groupName, books) {
      books.forEach((bookFolder, data) {
        allEntries.add(MapEntry(groupName, MapEntry(bookFolder, data)));
      });
    });

    final total = allEntries.length;
    var done = 0;
    final results = <String, Map<String, BookEntry>>{}; // group -> book -> entry

    const batchSize = AppConstants.catalogConfigConcurrentRequests;
    for (var i = 0; i < allEntries.length; i += batchSize) {
      final batch = allEntries.skip(i).take(batchSize);
      await Future.wait(batch.map((entry) async {
        final groupName = entry.key;
        final bookFolder = entry.value.key;
        final data = entry.value.value;
        final key = '$groupName/$bookFolder';

        data.imagePaths.sortNaturalBy((p) => p.split('/').last);
        _imagesByBook![key] = data.imagePaths
            .map((p) => RemoteBookImage(
                  group: groupName,
                  book: bookFolder,
                  fileName: p.split('/').last,
                  fullPath: p,
                ))
            .toList();

        final config = await _fetchConfigJson(groupName, bookFolder, fallback: bookFolder);

        results.putIfAbsent(groupName, () => {});
        results[groupName]![bookFolder] = BookEntry(folder: bookFolder, group: groupName, config: config);

        done++;
        onProgress?.call(done, total);
      }));
    }

    return _sortedGroupList(results);
  }

  /// Tente de récupérer et parser le config.json distant d'un livre.
  /// Retourne `null` (plutôt qu'un config par défaut) en cas d'échec
  /// réseau ou de réponse non-200, pour que l'appelant puisse choisir
  /// lui-même la source de repli (config local persisté pour un livre
  /// téléchargé, ou config par défaut en dernier recours) au lieu de se
  /// voir imposer silencieusement "ar"/RTL.
  Future<BookConfig?> _fetchConfigJsonOrNull(String group, String book, {required String fallback}) async {
    final url = '${AppConstants.githubRawBaseUrl}/${Uri.encodeFull(group)}/${Uri.encodeFull(book)}/'
        '${AppConstants.bookConfigSubDir}/${AppConstants.bookConfigFileName}';
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return BookConfig.fromJson(json, fallbackName: fallback);
      }
    } catch (_) {
      // Réseau indisponible pour ce livre précis : on laisse l'appelant
      // décider du repli (config local persisté, puis défaut en dernier
      // recours — voir LibraryRepository.fetchBookConfig).
    }
    return null;
  }

  /// Variante permissive utilisée par l'hydratation du catalogue complet :
  /// un config par défaut ("ar", nom de dossier) plutôt qu'un échec, pour
  /// ne jamais faire planter le chargement de TOUT le catalogue à cause
  /// d'un seul livre injoignable. Ce cas reste rare (un livre qui n'a
  /// jamais pu être atteint, jamais téléchargé) — à ne pas confondre avec
  /// le cas "livre déjà téléchargé, lu hors-ligne", géré séparément par
  /// [LibraryRepository.fetchBookConfig] avec le config local persisté.
  Future<BookConfig> _fetchConfigJson(String group, String book, {required String fallback}) async {
    return await _fetchConfigJsonOrNull(group, book, fallback: fallback) ?? BookConfig.empty(fallback);
  }

  bool _isSupportedImage(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return false;
    final ext = fileName.substring(dot + 1).toLowerCase();
    return AppConstants.supportedImageExtensions.contains(ext);
  }

  /// Équivalent rqt_book_config_get.php : renvoie la config déjà chargée en
  /// mémoire (catalogue) pour ce livre, en la RE-VÉRIFIANT depuis la source
  /// si elle n'y est pas encore (garantit une donnée toujours à jour avant
  /// une lecture, comme demandé pour éviter les incohérences RTL/LTR après
  /// réorganisation d'une collection).
  Future<BookConfig> fetchBookConfig(String group, String book, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cachedCatalog;
      if (cached != null) {
        for (final g in cached) {
          if (g.name != group) continue;
          for (final b in g.books) {
            if (b.folder == book) return b.config;
          }
        }
      }
    }
    return _fetchConfigJson(group, book, fallback: book);
  }

  /// Variante de [fetchBookConfig] qui retourne `null` (au lieu d'un
  /// config par défaut "ar") si la config n'a pas pu être obtenue, ni
  /// depuis le cache mémoire du catalogue ni depuis le réseau — pour
  /// permettre à [LibraryRepository.fetchBookConfig] d'essayer ensuite un
  /// config local persisté avant de se rabattre sur un défaut.
  Future<BookConfig?> fetchBookConfigOrNull(String group, String book, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cachedCatalog;
      if (cached != null) {
        for (final g in cached) {
          if (g.name != group) continue;
          for (final b in g.books) {
            if (b.folder == book) return b.config;
          }
        }
      }
    }
    return _fetchConfigJsonOrNull(group, book, fallback: book);
  }

  /// Équivalent rqt_books_group_images_get.php / rqt_book_download.php :
  /// liste les images (triées naturellement) d'un livre donné. Si l'index
  /// mémoire est vide (ex. juste après un redémarrage avec catalogue
  /// chargé depuis le cache disque), on refait un appel ciblé à l'arbre
  /// GitHub pour CE livre uniquement via l'API Contents (plus léger qu'un
  /// nouvel appel Git Trees complet).
  Future<List<RemoteBookImage>> listBookImages(String group, String book) async {
    final key = '$group/$book';
    if (_imagesByBook != null && _imagesByBook!.containsKey(key)) {
      return _imagesByBook![key]!;
    }

    final url = AppConstants.githubContentsApiUrl(
      '${Uri.encodeComponent(group)}/${Uri.encodeComponent(book)}/${AppConstants.bookImagesSubDir}',
    );
    try {
      final response = await _client.get(Uri.parse(url), headers: {
        'Accept': 'application/vnd.github+json',
      });
      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        final images = list
            .cast<Map<String, dynamic>>()
            .where((e) => e['type'] == 'file' && _isSupportedImage(e['name'] as String))
            .map((e) => RemoteBookImage(
                  group: group,
                  book: book,
                  fileName: e['name'] as String,
                  fullPath: e['path'] as String,
                ))
            .toList();
        images.sortNaturalBy((img) => img.fileName);
        _imagesByBook ??= {};
        _imagesByBook![key] = images;
        return images;
      }
    } catch (_) {
      // ignoré, on retombe sur liste vide ci-dessous
    }
    return const [];
  }

  String _serializeCatalog(List<BookGroup> groups) {
    return jsonEncode(groups
        .map((g) => {
              'name': g.name,
              'books': g.books
                  .map((b) => {
                        'folder': b.folder,
                        'config': b.config.toJson(),
                      })
                  .toList(),
            })
        .toList());
  }

  List<BookGroup> _deserializeCatalog(String jsonStr) {
    final data = jsonDecode(jsonStr) as List<dynamic>;
    return data.map((g) {
      final map = g as Map<String, dynamic>;
      final groupName = map['name'] as String;
      final books = (map['books'] as List<dynamic>).map((b) {
        final bookMap = b as Map<String, dynamic>;
        final folder = bookMap['folder'] as String;
        final config = BookConfig.fromJson(
          bookMap['config'] as Map<String, dynamic>,
          fallbackName: folder,
        );
        return BookEntry(folder: folder, group: groupName, config: config);
      }).toList();
      return BookGroup(name: groupName, books: books);
    }).toList();
  }

  void dispose() => _client.close();
}

class _RawBookData {
  String? configPath;
  final List<String> imagePaths = [];
}

class GithubLibraryException implements Exception {
  final String message;
  GithubLibraryException(this.message);
  @override
  String toString() => message;
}
