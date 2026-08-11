import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../collections/downloaded_books_screen.dart';
import '../library/library_controller.dart';
import '../library/widgets/library_search_field.dart';
import '../library/widgets/library_sidebar.dart';
import '../viewer/viewer_controller.dart';
import '../viewer/viewer_screen.dart';

/// Écran principal : équivalent de la page unique index.html qui combine
/// sidebar (liste/recherche) et zone de lecture, mais adapté à un usage
/// mobile (deux écrans distincts reliés par la navigation plutôt qu'un
/// layout desktop à deux colonnes).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryController>().loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Mes collections',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadedBooksScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const LibrarySearchField(),
          const Expanded(child: LibrarySidebar()),
        ],
      ),
      floatingActionButton: Consumer<ViewerController>(
        builder: (context, viewer, _) {
          if (viewer.state != ViewerLoadState.loaded && viewer.bookmark == null) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            icon: const Icon(Icons.menu_book),
            label: Text(viewer.state == ViewerLoadState.loaded ? 'Reprendre la lecture' : 'Marque-page'),
            onPressed: () async {
              if (viewer.state != ViewerLoadState.loaded) {
                await viewer.goToBookmark();
              }
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewerScreen()));
              }
            },
          );
        },
      ),
    );
  }
}
