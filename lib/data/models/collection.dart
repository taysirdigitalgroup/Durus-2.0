import '../../core/constants/app_constants.dart';

/// Une collection personnalisée de l'utilisateur (table `collection`).
/// Équivalent de la table `collection` côté MySQL/PHP, mais sans notion
/// d'utilisateur (une seule "personne" = l'appareil).
class BookCollection {
  final int id;
  final String title;
  final String updatedAt;

  const BookCollection({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory BookCollection.fromMap(Map<String, dynamic> map) => BookCollection(
        id: map[AppConstants.colId] as int,
        title: map[AppConstants.colCollectionTitle] as String,
        updatedAt: map[AppConstants.colUpdatedAt] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        AppConstants.colId: id,
        AppConstants.colCollectionTitle: title,
        AppConstants.colUpdatedAt: updatedAt,
      };
}

/// Un livre téléchargé, rattaché à une collection, avec sa position
/// d'affichage. Équivalent d'une ligne de la table `content` côté PHP.
class CollectionBook {
  final int? id;
  final int collectionId;
  final String collectionTitle;
  final String group;
  final String book;
  final int position;
  final String nomLatin;
  final String arabicName;
  final String author;
  final String translator;
  final String voice;
  final String lang; // 'ar' | 'noar'
  final String trans;
  final String type;

  const CollectionBook({
    this.id,
    required this.collectionId,
    required this.collectionTitle,
    required this.group,
    required this.book,
    required this.position,
    this.nomLatin = '',
    this.arabicName = '',
    this.author = '',
    this.translator = '',
    this.voice = '',
    required this.lang,
    this.trans = '',
    this.type = '',
  });

  bool get isArabic => lang == AppConstants.langArabic;

  CollectionBook copyWith({int? id, int? position, int? collectionId, String? collectionTitle}) {
    return CollectionBook(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      collectionTitle: collectionTitle ?? this.collectionTitle,
      group: group,
      book: book,
      position: position ?? this.position,
      nomLatin: nomLatin,
      arabicName: arabicName,
      author: author,
      translator: translator,
      voice: voice,
      lang: lang,
      trans: trans,
      type: type,
    );
  }

  factory CollectionBook.fromMap(Map<String, dynamic> map) => CollectionBook(
        id: map[AppConstants.colId] as int?,
        collectionId: map[AppConstants.colCollectionId] as int,
        collectionTitle: map[AppConstants.colCollectionTitle] as String? ?? '',
        group: map[AppConstants.colGroupName] as String,
        book: map[AppConstants.colBook] as String,
        position: map[AppConstants.colPosition] as int,
        nomLatin: map[AppConstants.colNomLatin] as String? ?? '',
        arabicName: map[AppConstants.colArabicName] as String? ?? '',
        author: map[AppConstants.colAuthor] as String? ?? '',
        translator: map[AppConstants.colTranslator] as String? ?? '',
        voice: map[AppConstants.colVoice] as String? ?? '',
        lang: map[AppConstants.colLang] as String,
        trans: map[AppConstants.colTrans] as String? ?? '',
        type: map[AppConstants.colType] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) AppConstants.colId: id,
        AppConstants.colCollectionId: collectionId,
        AppConstants.colGroupName: group,
        AppConstants.colBook: book,
        AppConstants.colPosition: position,
        AppConstants.colNomLatin: nomLatin,
        AppConstants.colArabicName: arabicName,
        AppConstants.colAuthor: author,
        AppConstants.colTranslator: translator,
        AppConstants.colVoice: voice,
        AppConstants.colLang: lang,
        AppConstants.colTrans: trans,
        AppConstants.colType: type,
      };
}
