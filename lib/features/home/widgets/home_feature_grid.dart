import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/mei_card.dart';
import '../../../routing/app_router.dart';

/// Feature tiles grid on home screen
class HomeFeatureGrid extends ConsumerWidget {
  const HomeFeatureGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Row containing PDF Tools and Documents side-by-side (on top)
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.03,
                child: MeiFeatureTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: ref.tr('all_tools_pdf_title'),
                  subtitle: ref.tr('home_tile_pdf_sub'),
                  accentColor: MeiColors.pdfRedDeep,
                  accentBackground: MeiColors.pdfRedLight,
                  badge: 'PDF',
                  onTap: () => context.push(MeiRoutes.pdfTools),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
            ),
            const SizedBox(width: MeiSpacing.md),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.03,
                child: MeiFeatureTile(
                  icon: Icons.description_rounded,
                  title: ref.tr('all_tools_doc_title'),
                  subtitle: ref.tr('home_tile_doc_sub'),
                  accentColor: MeiColors.docGreenDeep,
                  accentBackground: MeiColors.docGreenLight,
                  badge: 'TXT DOCX',
                  onTap: () => context.push(MeiRoutes.documents),
                ).animate(delay: 350.ms).fadeIn(duration: 400.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MeiSpacing.md),
        // 2. Featured Full-Width Card (Image Tools) (at bottom)
        MeiFeatureTile(
          icon: Icons.image_rounded,
          title: ref.tr('all_tools_img_title'),
          subtitle: ref.tr('home_tile_img_sub'),
          accentColor: MeiColors.imageBlueDeep,
          accentBackground: MeiColors.imageBlueLight,
          badge: 'JPG PNG WEBP',
          onTap: () => context.push(MeiRoutes.imageTools),
        ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(
              begin: 0.1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }
}
