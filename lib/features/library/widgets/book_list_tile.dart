import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/text_utils.dart';
import '../../../data/models/book_entry.dart';
import '../../collections/collection_picker_dialog.dart';
import '../../download/download_controller.dart';
import '../../viewer/viewer_controller.dart';
import '../library_controller.dart';
import '../library_sidebar_state.dart';

/// Carte représentant un livre dans une liste (bibliothèque, résultats de
/// recherche, contenu d'un groupe...). Nom latin (LTR) en haut, nom arabe
/// (RTL, aligné à droite) juste en dessous AVEC UN ESPACEMENT EXPLICITE
/// (le fait de laisser Flutter dimensionner ça à travers un ListTile
/// standard provoquait un collage visuel des deux lignes — d'où
/// l'utilisation d'une Card/Column custom avec des SizedBox explicites).
///
/// Un seul bouton "Ajouter" (fonctionne que le livre soit déjà téléchargé
/// ou non — dans ce dernier cas, référence sans retélécharger ni dupliquer
/// les images), plus un bouton "Supprimer" visible seulement s'il est déjà
/// téléchargé (suppression complète). L'auteur n'est PAS affiché ici
/// (uniquement dans le widget d'info du livre pendant la lecture).
class BookListTile extends StatefulWidget {
  final BookEntry book;
  final String group;
  final String? searchTerm;

  const BookListTile({
    super.key,
    required this.book,
    required this.group,
    this.searchTerm,
  });

  @override
  State<BookListTile> createState() => _BookListTileState();
}

class _BookListTileState extends State<BookListTile> with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  int? _lastHandledHighlightToken;

  @override
  void initState() {
    super.initState();
    // Effet de "clignotement" de signalement (fond qui pulse) affiché
    // après un clic sur "Localiser dans la bibliothèque" : quelques
    // battements de fondu, puis retour à l'état normal.
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _maybeStartBlink(LibrarySidebarState sidebarState) {
    final matches = sidebarState.highlightGroup == widget.group &&
        sidebarState.highlightBook == widget.book.folder;
    if (!matches) return;
    if (sidebarState.highlightToken == _lastHandledHighlightToken) return;
    _lastHandledHighlightToken = sidebarState.highlightToken;

    _blinkController.stop();
    _blinkController.value = 0;
    _blinkController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1350), () {
      if (mounted) _blinkController.animateTo(0, duration: const Duration(milliseconds: 200));
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final group = widget.group;
    final searchTerm = widget.searchTerm;

    // Selector plutôt que Consumer complet : cette carte ne se reconstruit
    // que si SA propre valeur (téléchargé / en cours de lecture) change.
    final isDownloaded = context.select<LibraryController, bool>(
      (c) => c.isDownloaded(group, book.folder),
    );
    final isCurrent = context.select<LibraryController, bool>(
      (c) => c.currentGroup == group && c.currentBook == book.folder,
    );
    final sidebarState = context.watch<LibrarySidebarState>();
    _maybeStartBlink(sidebarState);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Nullable : quand aucune mise en avant n'est nécessaire, on laisse
    // `color` à `null` pour que la Card utilise le CardTheme de l'appli
    // (important en thème sombre, où cardTheme.color a une valeur dédiée
    // différente de theme.cardColor). Le livre EN COURS DE LECTURE a un
    // fond un peu plus marqué que les autres états (téléchargé...), pour
    // qu'il reste repérable au premier coup d'œil dans la liste.
    final Color? baseColor = isCurrent
        ? colorScheme.primary.withValues(alpha: 0.22)
        : (isDownloaded ? Colors.green.withValues(alpha: 0.07) : null);

    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        Color? effectiveColor;
        if (_blinkController.value == 0 && baseColor == null) {
          effectiveColor = null; // pas de mise en avant : couleur par défaut du CardTheme
        } else {
          final resolvedBase = baseColor ?? theme.cardTheme.color ?? theme.cardColor;
          effectiveColor = Color.alphaBlend(
            colorScheme.tertiary.withValues(alpha: 0.5 * _blinkController.value),
            resolvedBase,
          );
        }
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: effectiveColor,
          child: child,
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.read<LibraryController>().setCurrentBook(group, book.folder);
          context.read<ViewerController>().openBook(group, book.folder);
          Scaffold.maybeOf(context)?.closeDrawer();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom latin (LTR)
                    Text.rich(
                      TextSpan(
                        children: TextUtils.buildHighlightedSpans(
                          book.displayName,
                          searchTerm: searchTerm,
                          baseStyle: theme.textTheme.bodyLarge!,
                          colorScheme: colorScheme,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Espacement EXPLICITE entre les deux lignes (corrige
                    // le collage visuel latin/arabe).
                    if (book.config.nomArabe.isNotEmpty) const SizedBox(height: 6),
                    // Nom arabe (RTL), aligné à droite
                    if (book.config.nomArabe.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text.rich(
                          TextSpan(
                            children: TextUtils.buildHighlightedSpans(
                              book.config.nomArabe,
                              searchTerm: searchTerm,
                              baseStyle: theme.textTheme.bodyMedium!.copyWith(
                                color: theme.textTheme.bodyMedium!.color?.withValues(alpha: 0.85),
                              ),
                              colorScheme: colorScheme,
                            ),
                          ),
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Ajouter à une collection',
                    icon: const Icon(Icons.download, color: Colors.green),
                    onPressed: () => _addToCollection(context),
                  ),
                  if (isDownloaded)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Supprimer définitivement',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToCollection(BuildContext context) async {
    final book = widget.book;
    final group = widget.group;
    final chosen = await showCollectionPickerDialog(context, bookTitle: book.displayName);
    if (chosen == null || !context.mounted) return;

    await context.read<DownloadController>().addToCollection(
          group: group,
          book: book.folder,
          collectionId: chosen.collectionId,
          collectionTitle: chosen.collectionTitle,
        );

    if (context.mounted) {
      await context.read<LibraryController>().refreshDownloadedBooks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${book.displayName}" ajouté à "${chosen.collectionTitle}".')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final book = widget.book;
    final group = widget.group;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer définitivement'),
        content: Text(
          '"${book.displayName}" sera supprimé de TOUTES vos collections et ses fichiers seront effacés. Continuer ?',
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
    if (confirmed == true && context.mounted) {
      await context.read<DownloadController>().deleteBookEverywhere(group: group, book: book.folder);
      if (context.mounted) {
        await context.read<LibraryController>().refreshDownloadedBooks();
      }
    }
  }
}
