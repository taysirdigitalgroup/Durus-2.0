import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Portage Dart des fonctions JS de traitement texte du site PHP :
/// - isArabic() / detection regex \p{Arabic}
/// - normalizeText() (suppression harakats/accents/ponctuation)
/// - highlightElementSacredNames() (Allah / Prophète / Khadimou Rassoul)
/// - highlightSearchedWordProperly() (surlignage du mot recherché)
class TextUtils {
  TextUtils._();

  static final RegExp _arabicRange = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _arabicHarakat = RegExp(r'[\u064B-\u065F]');
  static final RegExp _latinDiacritics = RegExp(r'[\u0300-\u036f]');
  static final RegExp _nonWordKeepArabic = RegExp(r'[^\w\u0600-\u06FF]');

  /// Équivalent isArabic(str) : vrai si le texte contient au moins un caractère arabe.
  static bool looksArabic(String? text) {
    if (text == null || text.isEmpty) return false;
    return _arabicRange.hasMatch(text);
  }

  /// Équivalent normalizeText() : minuscule, sans accents latins ni harakats
  /// arabes, sans ponctuation (les lettres arabes sont conservées).
  static String normalize(String? text) {
    if (text == null) return '';
    var result = text.trim().toLowerCase();
    // Décomposition Unicode + suppression des diacritiques latins (NFD-like).
    result = _stripCombiningMarks(result);
    result = result.replaceAll(_arabicHarakat, '');
    result = result.replaceAll(_nonWordKeepArabic, '');
    return result;
  }

  /// Suppression best-effort des signes diacritiques latins sans dépendre
  /// d'un package externe de normalisation Unicode.
  static String _stripCombiningMarks(String input) {
    const withDiacritics =
        'àâäáãåèéêëìíîïòóôöõùúûüýÿçñ';
    const withoutDiacritics =
        'aaaaaaeeeeiiiiooooouuuuyycn';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = withDiacritics.indexOf(ch);
      if (idx != -1) {
        buffer.write(withoutDiacritics[idx]);
      } else if (!_latinDiacritics.hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Retourne une couleur si [word] (déjà normalisé) correspond à un nom
  /// sacré, sinon null. Reproduit highlightElementSacredNames(), avec des
  /// teintes adaptées au thème (clair/sombre) pour rester lisibles et
  /// "pro" dans les deux cas (au lieu de rouge/bleu/vert saturés fixes).
  static Color? sacredNameColor(String normalizedWord, {required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    if (AppConstants.allahVariants.contains(normalizedWord)) {
      return isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C);
    }
    if (AppConstants.prophetNameVariants.contains(normalizedWord)) {
      return isDark ? const Color(0xFF90CAF9) : const Color(0xFF0D47A1);
    }
    if (AppConstants.khadimVariants.contains(normalizedWord)) {
      return isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20);
    }
    return null;
  }

  /// Construit une liste de [TextSpan] pour un titre de livre en :
  ///  1. mettant en évidence les noms sacrés (toujours actif) ;
  ///  2. surlignant en plus [searchTerm] si fourni (recherche en cours).
  ///
  /// Remplace à la fois highlightElementSacredNames() et
  /// highlightSearchedWordProperly() côté JS, en une seule passe basée sur
  /// des mots (séparateurs = espaces/ponctuation), ce qui est plus simple
  /// et robuste que la manipulation de TreeWalker en JS.
  ///
  /// Le surlignage de recherche utilise désormais la couleur primaire du
  /// thème (avec une opacité adaptée au mode clair/sombre) au lieu d'un
  /// jaune fixe, qui devenait illisible en thème sombre.
  static List<TextSpan> buildHighlightedSpans(
    String text, {
    String? searchTerm,
    required TextStyle baseStyle,
    required ColorScheme colorScheme,
    TextStyle? highlightStyle,
  }) {
    final normalizedSearch =
        (searchTerm != null && searchTerm.trim().isNotEmpty) ? normalize(searchTerm) : null;
    final isDark = colorScheme.brightness == Brightness.dark;

    final highlightBg = isDark
        ? colorScheme.primary.withValues(alpha: 0.35)
        : colorScheme.primary.withValues(alpha: 0.16);
    final highlightFg = isDark ? colorScheme.onPrimary : colorScheme.primary;

    // IMPORTANT : String.split() CONSOMME les délimiteurs (espaces,
    // ponctuation) sans les réinjecter dans la liste résultat — reformer
    // les TextSpan uniquement à partir des "mots" issus d'un split()
    // faisait donc disparaître tous les espaces entre les mots (bug des
    // noms de livres "collés"). On tokenise ici en conservant TOUT le
    // texte source : chaque run d'espaces devient son propre token (rendu
    // tel quel, sans mise en forme), et chaque run de caractères non-
    // espaces (mot, avec sa ponctuation éventuelle collée) devient un
    // token analysé pour le surlignage.
    final tokens = RegExp(r'\s+|\S+').allMatches(text).map((m) => m.group(0)!);
    final spans = <TextSpan>[];

    for (final token in tokens) {
      if (token.trim().isEmpty) {
        // Run d'espaces : conservé intégralement, sans style particulier.
        spans.add(TextSpan(text: token, style: baseStyle));
        continue;
      }

      final word = token;
      final normalizedWord = normalize(word);
      final sacredColor = sacredNameColor(normalizedWord, brightness: colorScheme.brightness);

      final isSearchMatch = normalizedSearch != null &&
          normalizedSearch.isNotEmpty &&
          normalizedWord.contains(normalizedSearch);

      if (isSearchMatch) {
        spans.add(TextSpan(
          text: word,
          style: (highlightStyle ?? baseStyle).copyWith(
            backgroundColor: highlightBg,
            color: sacredColor ?? highlightFg,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (sacredColor != null) {
        spans.add(TextSpan(
          text: word,
          style: baseStyle.copyWith(color: sacredColor, fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: word, style: baseStyle));
      }
    }
    return spans;
  }

  /// Direction du texte à appliquer à un champ (ex. barre de recherche) en
  /// fonction du premier caractère saisi. Équivalent adjustSearchDirection().
  static TextDirection directionForInput(String value) {
    if (value.trim().isEmpty) return TextDirection.rtl; // comportement par défaut du champ recherche
    return looksArabic(value[0]) ? TextDirection.rtl : TextDirection.ltr;
  }

  static final RegExp _arabicRun =
      RegExp(r'[\u0600-\u06FF][\u0600-\u06FF\s\u064B-\u065F]*[\u0600-\u06FF]|[\u0600-\u06FF]');

  /// Beaucoup de noms de groupe distants mélangent latin et arabe dans une
  /// seule chaîne (ex. "القرءان الكريم 1 Quran", ou avec un tiret séparateur
  /// "القصائد الخديم - Qasà-id"). Cette fonction extrait proprement les deux
  /// parties pour un affichage superposé (latin en haut LTR, arabe en bas
  /// RTL) plutôt que d'afficher la chaîne brute mélangée.
  static ({String latin, String arabic}) splitLatinArabic(String raw) {
    final matches = _arabicRun.allMatches(raw).map((m) => m.group(0)!).toList();
    final arabic = matches.join(' ').trim();

    var latin = raw;
    for (final m in matches) {
      latin = latin.replaceFirst(m, ' ');
    }
    latin = latin.trim();
    latin = latin.replaceFirst(RegExp(r'^-\s*'), '');
    latin = latin.replaceFirst(RegExp(r'\s*-$'), '');
    latin = latin.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (latin.isEmpty) latin = raw.trim();
    return (latin: latin, arabic: arabic);
  }
}
