import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/natural_sort.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/book_config.dart';
import '../../../data/models/book_entry.dart';
import '../library_controller.dart';
import '../library_sidebar_state.dart';
import 'book_list_tile.dart';
import 'group_card.dart';

/// Hauteur moyenne estimée d'une carte de livre (défilement approximatif
/// vers un livre ciblé par le bouton "localiser").
const double _kEstimatedBookCardExtent = 92.0;

/// Équivalent du panneau `#sidebar` : onglets "Tous les livres" /
/// "Téléchargés", résultats de recherche, blocs de cartes par groupe.
///
/// IMPORTANT : tout l'état de navigation (onglet actif, groupe déplié,
/// défilement) vit dans [LibrarySidebarState] — un contrôleur persistant
/// au niveau application, PAS dans le State de ce widget. Fermer/rouvrir
/// le Drawer (ou y arriver via le bouton "localiser") ne réinitialise donc
/// jamais rien : on retrouve exactement où on en était.
///
/// L'onglet "Téléchargés" est construit ENTIÈREMENT à partir des données
/// locales (table `collection_content`), sans dépendre du catalogue
/// distant : il reste donc pleinement utilisable hors-ligne, même si le
/// catalogue "Tous les livres" n'a pas pu être chargé.
class LibrarySidebar extends StatefulWidget {
  const LibrarySidebar({super.key});

  @override
  State<LibrarySidebar> createState() => _LibrarySidebarState();
}

