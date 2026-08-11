import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// Gère l'ouverture et la création du schéma SQLite local.
/// Remplace les tables MySQL `collection`, `content` et les colonnes
/// marque-page de la table `users` côté PHP.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseFileName);

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2 : ajout de nom_latin sur collection_content, nécessaire pour
      // pouvoir reconstruire l'affichage "Téléchargés" ENTIÈREMENT hors
      // ligne (sans dépendre du catalogue distant pour retrouver le nom
      // latin d'un livre déjà téléchargé).
      await db.execute(
        'ALTER TABLE ${AppConstants.tableCollectionContent} ADD COLUMN ${AppConstants.colNomLatin} TEXT',
      );
    }
    if (oldVersion < 3) {
      // v3 : le marque-page peut désormais pointer vers une COLLECTION
      // (lecture groupée) plutôt qu'un livre seul — on mémorise alors
      // l'id de la collection en plus du groupe/livre/page (qui restent
      // la référence LOCALE au livre marqué au sein de cette collection).
      await db.execute(
        'ALTER TABLE ${AppConstants.tableBookmark} ADD COLUMN ${AppConstants.colCollectionId} INTEGER',
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableCollection} (
        ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppConstants.colCollectionTitle} TEXT NOT NULL,
        ${AppConstants.colUpdatedAt} TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableCollectionContent} (
        ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppConstants.colCollectionId} INTEGER NOT NULL,
        ${AppConstants.colGroupName} TEXT NOT NULL,
        ${AppConstants.colBook} TEXT NOT NULL,
        ${AppConstants.colPosition} INTEGER NOT NULL,
        ${AppConstants.colArabicName} TEXT,
        ${AppConstants.colNomLatin} TEXT,
        ${AppConstants.colAuthor} TEXT,
        ${AppConstants.colTranslator} TEXT,
        ${AppConstants.colVoice} TEXT,
        ${AppConstants.colLang} TEXT NOT NULL,
        ${AppConstants.colTrans} TEXT,
        ${AppConstants.colType} TEXT,
        FOREIGN KEY (${AppConstants.colCollectionId})
          REFERENCES ${AppConstants.tableCollection} (${AppConstants.colId})
          ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableBookmark} (
        ${AppConstants.colId} INTEGER PRIMARY KEY CHECK (${AppConstants.colId} = 1),
        ${AppConstants.colGroupName} TEXT NOT NULL,
        ${AppConstants.colBook} TEXT NOT NULL,
        ${AppConstants.colLang} TEXT NOT NULL,
        ${AppConstants.colPage} INTEGER NOT NULL,
        ${AppConstants.colCollectionId} INTEGER,
        ${AppConstants.colUpdatedAt} TEXT
      );
    ''');

    // Collection par défaut "Dìwàn 1", créée dès l'installation
    // (équivalent de la création auto-collection côté PHP).
    await db.insert(AppConstants.tableCollection, {
      AppConstants.colId: AppConstants.defaultCollectionId,
      AppConstants.colCollectionTitle: AppConstants.defaultCollectionTitle,
      AppConstants.colUpdatedAt: DateTime.now().toIso8601String(),
    });
  }
}
