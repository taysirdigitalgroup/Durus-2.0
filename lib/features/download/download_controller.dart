import 'package:flutter/foundation.dart';

import '../../data/local/collections_repository.dart';
import '../../data/local/downloads_repository.dart';
import '../../data/remote/github_library_repository.dart';

/// Suivi de progression exposé à l'UI pendant un ajout en cours.
class BookDownloadTask {
  final String group;
  final String book;
  double progress; // 0.0 - 1.0
  bool isDone;

  /// Vrai si le livre était déjà téléchargé : aucune image n'a été
  /// retéléchargée, seule une référence a été ajoutée à la collection.
  bool wasAlreadyDownloaded;

  BookDownloadTask({
    required this.group,
    required this.book,
    this.progress = 0,
    this.isDone = false,
    this.wasAlreadyDownloaded = false,
  });

  String get key => '$group::$book';
}

/// Orchestre l'ajout d'un livre à une collection.
///
/// Point important (demande explicite) : si le livre est DÉJÀ téléchargé
/// (ses images sont déjà sur le disque, potentiellement via une autre
/// collection), on ne retélécharge JAMAIS les images et on ne les duplique
/// jamais sur le disque. On se contente d'ajouter une nouvelle ligne de
/// référence dans `collection_content` (group/book/position), ce qui
/// permet un référencement illimité du même livre — y compris plusieurs
/// fois dans la MÊME collection à des positions différentes — sans le
/// moindre coût de stockage ou de réseau supplémentaire. L'affichage "en
/// double" lors de la lecture groupée vient simplement du fait que
/// plusieurs entrées pointent vers les mêmes fichiers image locaux.
class DownloadController extends ChangeNotifier {
  final GithubLibraryRepository remote;
  final DownloadsRepository downloads;
  final CollectionsRepository collections;

  DownloadController({
    required this.remote,
    required this.downloads,
    required this.collections,
  });

  final Map<String, BookDownloadTask> _tasks = {};
  Map<String, BookDownloadTask> get tasks => Map.unmodifiable(_tasks);

  /// Ajoute [group]/[book] à la collection [collectionId]. Télécharge les
  /// images seulement si elles ne sont pas déjà présentes localement.
  Future<void> addToCollection({
    required String group,
    required String book,
    required int collectionId,
    required String collectionTitle,
  }) async {
    final task = BookDownloadTask(group: group, book: book);
    _tasks[task.key] = task;
    notifyListeners();

    try {
      final config = await remote.fetchBookConfig(group, book);
      final alreadyLocal = await downloads.isBookDownloaded(group, book);

      if (!alreadyLocal) {
        final images = await remote.listBookImages(group, book);
        await downloads.downloadBook(
          group,
          book,
          images,
          onProgress: (progress) {
            task.progress = progress.ratio;
            notifyListeners();
          },
        );
      } else {
        task.wasAlreadyDownloaded = true;
        task.progress = 1;
        notifyListeners();
      }

      // Persiste le VRAI config.json (langue incluse) à côté des images,
      // que le livre vienne d'être téléchargé ou qu'il l'était déjà —
      // sans ça, la lecture RTL/LTR d'un livre téléchargé devient fausse
      // dès que le catalogue distant n'est plus en cache (voir
      // DownloadsRepository.saveBookConfig).
      await downloads.saveBookConfig(group, book, config);

      await collections.addBookToCollection(
        collectionId: collectionId,
        collectionTitle: collectionTitle,
        group: group,
        book: book,
        lang: config.lang,
        nomLatin: config.nomLatin,
        arabicName: config.nomArabe,
        author: config.auteur,
        translator: config.traducteur,
        voice: config.voix,
        trans: config.trans,
        type: config.type,
      );

      task.isDone = true;
    } finally {
      _tasks.remove(task.key);
      notifyListeners();
    }
  }

  /// Supprime DÉFINITIVEMENT un livre téléchargé : fichiers locaux + TOUTES
  /// ses entrées de collection (y compris ses éventuelles duplications
  /// dans une ou plusieurs collections). Utilisé depuis la bibliothèque
  /// principale ("supprimer" = suppression complète, pas juste un retrait
  /// d'une collection précise — pour ça, voir CollectionsRepository.removeBook
  /// utilisé directement depuis l'écran des collections).
  Future<void> deleteBookEverywhere({required String group, required String book}) async {
    await downloads.deleteBookFiles(group, book);

    final all = await collections.getAllDownloadedBooks();
    for (final entry in all.where((e) => e.group == group && e.book == book)) {
      await collections.removeBook(contentId: entry.id, collectionId: entry.collectionId);
    }
    notifyListeners();
  }
}
