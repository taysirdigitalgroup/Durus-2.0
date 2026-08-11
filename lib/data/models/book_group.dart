import 'book_entry.dart';

/// Un groupe (catégorie) de livres, équivalent d'une clé du tableau $groups
/// retourné par getBooks() dans rqt_books_all_get.php.
class BookGroup {
  final String name;
  final List<BookEntry> books;

  const BookGroup({required this.name, required this.books});
}
