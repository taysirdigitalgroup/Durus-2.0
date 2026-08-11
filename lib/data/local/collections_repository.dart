import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../models/collection.dart';
import 'app_database.dart';

/// Remplace côté local TOUTES les fonctionnalités "collection" du PHP :
///  - rqt_user_collection_list_get.php
///  - rqt_user_collection_last_update_get/set.php
///  - rqt_user_collection_book_add_sync.php
///  - rqt_user_collection_book_delete.php
///  - rqt_user_collection_books_get.php
///  - rqt_user_collection_books_positions_update.php
///  - rqt_user_downloaded_books_get.php
///
/// Il n'y a plus de synchronisation serveur : toutes les opérations sont
/// des lectures/écritures SQLite directes et immédiates.
class CollectionsRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Équivalent rqt_user_collection_list_get.php
  Future<List<BookCollection>> getAllCollections() async {
    final db = await _db;
    final rows = await db.query(AppConstants.tableCollection, orderBy: '${AppConstants.colId} DESC');
    return rows.map(BookCollection.fromMap).toList();
  }

  /// Résout le titre d'une collection par id (le titre n'est pas dupliqué
  /// dans `collection_content`, on le récupère depuis la table `collection`).
  Future<BookCollection?> getCollectionById(int id) async {
    final db = await _db;
    final rows = await db.query(AppConstants.tableCollection, where: '${AppConstants.colId} = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return BookCollection.fromMap(rows.first);
  }

  /// Crée une nouvelle collection et retourne son id.
  Future<int> createCollection(String title) async {
    final db = await _db;
    return db.insert(AppConstants.tableCollection, {
      AppConstants.colCollectionTitle: title,
      AppConstants.colUpdatedAt: DateTime.now().toIso8601String(),
    });
  }

  Future<void> renameCollection(int id, String newTitle) async {
    final db = await _db;
    await db.update(
      AppConstants.tableCollection,
      {AppConstants.colCollectionTitle: newTitle},
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCollection(int id) async {
    final db = await _db;
    await db.delete(AppConstants.tableCollection, where: '${AppConstants.colId} = ?', whereArgs: [id]);
    await db.delete(
      AppConstants.tableCollectionContent,
      where: '${AppConstants.colCollectionId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> touchCollection(int id) async {
    final db = await _db;
    await db.update(
      AppConstants.tableCollection,
      {AppConstants.colUpdatedAt: DateTime.now().toIso8601String()},
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Équivalent rqt_user_collection_book_add_sync.php (mode insertion).
  /// Calcule automatiquement la position suivante dans la collection,
  /// sauf si [position] est fourni explicitement (cas "dupliquer à une
  /// position précise", équivalent duplicatedBook = true côté JS).
  Future<CollectionBook> addBookToCollection({
    required int collectionId,
    required String collectionTitle,
    required String group,
    required String book,
    required String lang,
    String nomLatin = '',
    String arabicName = '',
    String author = '',
    String translator = '',
    String voice = '',
    String trans = '',
    String type = '',
    int? position,
  }) async {
    final db = await _db;

    int finalPosition = position ?? 1;
    if (position == null) {
      final result = await db.rawQuery(
        'SELECT MAX(${AppConstants.colPosition}) as maxPos FROM ${AppConstants.tableCollectionContent} '
        'WHERE ${AppConstants.colCollectionId} = ?',
        [collectionId],
      );
      final maxPos = result.first['maxPos'] as int?;
      finalPosition = (maxPos ?? 0) + 1;
    }

    final entry = CollectionBook(
      collectionId: collectionId,
      collectionTitle: collectionTitle,
      group: group,
      book: book,
      position: finalPosition,
      nomLatin: nomLatin,
      arabicName: arabicName,
      author: author,
      translator: translator,
      voice: voice,
      lang: lang,
      trans: trans,
      type: type,
    );

    final id = await db.insert(AppConstants.tableCollectionContent, entry.toMap());
    await _compactPositions(collectionId);
    await touchCollection(collectionId);
    return entry.copyWith(id: id);
  }

  /// Équivalent rqt_user_collection_book_delete.php. [collectionId] est
  /// désormais requis : après suppression, les positions restantes sont
  /// automatiquement recompactées (1..N sans trou), pour que la
  /// numérotation affichée reste toujours exacte après une suppression,
  /// une duplication ou une réorganisation.
  Future<void> removeBook({
    int? contentId,
    required int collectionId,
    String? group,
    String? book,
  }) async {
    final db = await _db;

    if (contentId != null) {
      await db.delete(
        AppConstants.tableCollectionContent,
        where: '${AppConstants.colId} = ?',
        whereArgs: [contentId],
      );
    } else if (group != null && book != null) {
      await db.delete(
        AppConstants.tableCollectionContent,
        where:
            '${AppConstants.colCollectionId} = ? AND ${AppConstants.colGroupName} = ? AND ${AppConstants.colBook} = ?',
        whereArgs: [collectionId, group, book],
      );
    }
    await _compactPositions(collectionId);
    await touchCollection(collectionId);
  }

  /// Réécrit les positions de tous les livres d'une collection en 1..N,
  /// dans leur ordre actuel (par position croissante), sans laisser de
  /// trou. Appelé après tout ajout/suppression/duplication pour garantir
  /// que la numérotation affichée est toujours exacte et continue.
  Future<void> _compactPositions(int collectionId) async {
    final db = await _db;
    final rows = await db.query(
      AppConstants.tableCollectionContent,
      columns: [AppConstants.colId],
      where: '${AppConstants.colCollectionId} = ?',
      whereArgs: [collectionId],
      orderBy: '${AppConstants.colPosition} ASC, ${AppConstants.colId} ASC',
    );

    await db.transaction((txn) async {
      for (var i = 0; i < rows.length; i++) {
        final id = rows[i][AppConstants.colId] as int;
        await txn.update(
          AppConstants.tableCollectionContent,
          {AppConstants.colPosition: i + 1},
          where: '${AppConstants.colId} = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Équivalent rqt_user_collection_books_get.php
  Future<List<CollectionBook>> getBooksInCollection(int collectionId) async {
    final db = await _db;
    final rows = await db.query(
      AppConstants.tableCollectionContent,
      where: '${AppConstants.colCollectionId} = ?',
      whereArgs: [collectionId],
      orderBy: '${AppConstants.colPosition} ASC',
    );
    return rows.map(CollectionBook.fromMap).toList();
  }

  /// Équivalent rqt_user_downloaded_books_get.php : tous les livres
  /// téléchargés, toutes collections confondues.
  Future<List<CollectionBook>> getAllDownloadedBooks() async {
    final db = await _db;
    final rows = await db.query(
      AppConstants.tableCollectionContent,
      orderBy: '${AppConstants.colCollectionId} ASC, ${AppConstants.colPosition} ASC',
    );
    return rows.map(CollectionBook.fromMap).toList();
  }

  bool isBookDownloaded(List<CollectionBook> downloaded, String group, String book) {
    return downloaded.any((b) => b.group == group && b.book == book);
  }

  /// Équivalent rqt_user_collection_books_positions_update.php, mais
  /// nativement adapté à ReorderableListView : on reçoit la liste déjà
  /// réordonnée et on réécrit les positions 1..N en une transaction.
  Future<void> updatePositions(int collectionId, List<CollectionBook> orderedBooks) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedBooks.length; i++) {
        final book = orderedBooks[i];
        await txn.update(
          AppConstants.tableCollectionContent,
          {AppConstants.colPosition: i + 1},
          where: '${AppConstants.colId} = ?',
          whereArgs: [book.id],
        );
      }
    });
    await touchCollection(collectionId);
  }
}
