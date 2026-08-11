import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/natural_sort.dart';
import '../models/book_config.dart';
import '../remote/github_library_repository.dart';

/// Progression d'un téléchargement de livre.
class DownloadProgress {
  final int downloaded;
  final int total;
  const DownloadProgress(this.downloaded, this.total);
  double get ratio => total == 0 ? 0 : downloaded / total;
  bool get isComplete => total > 0 && downloaded >= total;
}

/// Gère le stockage disque des livres téléchargés pour la lecture
/// hors-ligne. Remplace le rôle d'IndexedDB (`images` object store) côté
/// JS (storeBookImagesInIndexedDB / getImagesFromIndexedDB /
/// deleteBookImagesFromIndexedDB), mais avec de vrais fichiers sur le
/// stockage de l'application plutôt qu'une base de blobs.
class DownloadsRepository {
  final http.Client _client;
  DownloadsRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<Directory> _rootDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, AppConstants.localBooksRootDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _bookDir(String group, String book) async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, group, book, AppConstants.bookImagesSubDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Chemin du config.json PERSISTÉ localement pour un livre téléchargé
  /// (à côté de son dossier d'images, jamais à l'intérieur). Contrairement
  /// aux images, ce fichier n'existait pas avant : sans lui, un livre
  /// téléchargé perdait toute information de langue dès que le catalogue
  /// distant n'était pas en cache (app relancée hors-ligne, cache TTL
  /// expiré, etc.), et retombait sur BookConfig.empty() — donc TOUJOURS
  /// "ar"/RTL quelle que soit la vraie langue du livre (fr/wo/en/...).
  /// C'est la cause du bug "toutes les pages s'affichent en RTL".
  Future<File> _configFile(String group, String book) async {
    final root = await _rootDir();
    final dir = Directory(p.join(root.path, group, book));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, AppConstants.bookConfigFileName));
  }

  /// Sauvegarde le config.json réel du livre (nomLatin/nomArabe/lang/...)
  /// en local, pour que la langue de lecture (RTL/LTR) reste correcte même
  /// hors-ligne ou quand le catalogue distant n'est pas/plus en cache.
  /// Appelé à chaque ajout à une collection, y compris si les images sont
  /// déjà présentes localement (pour rafraîchir une config potentiellement
  /// obsolète).
  Future<void> saveBookConfig(String group, String book, BookConfig config) async {
    final file = await _configFile(group, book);
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  /// Relit le config.json local d'un livre téléchargé, s'il existe.
  /// Retourne `null` si le livre n'a jamais eu sa config sauvegardée
  /// localement (ex. livre téléchargé par une version antérieure de
  /// l'app, avant l'introduction de cette persistance).
  Future<BookConfig?> getLocalBookConfig(String group, String book) async {
    try {
      final file = await _configFile(group, book);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return BookConfig.fromJson(json, fallbackName: book);
    } catch (_) {
      // Fichier corrompu/illisible : on se rabat sur les autres sources
      // (cache catalogue / réseau) plutôt que de faire planter l'ouverture
      // du livre.
      return null;
    }
  }

  /// Vrai si au moins une image du livre est déjà présente localement.
  Future<bool> isBookDownloaded(String group, String book) async {
    final dir = await _bookDir(group, book);
    if (!await dir.exists()) return false;
    final files = await dir.list().toList();
    return files.whereType<File>().isNotEmpty;
  }

  /// Retourne les chemins locaux (triés naturellement) des pages déjà
  /// téléchargées d'un livre. Équivalent getImagesFromIndexedDB().
  Future<List<String>> getLocalImagePaths(String group, String book) async {
    final dir = await _bookDir(group, book);
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    final files = entities.whereType<File>();
    final paths = files.map((f) => f.path).toList();
    paths.sortNaturalBy((path) => p.basename(path));
    return paths;
  }

  /// Télécharge toutes les pages d'un livre depuis GitHub et les écrit sur
  /// le disque. Équivalent storeBookImagesInIndexedDB(). [onProgress] est
  /// appelé après chaque page téléchargée (utile pour une barre de
  /// progression dans la modale de téléchargement).
  Future<void> downloadBook(
    String group,
    String book,
    List<RemoteBookImage> images, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final dir = await _bookDir(group, book);
    var done = 0;

    for (final image in images) {
      final localPath = p.join(dir.path, image.fileName);
      final file = File(localPath);

      if (await file.exists()) {
        done++;
        onProgress?.call(DownloadProgress(done, images.length));
        continue;
      }

      final response = await _client.get(Uri.parse(image.rawUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      }

      done++;
      onProgress?.call(DownloadProgress(done, images.length));
    }
  }

  /// Supprime les images d'un livre du stockage local.
  /// Équivalent deleteBookImagesFromIndexedDB().
  Future<void> deleteBookFiles(String group, String book) async {
    final root = await _rootDir();
    final bookRoot = Directory(p.join(root.path, group, book));
    if (await bookRoot.exists()) {
      await bookRoot.delete(recursive: true);
    }
  }

  void dispose() => _client.close();
}
