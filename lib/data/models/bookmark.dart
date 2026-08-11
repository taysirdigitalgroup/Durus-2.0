import '../../core/constants/app_constants.dart';

/// Marque-page global de l'application (une seule ligne en base),
/// équivalent des colonnes group_name/book/lang/page/last_update de la
/// table `users` côté PHP (rqt_marked_page_get.php / rqt_marked_page_set.php).
///
/// [collectionId] est renseigné si le marque-page a été posé pendant une
/// LECTURE GROUPÉE d'une collection : [group]/[book]/[page] restent la
/// référence LOCALE au livre marqué (numéro de page au sein de CE livre),
/// ce qui permet de retrouver le bon livre + la bonne page même si la
/// collection a été réorganisée depuis (voir ViewerController.openCollection).
class Bookmark {
  final String group;
  final String book;
  final String lang;
  final int page;
  final int? collectionId;
  final String lastUpdate;

  const Bookmark({
    required this.group,
    required this.book,
    required this.lang,
    required this.page,
    this.collectionId,
    required this.lastUpdate,
  });

  bool matches(String group, String book, int page, int? collectionId) =>
      this.group == group && this.book == book && this.page == page && this.collectionId == collectionId;

  factory Bookmark.fromMap(Map<String, dynamic> map) => Bookmark(
        group: map[AppConstants.colGroupName] as String,
        book: map[AppConstants.colBook] as String,
        lang: map[AppConstants.colLang] as String,
        page: map[AppConstants.colPage] as int,
        collectionId: map[AppConstants.colCollectionId] as int?,
        lastUpdate: map[AppConstants.colUpdatedAt] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        AppConstants.colGroupName: group,
        AppConstants.colBook: book,
        AppConstants.colLang: lang,
        AppConstants.colPage: page,
        AppConstants.colCollectionId: collectionId,
        AppConstants.colUpdatedAt: lastUpdate,
      };
}
