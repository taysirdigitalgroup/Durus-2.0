import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/bookmark_repository.dart';
import 'data/local/collections_repository.dart';
import 'data/local/downloads_repository.dart';
import 'data/remote/github_library_repository.dart';
import 'data/repositories/library_repository.dart';
import 'features/download/download_controller.dart';
import 'features/home/main_screen.dart';
import 'features/library/library_controller.dart';
import 'features/library/library_sidebar_state.dart';
import 'features/viewer/viewer_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DurusApp());
}

/// Racine de l'application Durus 2.0. Toutes les dépendances (dépôts
/// distant/local, contrôleurs) sont construites ici une seule fois et
/// injectées via Provider, exactement comme les différents modules du
/// script.js étaient tous chargés une fois au démarrage de la page.
class DurusApp extends StatelessWidget {
  const DurusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GithubLibraryRepository>(
          create: (_) => GithubLibraryRepository(),
          dispose: (_, repo) => repo.dispose(),
        ),
        Provider<DownloadsRepository>(
          create: (_) => DownloadsRepository(),
          dispose: (_, repo) => repo.dispose(),
        ),
        Provider<CollectionsRepository>(create: (_) => CollectionsRepository()),
        Provider<BookmarkRepository>(create: (_) => BookmarkRepository()),
        ProxyProvider2<GithubLibraryRepository, DownloadsRepository, LibraryRepository>(
          update: (_, remote, downloads, __) =>
              LibraryRepository(remote: remote, downloads: downloads),
        ),
        ChangeNotifierProvider<LibraryController>(
          create: (context) => LibraryController(
            libraryRepository: context.read<LibraryRepository>(),
            collectionsRepository: context.read<CollectionsRepository>(),
          ),
        ),
        ChangeNotifierProvider<LibrarySidebarState>(
          create: (_) => LibrarySidebarState(),
        ),
        ChangeNotifierProvider<ViewerController>(
          create: (context) => ViewerController(
            libraryRepository: context.read<LibraryRepository>(),
            collectionsRepository: context.read<CollectionsRepository>(),
            bookmarkRepository: context.read<BookmarkRepository>(),
          ),
        ),
        ChangeNotifierProvider<DownloadController>(
          create: (context) => DownloadController(
            remote: context.read<GithubLibraryRepository>(),
            downloads: context.read<DownloadsRepository>(),
            collections: context.read<CollectionsRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const MainScreen(),
      ),
    );
  }
}
