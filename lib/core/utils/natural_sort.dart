/// Portage simple de strnatcmp()/natsort() de PHP, utilisé pour trier :
/// - les noms de livres/groupes (comme uksort/usort côté rqt_books_all_get.php)
/// - les fichiers image d'un livre par numéro de page (comme natsort() côté
///   rqt_books_group_images_get.php / rqt_book_download.php)
library;

final RegExp _chunkPattern = RegExp(r'(\d+|\D+)');

/// Compare deux chaînes selon un ordre "naturel" : les segments numériques
/// sont comparés par valeur (1 < 2 < 10), pas lexicographiquement (1 < 10 < 2).
int naturalCompare(String a, String b) {
  final aChunks = _chunkPattern.allMatches(a).map((m) => m.group(0)!).toList();
  final bChunks = _chunkPattern.allMatches(b).map((m) => m.group(0)!).toList();

  final len = aChunks.length < bChunks.length ? aChunks.length : bChunks.length;

  for (var i = 0; i < len; i++) {
    final ac = aChunks[i];
    final bc = bChunks[i];

    final aIsNum = RegExp(r'^\d+$').hasMatch(ac);
    final bIsNum = RegExp(r'^\d+$').hasMatch(bc);

    if (aIsNum && bIsNum) {
      final an = BigInt.parse(ac);
      final bn = BigInt.parse(bc);
      final cmp = an.compareTo(bn);
      if (cmp != 0) return cmp;
    } else {
      final cmp = ac.compareTo(bc);
      if (cmp != 0) return cmp;
    }
  }
  return aChunks.length.compareTo(bChunks.length);
}

extension NaturalSortList<T> on List<T> {
  /// Trie la liste en place en appliquant [naturalCompare] sur la clé
  /// retournée par [keyOf] pour chaque élément.
  void sortNaturalBy(String Function(T) keyOf) {
    sort((a, b) => naturalCompare(keyOf(a), keyOf(b)));
  }
}
