import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// Page "Développeur / À propos" : présente Durus 2.0, Taysir Digital
/// Group (TDG) et son fondateur, les moyens de contact, et les options de
/// soutien (dons). Adaptée d'un gabarit existant côté TDG, simplifiée pour
/// Durus 2.0 (pas de vérification de mise à jour serveur, pas de stack
/// "mini serveur web" qui ne concerne pas cette app de lecture hors-ligne).
class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String _version = '…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {
      if (mounted) setState(() => _version = 'inconnue');
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copy(BuildContext ctx, String text, {String? snack}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(snack ?? 'Copié : $text'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Développeur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _Logo(),
            const SizedBox(height: 14),
            Text(
              AppConstants.tdgCompanyName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            Text(
              AppConstants.tdgShortName,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '« ${AppConstants.tdgTagline} »',
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            _InfoCard(
              icon: Icons.phone_android,
              iconColor: const Color(0xFF1565C0),
              title: 'À propos de l\'application',
              children: [
                const _AppInfoRow(label: 'Application', value: AppConstants.appName),
                _AppInfoRow(label: 'Version', value: _version),
                const _AppInfoRow(label: 'Moteur', value: 'Flutter'),
                const _AppInfoRow(label: 'Bibliothèque', value: 'xassidati-datas (GitHub)'),
                const _AppInfoRow(label: 'Lecture hors-ligne', value: 'Oui, après téléchargement'),
              ],
            ),
            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.person_outline,
              iconColor: const Color(0xFF2E7D32),
              title: 'Développeur',
              children: const [
                _AppInfoRow(label: 'Nom', value: AppConstants.developerName),
                _AppInfoRow(label: 'Titre', value: AppConstants.developerTitle),
                _AppInfoRow(label: 'Société', value: 'Taysir Digital Group (TDG)'),
              ],
            ),
            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.contact_phone_outlined,
              iconColor: const Color(0xFF6A1B9A),
              title: 'Contacts',
              children: [
                _ContactRow(
                  icon: Icons.phone,
                  label: AppConstants.tdgPhoneDisplay,
                  onTap: () => _launch('tel:${AppConstants.tdgPhoneDial}'),
                  onLongPress: () => _copy(context, AppConstants.tdgPhoneDial),
                  color: const Color(0xFF2E7D32),
                ),
                const Divider(height: 1),
                _ContactRow(
                  icon: Icons.email_outlined,
                  label: AppConstants.tdgEmail,
                  onTap: () => _launch('mailto:${AppConstants.tdgEmail}'),
                  onLongPress: () => _copy(context, AppConstants.tdgEmail),
                  color: const Color(0xFFD32F2F),
                ),
                const Divider(height: 1),
                _ContactRow(
                  icon: Icons.language,
                  label: 'Site web TDG',
                  onTap: () => _launch(AppConstants.tdgWebsite),
                  color: const Color(0xFF1565C0),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.volunteer_activism_outlined,
              iconColor: const Color(0xFFE91E63),
              title: 'Nous soutenir',
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Durus 2.0 est développée et maintenue par TDG. Si l\'application vous est utile, un don est toujours apprécié et nous aide à continuer.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                _DonateButton(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF003087),
                  label: 'PayPal',
                  sublabel: AppConstants.donatePaypalLabel,
                  onTap: () => _launch(AppConstants.donatePaypalUrl),
                ),
                const SizedBox(height: 10),
                _DonateButton(
                  icon: Icons.waves,
                  iconColor: const Color(0xFF1BC5BD),
                  label: 'Wave',
                  sublabel: AppConstants.donateWaveLabel,
                  onTap: () => _launch(AppConstants.donateWaveUrl),
                ),
                const SizedBox(height: 8),
                _CopyNumberRow(
                  label: 'Wave',
                  numberDisplay: AppConstants.donateWaveNumberDisplay,
                  numberDial: AppConstants.donateWaveNumberDial,
                  color: const Color(0xFF1BC5BD),
                  onCopy: (text) => _copy(context, text, snack: 'Numéro copié'),
                ),
                _CopyNumberRow(
                  label: 'Orange Money',
                  numberDisplay: AppConstants.donateOrangeMoneyNumberDisplay,
                  numberDial: AppConstants.donateOrangeMoneyNumberDial,
                  color: const Color(0xFFFF6600),
                  onCopy: (text) => _copy(context, text, snack: 'Numéro copié'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.copyright, size: 18, color: Colors.grey),
                  const SizedBox(height: 6),
                  const Text(
                    '© Taysir Digital Group (TDG)',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tous droits réservés.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(AppConstants.tdgLogoAsset, width: 120, height: 120, fit: BoxFit.cover),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _AppInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color color;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
}

class _DonateButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _DonateButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fond calculé à partir de la couleur de l'icône plutôt qu'une teinte
    // fixe presque blanche : celle-ci restait blanche même en thème sombre
    // et rendait le bouton illisible / incohérent avec le reste de l'UI.
    final bgColor = iconColor.withValues(alpha: isDark ? 0.20 : 0.08);
    final borderColor = iconColor.withValues(alpha: isDark ? 0.45 : 0.25);
    final labelColor = isDark ? Colors.white : iconColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor)),
                  Text(
                    sublabel,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: iconColor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _CopyNumberRow extends StatelessWidget {
  final String label;
  final String numberDisplay;
  final String numberDial;
  final Color color;
  final void Function(String text) onCopy;

  const _CopyNumberRow({
    required this.label,
    required this.numberDisplay,
    required this.numberDial,
    required this.color,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              '$label : $numberDisplay',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () => onCopy(numberDial),
            icon: const Icon(Icons.copy, size: 13),
            label: const Text('Copier', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      );
}
