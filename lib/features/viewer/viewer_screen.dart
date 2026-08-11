import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/library_repository.dart';
import 'viewer_controller.dart';
import 'widgets/page_navigation_bar.dart';

/// Équivalent de la zone `#images-container` (carrousel Bootstrap) côté
/// PHP : affiche les pages du livre (ou de la collection en lecture
/// groupée) avec zoom/pan, et applique le sens RTL/LTR via `reverse:`.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late PageController _pageController;
  bool _portraitMode = true;

  @override
  void initState() {
    super.initState();
    final viewer = context.read<ViewerController>();
    _pageController = PageController(initialPage: (viewer.currentPage - 1).clamp(0, 1 << 30));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewerController>(
      builder: (context, viewer, _) {
        // Resynchronise le PageController si la page a changé depuis la
        // barre de navigation plutôt que par un balayage direct.
        final targetIndex = viewer.currentPage - 1;
        if (_pageController.hasClients &&
            _pageController.page?.round() != targetIndex &&
            targetIndex >= 0 &&
            targetIndex < viewer.totalPages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                targetIndex,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              viewer.currentCollectionId != null
                  ? viewer.currentCollectionTitle ?? 'Collection'
                  : viewer.currentBook ?? AppConstants.appName,
            ),
            actions: [
              IconButton(
                tooltip: 'Portrait / Paysage',
                icon: Icon(_portraitMode ? Icons.stay_current_landscape : Icons.stay_current_portrait),
                onPressed: () => setState(() => _portraitMode = !_portraitMode),
              ),
              IconButton(
                tooltip: 'Infos du livre',
                icon: const Icon(Icons.info_outline),
                onPressed: viewer.currentGroup != null ? () => _showBookInfo(context, viewer) : null,
              ),
            ],
          ),
          body: _buildBody(viewer),
          bottomNavigationBar: viewer.state == ViewerLoadState.loaded
              ? const PageNavigationBar()
              : null,
        );
      },
    );
  }

  Widget _buildBody(ViewerController viewer) {
    switch (viewer.state) {
      case ViewerLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewerLoadState.error:
        return Center(child: Text('Erreur : ${viewer.errorMessage}'));
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
        return const Center(child: Text('Sélectionnez un livre dans la bibliothèque.'));
      case ViewerLoadState.loaded:
        return PageView.builder(
          controller: _pageController,
          reverse: viewer.isArabic, // <-- toute la logique RTL tient ici
          itemCount: viewer.totalPages,
          onPageChanged: (index) => viewer.goToPage(index + 1),
          itemBuilder: (context, index) => _PageImage(page: viewer.pages[index]),
        );
    }
  }

  void _showBookInfo(BuildContext context, ViewerController viewer) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(viewer.currentBook ?? '', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Groupe : ${viewer.currentGroup ?? ''}'),
          ],
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
    final provider = page.isLocal
        ? FileImage(File(page.localPath!)) as ImageProvider
        : NetworkImage(page.remoteUrl!);

    return PhotoView(
      imageProvider: provider,
      minScale: PhotoViewComputedScale.contained * AppConstants.viewerMinScale,
      maxScale: PhotoViewComputedScale.contained * AppConstants.viewerMaxScale,
      backgroundDecoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.broken_image, size: 48)),
    );
  }
}
