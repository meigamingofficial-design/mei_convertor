import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../routing/app_router.dart';
import '../../recent_files/providers/history_provider.dart';
import '../widgets/home_feature_grid.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/home_quick_convert_hero.dart';
import '../widgets/home_recent_files_section.dart';

/// Main home screen — the entry point of Mei Converter
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      body: Stack(
        children: [
          // Decorative sakura bloom — top right atmospheric glow
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x22E8A0B4), // sakura pink tint
                    Color(0x00F9F7F5), // transparent
                  ],
                ),
              ),
            ),
          ),
          // Decorative lavender bloom — bottom left
          Positioned(
            bottom: 60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x14B8AECC), // lavender tint
                    Color(0x00F9F7F5),
                  ],
                ),
              ),
            ),
          ),
          // Main scrollable content
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Top App Bar
                const SliverAppBar(
                  pinned: false,
                  floating: true,
                  snap: true,
                  backgroundColor: MeiColors.offWhite,
                  surfaceTintColor: MeiColors.offWhite,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 64,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _HomeAppBar(),
                    collapseMode: CollapseMode.none,
                  ),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    MeiSpacing.lg,
                    MeiSpacing.xs,
                    MeiSpacing.lg,
                    MeiSpacing.massive,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Greeting
                      const HomeGreetingHeader(),
                      const Gap(MeiSpacing.xxl),

                      // Quick Convert Hero Card
                      HomeQuickConvertHero(
                        onTap: () => context.push(MeiRoutes.quickConvert),
                      ),
                      const Gap(MeiSpacing.xxl),

                      // Feature Grid
                      _SectionHeader(
                        title: ref.tr('home_section_tools'),
                        trailing: TextButton(
                          onPressed: () => context.push(MeiRoutes.allTools),
                          style: TextButton.styleFrom(
                            foregroundColor: MeiColors.sakuraDeep,
                            textStyle: MeiTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Text(ref.tr('home_more_tools')),
                        ),
                      ),
                      const Gap(MeiSpacing.md),
                      const HomeFeatureGrid(),
                      const Gap(MeiSpacing.xxl),

                      // Recent Files
                      _SectionHeader(
                        title: ref.tr('home_section_recent'),
                        trailing: ref.watch(historyProvider).maybeWhen(
                              data: (records) => records.isNotEmpty
                                  ? TextButton(
                                      onPressed: () => context.push(MeiRoutes.recentFiles),
                                      style: TextButton.styleFrom(
                                        foregroundColor: MeiColors.sakuraDeep,
                                        textStyle: MeiTextStyles.labelMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      child: Text(ref.tr('home_see_all')),
                                    )
                                  : null,
                              orElse: () => null,
                            ),
                      ),
                      const Gap(MeiSpacing.md),
                      const HomeRecentFilesSection(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MeiSpacing.lg,
        vertical: MeiSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MeiColors.sakura, MeiColors.lavender],
                  ),
                  borderRadius: MeiRadius.smAll,
                  boxShadow: MeiShadows.soft,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    MeiAssets.logoTransparent,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Gap(MeiSpacing.sm),
              Text(
                ref.tr('home_title'),
                style: MeiTextStyles.headlineMedium.copyWith(
                  color: MeiColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              _AppBarIconButton(
                icon: Icons.settings_rounded,
                onTap: () => context.push(MeiRoutes.settings),
                tooltip: ref.tr('settings_title'),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _AppBarIconButton extends StatefulWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_AppBarIconButton> createState() => _AppBarIconButtonState();
}

class _AppBarIconButtonState extends State<_AppBarIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: MeiColors.white,
              borderRadius: MeiRadius.mdAll,
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: MeiColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: const BoxDecoration(
                color: MeiColors.sakura,
                borderRadius: MeiRadius.xsAll,
              ),
            ),
            const Gap(MeiSpacing.sm),
            Text(
              title,
              style: MeiTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}
