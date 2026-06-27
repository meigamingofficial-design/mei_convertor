import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/providers/package_info_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/mei_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('settings_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: MeiSpacing.pageInsets,
          physics: const BouncingScrollPhysics(),
          children: [
            const Gap(MeiSpacing.lg),

            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: MeiSpacing.xl,
                vertical: MeiSpacing.xxl,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MeiColors.sakuraLighter, Color(0xFFF7EEF5)],
                ),
                borderRadius: MeiRadius.xlAll,
                border: Border.all(color: MeiColors.sakuraLight, width: 1),
                boxShadow: MeiShadows.soft,
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [MeiColors.sakura, MeiColors.lavender],
                      ),
                      borderRadius: MeiRadius.lgAll,
                      boxShadow: MeiShadows.soft,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        MeiAssets.logoTransparent,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Gap(MeiSpacing.md),
                  Text(
                    ref.tr('app_name'),
                    style: MeiTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: MeiColors.textPrimary,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    ref.tr('settings_sub'),
                    style: MeiTextStyles.bodySmall.copyWith(
                      color: MeiColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),

            const Gap(MeiSpacing.xxl),

            // --- Preferences ---
            Text(
              ref.tr('settings_header_preferences'),
              style: MeiTextStyles.labelSmall.copyWith(
                color: MeiColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Gap(MeiSpacing.md),

            // Language selector card
            MeiCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.language_rounded, color: MeiColors.sakuraDeep),
                title: Text(ref.tr('settings_lang')),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: MeiColors.sakuraLighter,
                    borderRadius: MeiRadius.fullAll,
                  ),
                  child: Text(
                    currentLang.displayName,
                    style: MeiTextStyles.labelMedium.copyWith(
                      color: MeiColors.sakuraDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () => _showLanguageDialog(context, ref),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 50.ms),

            const Gap(MeiSpacing.xl),

            // --- Legal ---
            Text(
              ref.tr('settings_header_legal'),
              style: MeiTextStyles.labelSmall.copyWith(
                color: MeiColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Gap(MeiSpacing.md),

            // Privacy & Terms cards
            MeiCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: MeiColors.sakuraDeep),
                    title: Text(ref.tr('settings_privacy')),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegalViewerScreen(
                          title: ref.tr('settings_privacy'),
                          assetPath: currentLang == AppLanguage.en
                              ? 'assets/legal/privacy_policy.md'
                              : 'assets/legal/privacy_policy_${currentLang.code}.md',
                          language: currentLang,
                        ),
                      ),
                    ),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.gavel_rounded, color: MeiColors.sakuraDeep),
                    title: Text(ref.tr('settings_terms')),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegalViewerScreen(
                          title: ref.tr('settings_terms'),
                          assetPath: currentLang == AppLanguage.en
                              ? 'assets/legal/terms_and_conditions.md'
                              : 'assets/legal/terms_and_conditions_${currentLang.code}.md',
                          language: currentLang,
                        ),
                      ),
                    ),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: MeiColors.sakuraDeep),
                    title: Text(ref.tr('settings_licenses')),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: ref.tr('app_name'),
                      applicationVersion: '${packageInfo.version} (${packageInfo.buildNumber})',
                      applicationLegalese: '© 2026 ${ref.tr('settings_dev_value')}',
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const Gap(MeiSpacing.xl),

            // --- About ---
            Text(
              ref.tr('settings_header_about'),
              style: MeiTextStyles.labelSmall.copyWith(
                color: MeiColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Gap(MeiSpacing.md),

            MeiCard(
              padding: const EdgeInsets.symmetric(
                horizontal: MeiSpacing.lg,
                vertical: MeiSpacing.md,
              ),
              child: Column(
                children: [
                  _InfoRow(label: ref.tr('settings_dev'), value: ref.tr('settings_dev_value')),
                  const Gap(MeiSpacing.md),
                  _InfoRow(label: ref.tr('settings_contact'), value: ref.tr('settings_contact_value')),
                  const Gap(MeiSpacing.md),
                  _InfoRow(
                    label: ref.tr('settings_version'),
                    value: '${packageInfo.version} (${packageInfo.buildNumber})',
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

            const Gap(MeiSpacing.massive),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('settings_lang')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((lang) {
            final isSelected = ref.read(localeProvider) == lang;
            return ListTile(
              title: Text(lang.displayName),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: MeiColors.sakuraDeep)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLanguage(lang);
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ref.tr('cancel')),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textSecondary),
        ),
        const Gap(MeiSpacing.md),
        Expanded(
          child: Text(
            value,
            style: MeiTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: MeiColors.textPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ── Custom Markdown Document Viewer ──────────────────────────────────────────

class LegalViewerScreen extends ConsumerWidget {
  const LegalViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
    required this.language,
  });

  final String title;
  final String assetPath;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading document: ${snapshot.error}'));
          }
          return SingleChildScrollView(
            padding: MeiSpacing.pageInsets,
            physics: const BouncingScrollPhysics(),
            child: MeiCard(
              padding: MeiSpacing.cardPadding,
              child: _MeiMarkdownViewer(
                text: snapshot.data ?? '',
                language: language,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MeiMarkdownViewer extends ConsumerWidget {
  const _MeiMarkdownViewer({
    required this.text,
    required this.language,
  });
  final String text;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = text.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const Gap(MeiSpacing.xs));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: MeiSpacing.md, bottom: MeiSpacing.sm),
          child: Text(
            trimmed.substring(2),
            style: MeiTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: MeiSpacing.md, bottom: MeiSpacing.sm),
          child: Text(
            trimmed.substring(3),
            style: MeiTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600),
          ),
        ));
      } else if (trimmed.startsWith('---')) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: MeiSpacing.md),
          child: Divider(),
        ));
      } else if (trimmed.startsWith('- ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MeiColors.sakuraDeep)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _parseInlineFormatting(context, ref, trimmed.substring(2)),
                    style: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textSecondary, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              children: _parseInlineFormatting(context, ref, trimmed),
              style: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textSecondary, height: 1.5),
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<InlineSpan> _parseInlineFormatting(BuildContext context, WidgetRef ref, String input) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*|\[(.*?)\]\((.*?)\)');
    int start = 0;

    for (final match in regex.allMatches(input)) {
      if (match.start > start) {
        spans.add(TextSpan(text: input.substring(start, match.start)));
      }

      final boldText = match.group(1);
      final linkText = match.group(2);
      final linkUrl = match.group(3);

      if (boldText != null) {
        spans.add(TextSpan(
          text: boldText,
          style: const TextStyle(fontWeight: FontWeight.bold, color: MeiColors.textPrimary),
        ));
      } else if (linkText != null && linkUrl != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                if (linkUrl.contains('privacy_policy')) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LegalViewerScreen(
                        title: ref.tr('settings_privacy'),
                        assetPath: language == AppLanguage.en
                            ? 'assets/legal/privacy_policy.md'
                            : 'assets/legal/privacy_policy_${language.code}.md',
                        language: language,
                      ),
                    ),
                  );
                } else if (linkUrl.contains('terms_and_conditions')) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LegalViewerScreen(
                        title: ref.tr('settings_terms'),
                        assetPath: language == AppLanguage.en
                            ? 'assets/legal/terms_and_conditions.md'
                            : 'assets/legal/terms_and_conditions_${language.code}.md',
                        language: language,
                      ),
                    ),
                  );
                }
              },
              child: Text(
                linkText,
                style: const TextStyle(
                  color: MeiColors.sakuraDeep,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      }
      start = match.end;
    }

    if (start < input.length) {
      spans.add(TextSpan(text: input.substring(start)));
    }

    return spans;
  }
}
