import 'package:flutter/material.dart';

/// Bloc "carte" représentant un groupe (catégorie) de livres. Remplace le
/// style liste déroulante (ExpansionTile) par un joli bloc, avec le nom
/// latin (LTR) superposé au nom arabe (RTL, aligné à droite) — ces deux
/// noms étant extraits du nom brut du groupe distant via
/// TextUtils.splitLatinArabic(). Au clic, ouvre une sous-page dédiée.
class GroupCard extends StatelessWidget {
  final String latinName;
  final String arabicName;
  final int bookCount;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.latinName,
    required this.arabicName,
    required this.bookCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      latinName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (arabicName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            arabicName,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '$bookCount livre${bookCount > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
