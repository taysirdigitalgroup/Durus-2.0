import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/library_repository.dart';
import '../library/library_controller.dart';
import '../library/library_sidebar_state.dart';
import 'viewer_controller.dart';
import 'widgets/page_navigation_bar.dart';

/// Contenu de la zone de lecture, SANS Scaffold/AppBar propres : ce widget
/// est intégré directement dans le corps de l'écran unique de l'app
/// (One Page demandé), à côté du sidebar (Drawer). Équivalent de la zone
/// `#images-container` + `#metaBookSection` du PHP.
class ReaderBody extends StatefulWidget {
  const ReaderBody({super.key});

  @override
  State<ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends State<ReaderBody> {
  PageController? _pageController;
  int? _controllerForCollectionOrBook;
  bool _portraitMode = true;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewerController>(
      builder: (context, viewer, _) {
        return Column(
          children: [
            if (viewer.state == ViewerLoadState.loaded) _buildInfoBar(context, viewer),
            Expanded(
              child: Stack(
                children: [
                  _buildBody(viewer),
                  if (viewer.state == ViewerLoadState.loaded)
                    _ReadingDirectionHint(
                      isArabic: viewer.isArabic,
                      triggerToken: viewer.openEventToken,
                    ),
                ],
              ),
            ),
            if (viewer.state == ViewerLoadState.loaded) const PageNavigationBar(),
          ],
        );
      },
    );
  }

