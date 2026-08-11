import 'package:flutter/material.dart';

import '../../data/models/book_entry.dart';
import 'widgets/book_list_tile.dart';

/// Sous-page ouverte au clic sur une carte de groupe : nom du groupe
/// (latin superposé à l'arabe) et icône de retour fixés en haut (AppBar
/// standard), liste des livres de ce groupe en dessous.
class GroupBooksPage extends StatelessWidget {
  final String groupLatin;
  final String groupArabic;
  final List<BookEntry> books;
  final Future<void> Function()? onRefresh;

  const GroupBooksPage({
    super.key,
    required this.groupLatin,
    required this.groupArabic,
    required this.books,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(groupLatin, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (groupArabic.isNotEmpty)
              Text(
                groupArabic,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: books.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('Aucun livre dans ce groupe.')),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: books.length,
                itemBuilder: (context, index) =>
                    BookListTile(book: books[index], group: books[index].group),
              ),
      ),
    );
  }
}
