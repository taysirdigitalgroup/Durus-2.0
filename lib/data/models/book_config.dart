import '../../core/constants/app_constants.dart';

/// Représente le contenu de config/config.json d'un livre distant.
/// Champs alignés sur rqt_book_config_get.php.
class BookConfig {
  final String nomLatin;
  final String nomArabe;
  final String auteur;
  final String traducteur;
  final String voix;
  final String lang; // 'ar' ou toute autre valeur -> considéré non-arabe
  final String trans;
  final String type;

  const BookConfig({
    required this.nomLatin,
    required this.nomArabe,
    required this.auteur,
    required this.traducteur,
    required this.voix,
    required this.lang,
    required this.trans,
    required this.type,
  });

  bool get isArabic => lang == AppConstants.langArabic;

  factory BookConfig.fromJson(Map<String, dynamic> json, {String fallbackName = ''}) {
    return BookConfig(
      nomLatin: (json['nomLatin'] as String?)?.trim().isNotEmpty == true
          ? json['nomLatin'] as String
          : fallbackName,
      nomArabe: json['nomArabe'] as String? ?? '',
      auteur: json['auteur'] as String? ?? '',
      traducteur: json['traducteur'] as String? ?? '',
      voix: json['voix'] as String? ?? '',
      lang: (json['lang'] as String? ?? AppConstants.langArabic) == AppConstants.langArabic
          ? AppConstants.langArabic
          : AppConstants.langOther,
      trans: json['trans'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  factory BookConfig.empty(String fallbackName) => BookConfig(
        nomLatin: fallbackName,
        nomArabe: '',
        auteur: '',
        traducteur: '',
        voix: '',
        lang: AppConstants.langArabic,
        trans: '',
        type: '',
      );

  Map<String, dynamic> toJson() => {
        'nomLatin': nomLatin,
        'nomArabe': nomArabe,
        'auteur': auteur,
        'traducteur': traducteur,
        'voix': voix,
        'lang': lang,
        'trans': trans,
        'type': type,
      };
}
