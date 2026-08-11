import 'package:flutter/foundation.dart';

/// Requête de localisation d'un livre dans le sidebar : quel onglet
/// privilégier, quel groupe ouvrir, quel livre faire défiler jusqu'à
/// l'écran.
class LocateBookRequest {
  final String group;
  final String book;

  /// Si vrai, cible l'onglet "Téléchargés" plutôt que "Tous les livres"
  /// (cas : catalogue distant indisponible hors-ligne mais livre déjà
  /// téléchargé).
  final bool preferDownloadedTab;

  const LocateBookRequest({
    required this.group,
    required this.book,
    required this.preferDownloadedTab,
  });
}

/// Petit bus de commande permettant à un widget qui n'est PAS un
/// descendant du Drawer (ex. la zone de lecture) de demander au sidebar
/// d'ouvrir un onglet précis, de déplier un groupe, et de défiler jusqu'à
/// un livre donné — sans dépendance directe entre les deux widgets.
class LibraryNavigationController extends ChangeNotifier {
  LocateBookRequest? _pending;

  void requestLocate(LocateBookRequest request) {
    _pending = request;
    notifyListeners();
  }

  /// Consomme (et efface) la requête en attente. Le sidebar appelle ceci
  /// une seule fois lorsqu'il est notifié, pour éviter de retraiter la
  /// même requête plusieurs fois.
  LocateBookRequest? consumePending() {
    final request = _pending;
    _pending = null;
    return request;
  }
}