class _LibrarySidebarState extends State<LibrarySidebar> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final ScrollController _allGroupsScrollController;
  late final ScrollController _downloadedGroupsScrollController;
  late final ScrollController _inlineScrollController;

  @override
  void initState() {
    super.initState();
    final sidebarState = context.read<LibrarySidebarState>();

    _tabController = TabController(length: 2, vsync: this, initialIndex: sidebarState.tabIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<LibrarySidebarState>().setTab(_tabController.index);
      }
    });

    _allGroupsScrollController = ScrollController(initialScrollOffset: sidebarState.allGroupsScrollOffset)
      ..addListener(() {
        if (_allGroupsScrollController.hasClients) {
          sidebarState.allGroupsScrollOffset = _allGroupsScrollController.offset;
        }
      });
    _downloadedGroupsScrollController =
        ScrollController(initialScrollOffset: sidebarState.downloadedGroupsScrollOffset)
          ..addListener(() {
            if (_downloadedGroupsScrollController.hasClients) {
              sidebarState.downloadedGroupsScrollOffset = _downloadedGroupsScrollController.offset;
            }
          });

    final initialInlineOffset = sidebarState.tabIndex == 1
        ? sidebarState.inlineDownloadedGroupScrollOffset
        : sidebarState.inlineAllGroupScrollOffset;
    _inlineScrollController = ScrollController(initialScrollOffset: initialInlineOffset)
      ..addListener(() {
        if (!_inlineScrollController.hasClients) return;
        final s = context.read<LibrarySidebarState>();
        if (s.tabIndex == 1) {
          s.inlineDownloadedGroupScrollOffset = _inlineScrollController.offset;
        } else {
          s.inlineAllGroupScrollOffset = _inlineScrollController.offset;
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allGroupsScrollController.dispose();
    _downloadedGroupsScrollController.dispose();
    _inlineScrollController.dispose();
    super.dispose();
  }

  void _scrollToBook(List<BookEntry> books, String bookFolder) {
    if (!_inlineScrollController.hasClients) return;
    final index = books.indexWhere((b) => b.folder == bookFolder);
    if (index == -1) return;

    final target = (index * _kEstimatedBookCardExtent - 24)
        .clamp(0.0, _inlineScrollController.position.maxScrollExtent);
    _inlineScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  List<BookEntry> _allBooksOfGroup(LibraryController library, String groupName) {
    for (final g in library.groups) {
      if (g.name == groupName) return g.books;
    }
    return const [];
  }

  /// Construit la liste des livres téléchargés d'un groupe ENTIÈREMENT à
  /// partir des données locales (`library.downloadedBooks`), sans jamais
  /// dépendre du catalogue distant — c'est ce qui garantit que l'onglet
  /// "Téléchargés" fonctionne même hors-ligne / si le catalogue n'a pas pu
  /// être chargé. Les infos affichées (nom latin/arabe, langue) viennent
  /// des colonnes capturées au moment du téléchargement.
  List<BookEntry> _downloadedBooksOfGroup(LibraryController library, String groupName) {
    final seenFolders = <String>{};
    final result = <BookEntry>[];

    for (final b in library.downloadedBooks) {
      if (b.group != groupName) continue;
      if (!seenFolders.add(b.book)) continue; // dédoublonnage (référencé plusieurs fois dans des collections)
      result.add(BookEntry(
        folder: b.book,
        group: b.group,
        config: BookConfig(
          nomLatin: b.nomLatin.isNotEmpty ? b.nomLatin : b.book,
          nomArabe: b.arabicName,
          auteur: b.author,
          traducteur: b.translator,
          voix: b.voice,
          lang: b.lang,
          trans: b.trans,
          type: b.type,
        ),
      ));
    }

    result.sort((a, b) {
      if (a.isArabic && !b.isArabic) return -1;
      if (!a.isArabic && b.isArabic) return 1;
      return naturalCompare(a.displayName, b.displayName);
    });
    return result;
  }

  List<String> _downloadedGroupNames(LibraryController library) {
    final names = <String>{};
    for (final b in library.downloadedBooks) {
      names.add(b.group);
    }
    final list = names.toList()..sort(naturalCompare);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sidebarState = context.watch<LibrarySidebarState>();

    // Applique une éventuelle demande de localisation en attente (bouton
    // "localiser" depuis le lecteur) : bascule l'onglet visuellement...
    if (_tabController.index != sidebarState.tabIndex) {
      _tabController.index = sidebarState.tabIndex;
    }

    return Consumer<LibraryController>(
      builder: (context, library, _) {
        // ... puis, une fois la liste construite, défile jusqu'au livre
        // ciblé (nécessite de connaître la liste du groupe = library).
        final pendingBook = sidebarState.consumePendingScrollTarget();
        if (pendingBook != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final books = sidebarState.tabIndex == 1
                ? _downloadedBooksOfGroup(library, sidebarState.selectedDownloadedGroupName ?? '')
                : _allBooksOfGroup(library, sidebarState.selectedAllGroupName ?? '');
            _scrollToBook(books, pendingBook);
          });
        }

        if (library.searchQuery.isNotEmpty) {
          return _buildSearchResults(library);
        }

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Tous les livres'),
                Tab(text: 'Téléchargés'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  sidebarState.selectedAllGroupName != null
                      ? _buildGroupInline(
                          groupName: sidebarState.selectedAllGroupName!,
                          books: _allBooksOfGroup(library, sidebarState.selectedAllGroupName!),
                          onBack: () => context.read<LibrarySidebarState>().closeGroupAll(),
                          onRefresh: library.refresh,
                        )
                      : _buildAllBooksGroups(library, sidebarState),
                  sidebarState.selectedDownloadedGroupName != null
                      ? _buildGroupInline(
                          groupName: sidebarState.selectedDownloadedGroupName!,
                          books:
                              _downloadedBooksOfGroup(library, sidebarState.selectedDownloadedGroupName!),
                          onBack: () => context.read<LibrarySidebarState>().closeGroupDownloaded(),
                          onRefresh: library.refreshDownloadedBooks,
                        )
                      : _buildDownloadedGroups(library, sidebarState),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupInline({
    required String groupName,
    required List<BookEntry> books,
    required VoidCallback onBack,
    required Future<void> Function() onRefresh,
  }) {
    final theme = Theme.of(context);
    final parts = TextUtils.splitLatinArabic(groupName);

    return Column(
      children: [
        Material(
          elevation: 1,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Retour',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        parts.latin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (parts.arabic.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            parts.arabic,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: books.isEmpty
                ? ListView(
                    controller: _inlineScrollController,
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: Text('Aucun livre dans ce groupe.')),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _inlineScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: books.length,
                    itemBuilder: (context, index) => BookListTile(
                      book: books[index],
                      group: books[index].group,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(LibraryController library) {
    Future<void> onRefresh() async {
      await library.refresh();
      await library.search(library.searchQuery);
    }

    if (library.searchResults.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(child: Text('Aucun résultat pour «${library.searchQuery}»')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: library.searchResults.length,
        itemBuilder: (context, index) {
          final result = library.searchResults[index];
          return BookListTile(
            book: result.book,
            group: result.group,
            searchTerm: library.searchQuery,
          );
        },
      ),
    );
  }

  Widget _buildAllBooksGroups(LibraryController library, LibrarySidebarState sidebarState) {
    switch (library.state) {
      case LibraryLoadState.loading:
      case LibraryLoadState.idle:
        final total = library.loadProgressTotal;
        final done = library.loadProgressDone;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: total > 0 ? done / total : null),
                const SizedBox(height: 16),
                Text(
                  total > 0
                      ? 'Chargement du catalogue... ($done/$total livres)'
                      : 'Connexion au catalogue distant...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case LibraryLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(library.friendlyErrorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: library.loadInitial, child: const Text('Réessayer')),
              ],
            ),
          ),
        );
      case LibraryLoadState.loaded:
        return RefreshIndicator(
          onRefresh: library.refresh,
          child: ListView.builder(
            controller: _allGroupsScrollController,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: library.groups.length,
            itemBuilder: (context, index) {
              final group = library.groups[index];
              final parts = TextUtils.splitLatinArabic(group.name);
              return GroupCard(
                latinName: parts.latin,
                arabicName: parts.arabic,
                bookCount: group.books.length,
                onTap: () => sidebarState.openGroupAll(group.name),
              );
            },
          ),
        );
    }
  }

  Widget _buildDownloadedGroups(LibraryController library, LibrarySidebarState sidebarState) {
    final matchingGroupNames = _downloadedGroupNames(library);

    if (matchingGroupNames.isEmpty) {
      return RefreshIndicator(
        onRefresh: library.refreshDownloadedBooks,
        child: ListView(
          controller: _downloadedGroupsScrollController,
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  "Aucun livre téléchargé pour l'instant.",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: library.refreshDownloadedBooks,
      child: ListView.builder(
        controller: _downloadedGroupsScrollController,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: matchingGroupNames.length,
        itemBuilder: (context, index) {
          final groupName = matchingGroupNames[index];
          final books = _downloadedBooksOfGroup(library, groupName);
          final parts = TextUtils.splitLatinArabic(groupName);
          return GroupCard(
            latinName: parts.latin,
            arabicName: parts.arabic,
            bookCount: books.length,
            onTap: () => sidebarState.openGroupDownloaded(groupName),
          );
        },
      ),
    );
  }
}
