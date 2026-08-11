import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../models/bookmark.dart';
import 'app_database.dart';

/// Remplace rqt_marked_page_get.php / rqt_marked_page_set.php.
/// Un seul marque-page global (ligne unique id=1), comme dans le PHP
/// d'origine où le marque-page était stocké sur la ligne `users` de
/// l'utilisateur connecté (pas de marque-page par livre).
class BookmarkRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// Équivalent rqt_marked_page_get.php
  Future<Bookmark?> getBookmark() async {
    final db = await _db;
    final rows = await db.query(AppConstants.tableBookmark, where: '${AppConstants.colId} = 1');
    if (rows.isEmpty) return null;
    return Bookmark.fromMap(rows.first);
  }

  /// Équivalent rqt_marked_page_set.php. [collectionId] est renseigné si
  /// le marque-page est posé pendant une lecture groupée (voir Bookmark).
  Future<void> setBookmark({
    required String group,
    required String book,
    required String lang,
    required int page,
    int? collectionId,
  }) async {
    final db = await _db;
    await db.insert(
      AppConstants.tableBookmark,
      {
        AppConstants.colId: 1,
        AppConstants.colGroupName: group,
        AppConstants.colBook: book,
        AppConstants.colLang: lang,
        AppConstants.colPage: page,
        AppConstants.colCollectionId: collectionId,
        AppConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearBookmark() async {
    final db = await _db;
    await db.delete(AppConstants.tableBookmark, where: '${AppConstants.colId} = 1');
  }
}
