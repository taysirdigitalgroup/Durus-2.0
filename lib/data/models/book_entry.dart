import 'book_config.dart';

/// Un livre au sein du catalogue distant, équivalent d'un élément du
/// tableau $books retourné par getBooks() dans rqt_books_all_get.php.
class BookEntry {
  /// Nom exact du dossier du livre dans le dépôt (utilisé pour construire
  /// les URLs), ex: "Al Quran - Juz-u 01".
  final String folder;

  /// Groupe (catégorie) auquel appartient ce livre, ex: "القرءان الكريم 1 Quran".
  final String group;

  final BookConfig config;

  const BookEntry({
    required this.folder,
    required this.group,
    required this.config,
  });

  /// Nom affiché (nomLatin si présent, sinon le nom du dossier).
  String get displayName => config.nomLatin.isNotEmpty ? config.nomLatin : folder;

  bool get isArabic => config.isArabic;

  /// Clé unique stable pour ce livre (groupe + dossier).
  String get uniqueKey => '$group::$folder';
}
