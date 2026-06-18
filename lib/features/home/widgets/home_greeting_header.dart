import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme.dart';

/// Personalized greeting at the top of the home screen
class HomeGreetingHeader extends ConsumerWidget {
  const HomeGreetingHeader({super.key});

  String _getGreeting(WidgetRef ref) {
    final hour = DateTime.now().hour;
    if (hour < 12) return ref.tr('home_greeting_morning');
    if (hour < 17) return ref.tr('home_greeting_afternoon');
    return ref.tr('home_greeting_evening');
  }

  String _getDate(AppLanguage lang) {
    final localeCode = lang.code;
    return DateFormat('EEEE, d MMMM', localeCode).format(DateTime.now());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getDate(lang),
          style: MeiTextStyles.labelMedium.copyWith(
            color: MeiColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const Gap(MeiSpacing.xs),
        Text(
          '${_getGreeting(ref)} 👋',
          style: MeiTextStyles.displayMedium,
        ),
        const Gap(MeiSpacing.xs),
        Text(
          ref.tr('home_greeting_sub'),
          style: MeiTextStyles.bodyLarge.copyWith(
            color: MeiColors.textSecondary,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideY(begin: 0.15, end: 0, duration: 500.ms, delay: 100.ms, curve: Curves.easeOutCubic);
  }
}
