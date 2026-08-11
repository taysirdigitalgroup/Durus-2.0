import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../data/local/collections_repository.dart';
import '../../data/models/collection.dart';
import '../download/download_controller.dart';
import '../viewer/viewer_controller.dart';

/// Équivalent de la gestion des collections côté JS :
/// - liste des livres téléchargés d'une collection, triés par position
/// - réorganisation par glisser-déposer (ReorderableListView remplace
///   avantageusement le Hammer.js drag-and-drop du PHP)
/// - bouton "Lire en continu" qui lance loadCollection() (lecture groupée)
/// - retrait d'un livre de CETTE collection, ou suppression définitive
///   (toutes collections + fichiers)
/// - duplication rapide d'un livre DANS la même collection via l'icône
///   "copier" (référence supplémentaire, jamais de retéléchargement ni de
///   duplication de fichiers image)
///
/// Navigation "One Page" : cet écran est poussé au-dessus de l'écran
/// principal (qui contient le lecteur) ; sélectionner un livre ici met à
/// jour le ViewerController puis revient à l'écran principal.
class DownloadedBooksScreen extends StatefulWidget {
  const DownloadedBooksScreen({super.key});

  @override
  State<DownloadedBooksScreen> createState() => _DownloadedBooksScreenState();
}

class _DownloadedBooksScreenState extends State<DownloadedBooksScreen> {
  List<BookCollection> _collections = [];
  int? _selectedCollectionId;
  List<CollectionBook> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final repo = context.read<CollectionsRepository>();
    final collections = await repo.getAllCollections();

    // Présélectionne la DERNIÈRE collection consultée (mémorisée en
    // préférences) plutôt que de toujours revenir à la première.
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getInt(AppConstants.prefsLastSelectedCollectionKey);
    final lastStillExists = lastId != null && collections.any((c) => c.id == lastId);

    setState(() {
      _collections = collections;
      _selectedCollectionId = lastStillExists ? lastId : (collections.isNotEmpty ? collections.first.id : null);
    });

    if (_selectedCollectionId != null) {
      await _loadBooks(_selectedCollectionId!);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectCollection(int id) async {
    setState(() => _selectedCollectionId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefsLastSelectedCollectionKey, id);
    await _loadBooks(id);
  }

  Future<void> _loadBooks(int collectionId) async {
    setState(() => _loading = true);
    final repo = context.read<CollectionsRepository>();
    final books = await repo.getBooksInCollection(collectionId);
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes collections'),
        actions: [
          IconButton(
            tooltip: 'Renommer la collection',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _selectedCollectionId != null ? _renameCurrentCollection : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_collections.isNotEmpty) _buildCollectionTabs(),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildBooksList()),
        ],
      ),
      floatingActionButton: _books.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.auto_stories),
              label: const Text('Lire en continu'),
              onPressed: _openGroupedReading,
            )
          : null,
    );
  }

  Widget _buildCollectionTabs() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final c = _collections[index];
          final selected = c.id == _selectedCollectionId;
          return ChoiceChip(
            label: Text(c.title, overflow: TextOverflow.ellipsis),
            selected: selected,
            onSelected: (_) => _selectCollection(c.id),
          );
        },
      ),
    );
  }

  /// Actualisation par tiré vers le bas : recharge à la fois la liste des
  /// collections (au cas où une aurait été créée/renommée ailleurs) et le
  /// contenu de la collection actuellement affichée.
  Future<void> _onRefresh() async {
    if (_selectedCollectionId != null) {
      await _loadBooks(_selectedCollectionId!);
    } else {
      await _loadCollections();
    }
  }

  Widget _buildBooksList() {
    if (_books.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'Aucun livre dans cette collection.\nAjoutez un livre depuis la bibliothèque pour le retrouver ici.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _books.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final book = _books[index];
        return ListTile(
          key: ValueKey(book.id),
          leading: CircleAvatar(child: Text('${book.position}')),
          title: Text(book.book, maxLines: 1, overflow: TextOverflow.ellipsis),
          // Icône "copier" à GAUCHE, sur la même ligne que le nom arabe,
          // pour dupliquer rapidement ce livre dans la même collection
          // (nouvelle référence, jamais de retéléchargement d'images).
          subtitle: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _duplicateInCollection(book),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: 4),
              if (book.arabicName.isNotEmpty)
                Expanded(
                  child: Text(
                    book.arabicName,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'duplicate') _duplicateInCollection(book);
                  if (value == 'remove') _removeFromCollection(book);
                  if (value == 'delete') _confirmDeleteEverywhere(book);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'duplicate', child: Text('Dupliquer dans cette collection')),
                  PopupMenuItem(value: 'remove', child: Text('Retirer de cette collection')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer définitivement', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              const Icon(Icons.drag_handle),
            ],
          ),
          onTap: () {
            context.read<ViewerController>().openBook(book.group, book.book);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      },
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updated = List<CollectionBook>.from(_books);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    setState(() => _books = updated);

    if (_selectedCollectionId != null) {
      await context.read<CollectionsRepository>().updatePositions(_selectedCollectionId!, updated);
      await _loadBooks(_selectedCollectionId!); // recharge avec positions à jour (1..N)
    }
  }

  /// Duplique une référence au même livre (group/book) dans la MÊME
  /// collection, à la position suivante — aucune image n'est retéléchargée
  /// ni dupliquée sur le disque, seule une nouvelle ligne de référence est
  /// ajoutée. Le livre apparaîtra alors deux fois (ou plus) dans cette
  /// collection, comme souhaité pour la lecture groupée personnalisée.
  Future<void> _duplicateInCollection(CollectionBook book) async {
    final repo = context.read<CollectionsRepository>();
    await repo.addBookToCollection(
      collectionId: book.collectionId,
      collectionTitle: book.collectionTitle,
      group: book.group,
      book: book.book,
      lang: book.lang,
      nomLatin: book.nomLatin,
      arabicName: book.arabicName,
      author: book.author,
      translator: book.translator,
      voice: book.voice,
      trans: book.trans,
      type: book.type,
    );
    if (_selectedCollectionId != null) await _loadBooks(_selectedCollectionId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livre dupliqué dans cette collection.')),
      );
    }
  }

  Future<void> _removeFromCollection(CollectionBook book) async {
    await context.read<CollectionsRepository>().removeBook(contentId: book.id, collectionId: book.collectionId);
    if (_selectedCollectionId != null) await _loadBooks(_selectedCollectionId!);
  }

  Future<void> _confirmDeleteEverywhere(CollectionBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer définitivement'),
        content: Text(
          '"${book.book}" sera supprimé de TOUTES vos collections et ses fichiers seront effacés. Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<DownloadController>().deleteBookEverywhere(group: book.group, book: book.book);
      if (_selectedCollectionId != null) await _loadBooks(_selectedCollectionId!);
    }
  }

  Future<void> _renameCurrentCollection() async {
    final current = _collections.firstWhere((c) => c.id == _selectedCollectionId);
    final controller = TextEditingController(text: current.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer la collection'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      await context.read<CollectionsRepository>().renameCollection(current.id, newTitle);
      await _loadCollections();
    }
  }

  void _openGroupedReading() {
    if (_selectedCollectionId == null) return;
    context.read<ViewerController>().openCollection(_selectedCollectionId!);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