  Widget _buildInfoBar(BuildContext context, ViewerController viewer) {
    final config = viewer.currentBookConfig;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => _showBookInfo(context, viewer),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config?.nomLatin ?? viewer.currentBook ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (config != null && config.nomArabe.isNotEmpty)
                      Text(
                        config.nomArabe,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Localiser dans la bibliothèque',
                icon: const Icon(Icons.my_location),
                onPressed: () => _locateCurrentBookInSidebar(context, viewer),
              ),
              IconButton(
                tooltip: 'Portrait / Paysage',
                icon: Icon(_portraitMode ? Icons.stay_current_landscape : Icons.stay_current_portrait),
                onPressed: () => setState(() => _portraitMode = !_portraitMode),
              ),
              const Icon(Icons.info_outline, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ViewerController viewer) {
    switch (viewer.state) {
      case ViewerLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewerLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 40, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(viewer.friendlyErrorMessage, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      case ViewerLoadState.empty:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Livre introuvable en local.\nVeuillez vérifier votre connexion et télécharger ce livre pour le consulter hors connexion.",
              textAlign: TextAlign.center,
            ),
          ),
        );
      case ViewerLoadState.idle:
        return _buildWelcome(context);
      case ViewerLoadState.loaded:
        return _buildPageView(viewer);
    }
  }

  /// Crée (ou resynchronise) le PageController UNIQUEMENT ici, dans le cas
  /// 'loaded' — c'est-à-dire seulement une fois que viewer.currentPage a
  /// déjà sa valeur DÉFINITIVE pour ce livre/collection. Le faire plus tôt
  /// (ex. dès le passage à l'état 'loading', avant que le chargement
  /// asynchrone n'ait fixé la bonne page) créait un PageController avec un
  /// `initialPage` basé sur l'ANCIENNE page affichée précédemment — d'où
  /// le bug "marque page 4, retour affiche la page 1" : le PageView
  /// s'attachait à ce controller prématuré dès son premier rendu, et la
  /// resynchronisation ultérieure ne se déclenchait pas de manière fiable
  /// (le contrôleur n'avait pas encore de client au moment du test).
  Widget _buildPageView(ViewerController viewer) {
    final identity = Object.hash(viewer.currentGroup, viewer.currentBook, viewer.currentCollectionId);

    if (_pageController == null || _controllerForCollectionOrBook != identity) {
      _pageController?.dispose();
      _pageController = PageController(initialPage: (viewer.currentPage - 1).clamp(0, 1 << 30));
      _controllerForCollectionOrBook = identity;
    } else {
      // Même livre/collection déjà affiché : si la page courante a changé
      // par un autre biais qu'un balayage direct (bouton de navigation,
      // retour au marque-page alors qu'on est déjà sur ce livre...), on
      // resynchronise le PageView après le prochain frame.
      final targetIndex = viewer.currentPage - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController != null &&
            _pageController!.hasClients &&
            _pageController!.page?.round() != targetIndex &&
            targetIndex >= 0 &&
            targetIndex < viewer.totalPages) {
          _pageController!.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return PageView.builder(
      key: ValueKey(_controllerForCollectionOrBook),
      controller: _pageController,
      reverse: viewer.isArabic, // <-- toute la logique RTL tient ici
      itemCount: viewer.totalPages,
      onPageChanged: (index) => viewer.goToPage(index + 1),
      itemBuilder: (context, index) => _PageImage(page: viewer.pages[index]),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'Choisissez un livre dans le menu pour commencer la lecture.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (ctx) => OutlinedButton.icon(
                icon: const Icon(Icons.menu),
                label: const Text('Ouvrir la bibliothèque'),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre le sidebar, sélectionne le bon onglet, déplie le groupe du
  /// livre affiché, et défile jusqu'à lui. Si le catalogue distant n'est
  /// pas disponible (pas de connexion) ET que le livre est déjà
  /// téléchargé, cible l'onglet "Téléchargés" plutôt que "Tous les
  /// livres" (qui serait vide/inutilisable hors-ligne sans cache).
  void _locateCurrentBookInSidebar(BuildContext context, ViewerController viewer) {
    final group = viewer.currentPageGroup;
    final book = viewer.currentPageBook;
    if (group == null || book == null) return;

    final library = context.read<LibraryController>();
    final isDownloaded = library.isDownloaded(group, book);
    final catalogAvailable = library.state == LibraryLoadState.loaded && library.groups.isNotEmpty;
    final preferDownloadedTab = !catalogAvailable && isDownloaded;

    // Si une recherche est affichée dans le sidebar, "Localiser dans la
    // bibliothèque" restait auparavant sans effet visible (le sidebar
    // affiche la liste de résultats plutôt que les onglets/groupes tant
    // qu'une recherche est active). On ferme donc d'abord la recherche
    // pour laisser place à l'onglet/groupe ciblé.
    if (library.searchQuery.isNotEmpty) {
      library.clearSearch();
    }

    // Aligne la surbrillance "livre en cours" du sidebar sur la page
    // réellement affichée (utile notamment en lecture groupée, où
    // currentGroup/currentBook du ViewerController restent à null).
    library.setCurrentBook(group, book);

    context.read<LibrarySidebarState>().locateBook(
          group: group,
          book: book,
          preferDownloadedTab: preferDownloadedTab,
        );

    Scaffold.of(context).openDrawer();
  }

  void _showBookInfo(BuildContext context, ViewerController viewer) {
    final config = viewer.currentBookConfig;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config?.nomLatin ?? viewer.currentBook ?? '', style: Theme.of(ctx).textTheme.titleLarge),
            if (config != null && config.nomArabe.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  config.nomArabe,
                  textDirection: TextDirection.rtl,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            const Divider(height: 24),
            if (config != null && config.auteur.isNotEmpty) _InfoLine(label: 'Auteur', value: config.auteur),
            if (config != null && config.traducteur.isNotEmpty)
              _InfoLine(label: 'Traducteur', value: config.traducteur),
            if (config != null && config.voix.isNotEmpty) _InfoLine(label: 'Voix', value: config.voix),
            if (viewer.currentCollectionId != null)
              _InfoLine(label: 'Nom collection', value: viewer.currentCollectionTitle ?? '')
            else
              _InfoLine(label: 'Groupe', value: viewer.currentGroup ?? ''),
            _InfoLine(label: 'Langue', value: viewer.isArabic ? 'Arabe' : 'Latin'),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Flèche épaisse indiquant le sens de lecture, affichée UNIQUEMENT à
/// chaque "ouverture" d'un livre/collection (affichage simple ou retour à
/// un marque-page — voir [ViewerController.openEventToken]), jamais lors
/// d'une simple navigation de page à page. Clignote lentement pendant 3
/// secondes puis disparaît d'elle-même.
///
/// Position/sens ancrés à la logique de navigation déjà en place dans
/// [PageNavigationBar] (`reverse: viewer.isArabic`) : en arabe (RTL,
/// PageView inversé), on avance en balayant vers la GAUCHE, d'où une
/// flèche "<-" en haut à GAUCHE ; en latin (LTR), on avance en balayant
/// vers la DROITE, d'où une flèche "->" en haut à DROITE.
class _ReadingDirectionHint extends StatefulWidget {
  final bool isArabic;
  final int triggerToken;

  const _ReadingDirectionHint({required this.isArabic, required this.triggerToken});

  @override
  State<_ReadingDirectionHint> createState() => _ReadingDirectionHintState();
}

class _ReadingDirectionHintState extends State<_ReadingDirectionHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Cycle lent (900ms par demi-battement) pour un clignotement doux,
    // pas agressif.
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _startFor(widget.triggerToken);
  }

  void _startFor(int token) {
    _hideTimer?.cancel();
    if (token <= 0) return; // pas encore de première ouverture réelle
    setState(() => _visible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didUpdateWidget(covariant _ReadingDirectionHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.triggerToken != widget.triggerToken) {
      _startFor(widget.triggerToken);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final icon = widget.isArabic ? Icons.arrow_back : Icons.arrow_forward;

    return Positioned(
      top: 16,
      left: widget.isArabic ? 16 : null,
      right: widget.isArabic ? null : 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 32, color: theme.colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  final ViewerPage page;
  const _PageImage({required this.page});

  @override
  Widget build(BuildContext context) {
    // photo_view retiré du chemin critique de rendu simple : on utilise
    // InteractiveViewer (inclus dans Flutter, plus léger) pour le zoom,
    // ce qui réduit le travail de layout par page et améliore la fluidité
    // de la navigation entre pages (une des lenteurs remontées).
    final image = page.isLocal
        ? Image.file(File(page.localPath!), fit: BoxFit.contain, gaplessPlayback: true)
        : Image.network(page.remoteUrl!, fit: BoxFit.contain, gaplessPlayback: true);

    return InteractiveViewer(
      minScale: AppConstants.viewerMinScale,
      maxScale: AppConstants.viewerMaxScale,
      child: Center(child: image),
    );
  }
}
