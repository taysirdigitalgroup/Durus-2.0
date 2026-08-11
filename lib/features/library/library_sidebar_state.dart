import 'package:flutter/foundation.dart';

/// État de navigation du sidebar (bibliothèque), conservé au niveau
/// application — donc INDÉPENDANT du montage/démontage du widget Drawer.
///
/// Objectif explicite : tant que l'app n'est pas fermée, rouvrir le
/// sidebar (bouton toggle, bouton "localiser"...) doit toujours retrouver
/// EXACTEMENT le même onglet, le même groupe déplié et le même niveau de
/// défilement — jamais de réinitialisation. En stockant cet état ici
/// (plutôt que dans le State du widget LibrarySidebar), on élimine tout
/// risque de perte liée au cycle de vie du Drawer (fermeture/réouverture,
/// reconstruction du widget, etc.), et on élimine aussi la race condition
/// qui existait avec l'ancien mécanisme à base d'écouteur unique.
class LibrarySidebarState extends ChangeNotifier {
  int tabIndex = 0; // 0 = "Tous les livres", 1 = "Téléchargés"

  String? selectedAllGroupName;
  String? selectedDownloadedGroupName;

  double allGroupsScrollOffset = 0;
  double downloadedGroupsScrollOffset = 0;
  double inlineAllGroupScrollOffset = 0;
  double inlineDownloadedGroupScrollOffset = 0;

  /// Livre à faire défiler jusqu'à l'écran après une demande de
  /// localisation (consommé une seule fois par le sidebar).
  String? _pendingScrollToBookFolder;

  /// Groupe/livre actuellement ciblés par un clignotement de signalement
  /// (déclenché depuis "Localiser dans la bibliothèque"), et jeton
  /// incrémenté à chaque nouvelle demande — permet à [BookListTile] de
  /// redémarrer l'animation même si c'est exactement le même livre qui est
  /// localisé une seconde fois de suite.
  String? highlightGroup;
  String? highlightBook;
  int highlightToken = 0;

  void setTab(int index) {
    if (tabIndex == index) return;
    tabIndex = index;
    notifyListeners();
  }

  void openGroupAll(String groupName) {
    selectedAllGroupName = groupName;
    inlineAllGroupScrollOffset = 0;
    notifyListeners();
  }

  void closeGroupAll() {
    selectedAllGroupName = null;
    notifyListeners();
  }

  void openGroupDownloaded(String groupName) {
    selectedDownloadedGroupName = groupName;
    inlineDownloadedGroupScrollOffset = 0;
    notifyListeners();
  }

  void closeGroupDownloaded() {
    selectedDownloadedGroupName = null;
    notifyListeners();
  }

  /// Demande de localisation d'un livre depuis l'écran de lecture : bascule
  /// l'onglet, ouvre le bon groupe, et mémorise le livre à cibler pour le
  /// défilement (traité par le sidebar au prochain build).
  void locateBook({
    required String group,
    required String book,
    required bool preferDownloadedTab,
  }) {
    if (preferDownloadedTab) {
      tabIndex = 1;
      selectedDownloadedGroupName = group;
    } else {
      tabIndex = 0;
      selectedAllGroupName = group;
    }
    _pendingScrollToBookFolder = book;
    highlightGroup = group;
    highlightBook = book;
    highlightToken++;
    notifyListeners();
  }

  String? consumePendingScrollTarget() {
    final value = _pendingScrollToBookFolder;
    _pendingScrollToBookFolder = null;
    return value;
  }
}
