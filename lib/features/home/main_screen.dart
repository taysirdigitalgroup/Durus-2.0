import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../collections/downloaded_books_screen.dart';
import '../info/info_page.dart';
import '../library/library_controller.dart';
import '../library/widgets/library_search_field.dart';
import '../library/widgets/library_sidebar.dart';
import '../viewer/reader_body.dart';
import '../viewer/viewer_controller.dart';

/// Écran unique de l'application ("One Page" demandé) : un seul Scaffold
/// avec un Drawer (bibliothèque + recherche) et un corps qui affiche en
/// permanence la zone de lecture — il n'y a plus de navigation séparée
/// pour lire un livre, tout se passe sur cet écran.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final library = context.read<LibraryController>();
      await library.loadInitial();
      // Filet de sécurité : actualise le catalogue et les téléchargements
      // de temps en temps en arrière-plan, pour que les livres ajoutés au
      // dépôt distant finissent par apparaître même sans tiré-vers-le-bas
      // manuel de l'utilisateur.
      library.startAutoRefresh();
      // Charge le marque-page dès l'ouverture de l'app (sans ouvrir de
      // livre) pour pouvoir afficher tout de suite "Continuer la lecture".
      context.read<ViewerController>().loadBookmarkOnly();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Revenir au premier plan est un bon moment pour vérifier
    // silencieusement s'il y a du nouveau dans le catalogue distant.
    if (state == AppLifecycleState.resumed) {
      context.read<LibraryController>().refreshSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(AppConstants.appIconAsset, width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            const Text(AppConstants.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mes collections',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadedBooksScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Développeur',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage())),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(AppConstants.appName, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              const Divider(height: 1),
              const LibrarySearchField(),
              const Expanded(child: LibrarySidebar()),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          const _ContinueReadingBanner(),
          const Expanded(child: ReaderBody()),
        ],
      ),
    );
  }
}

/// Bannière "Continuer la lecture" affichée dès qu'un marque-page existe
/// et qu'aucun livre n'est activement en cours d'affichage — demande
/// explicite : elle doit être visible dès l'ouverture de l'app si un
/// marque-page est présent.
class _ContinueReadingBanner extends StatelessWidget {
  const _ContinueReadingBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewerController>(
      builder: (context, viewer, _) {
        final bookmark = viewer.bookmark;
        if (bookmark == null || viewer.state == ViewerLoadState.loaded) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.primaryContainer,
          child: InkWell(
            onTap: () => viewer.goToBookmark(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill, color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Continuer la lecture',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                        ),
                        Text(
                          '${bookmark.book} — page ${bookmark.page}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
