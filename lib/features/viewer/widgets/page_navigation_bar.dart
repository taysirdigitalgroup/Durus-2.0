import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewer_controller.dart';

/// Équivalent de la barre `#pageNavigationForm` du PHP :
/// premier/précédent/marque-page/champ de saisie de page/suivant/dernier.
/// Les boutons "précédent"/"suivant" sont indépendants de la langue du
/// livre : c'est le PageView (via `reverse: isArabic`) qui donne le sens
/// visuel RTL, pas la logique de ces boutons (voir ViewerController).
class PageNavigationBar extends StatefulWidget {
  const PageNavigationBar({super.key});

  @override
  State<PageNavigationBar> createState() => _PageNavigationBarState();
}

class _PageNavigationBarState extends State<PageNavigationBar> {
  late final TextEditingController _pageFieldController;

  @override
  void initState() {
    super.initState();
    _pageFieldController = TextEditingController();
  }

  @override
  void dispose() {
    _pageFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewerController>(
      builder: (context, viewer, _) {
        _pageFieldController.text = viewer.currentPage.toString();

        // IMPORTANT : les icônes restent TOUJOURS à la même position
        // (première-page/« à gauche, ‹ à gauche, › à droite,
        // dernière-page/» à droite) — c'est l'ACTION déclenchée par
        // chaque bouton qui s'inverse selon la langue, pas l'icône.
        // En effet, en RTL la page 1 est affichée à droite : le bouton
        // le plus à gauche doit donc amener à la DERNIÈRE page (et non
        // "première"), et le chevron gauche doit avancer ("suivant") au
        // lieu de reculer. En LTR, comportement classique inchangé.
        final isRtl = viewer.isArabic;

        final leftEdgeAction = isRtl ? viewer.lastPage : viewer.firstPage;
        final leftEdgeEnabled = isRtl ? viewer.currentPage < viewer.totalPages : viewer.currentPage > 1;
        final leftEdgeTooltip = isRtl ? 'Dernière page' : 'Première page';

        final leftChevronAction = isRtl ? viewer.nextPage : viewer.previousPage;
        final leftChevronEnabled = isRtl ? viewer.currentPage < viewer.totalPages : viewer.currentPage > 1;
        final leftChevronTooltip = isRtl ? 'Page suivante' : 'Page précédente';

        final rightChevronAction = isRtl ? viewer.previousPage : viewer.nextPage;
        final rightChevronEnabled = isRtl ? viewer.currentPage > 1 : viewer.currentPage < viewer.totalPages;
        final rightChevronTooltip = isRtl ? 'Page précédente' : 'Page suivante';

        final rightEdgeAction = isRtl ? viewer.firstPage : viewer.lastPage;
        final rightEdgeEnabled = isRtl ? viewer.currentPage > 1 : viewer.currentPage < viewer.totalPages;
        final rightEdgeTooltip = isRtl ? 'Première page' : 'Dernière page';

        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 4,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: leftEdgeTooltip,
                    icon: const Icon(Icons.first_page),
                    onPressed: leftEdgeEnabled ? leftEdgeAction : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: leftChevronTooltip,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: leftChevronEnabled ? leftChevronAction : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: viewer.isCurrentPageBookmarked
                        ? 'Page marquée'
                        : 'Marquer cette page',
                    icon: Icon(
                      viewer.isCurrentPageBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: viewer.isCurrentPageBookmarked
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: () => _confirmAndMark(context, viewer),
                  ),
                  // Pas de largeur totale fixe ici (l'ancien
                  // SizedBox(width: 84) provoquait "A RenderFlex overflowed
                  // by 6.5 pixels" dès qu'un livre atteint 4 chiffres, ex.
                  // "/1235") : la ligne entière défile déjà horizontalement
                  // (SingleChildScrollView ci-dessus), donc laisser le
                  // compteur se dimensionner naturellement est sans risque
                  // et s'adapte même à 5 chiffres ou plus.
                  SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _pageFieldController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      onSubmitted: (value) => _submitPage(context, viewer, value),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('/${viewer.totalPages}', overflow: TextOverflow.ellipsis),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Retour à la page marquée',
                    icon: const Icon(Icons.replay_circle_filled_outlined),
                    onPressed: viewer.bookmark != null ? () => _confirmAndGoToBookmark(context, viewer) : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: rightChevronTooltip,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: rightChevronEnabled ? rightChevronAction : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: rightEdgeTooltip,
                    icon: const Icon(Icons.last_page),
                    onPressed: rightEdgeEnabled ? rightEdgeAction : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submitPage(BuildContext context, ViewerController viewer, String value) {
    final page = int.tryParse(value.trim());
    if (page == null || page < 1 || page > viewer.totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewer.totalPages == 1
                ? 'Ce livre a une seule page.'
                : 'Veuillez saisir un numéro de page valide entre 1 et ${viewer.totalPages}.',
          ),
        ),
      );
      _pageFieldController.text = viewer.currentPage.toString();
      return;
    }
    viewer.goToPage(page);
  }

  Future<void> _confirmAndMark(BuildContext context, ViewerController viewer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marquer cette page'),
        content: Text('Enregistrer la page ${viewer.currentPage} comme marque-page ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed == true) {
      await viewer.markCurrentPage();
    }
  }

  Future<void> _confirmAndGoToBookmark(BuildContext context, ViewerController viewer) async {
    final bm = viewer.bookmark;
    if (bm == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aller à la page marquée'),
        content: Text(
          'Vous allez quitter la lecture actuelle pour aller à "${bm.book}", page ${bm.page}. Continuer ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed == true) {
      await viewer.goToBookmark();
    }
  }
}
