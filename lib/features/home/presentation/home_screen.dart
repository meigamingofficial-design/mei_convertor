import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/mei_states.dart';
import '../../../routing/app_router.dart';
import '../widgets/home_feature_grid.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/home_quick_convert_hero.dart';
import '../widgets/home_recent_files_section.dart';

/// Main home screen — the entry point of Mei Convertor
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
      body: SafeArea(
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
                  MeiSectionHeader(
                    title: ref.tr('home_section_tools'),
                    trailing: TextButton(
                      onPressed: () => context.push(MeiRoutes.allTools),
                      child: Text(ref.tr('home_view_all')),
                    ),
                  ),
                  const Gap(MeiSpacing.md),
                  const HomeFeatureGrid(),
                  const Gap(MeiSpacing.xxl),

                  // Recent Files
                  MeiSectionHeader(
                    title: ref.tr('home_section_recent'),
                    trailing: TextButton(
                      onPressed: () => context.push(MeiRoutes.recentFiles),
                      child: Text(ref.tr('home_see_all')),
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
                child: const Icon(
                  Icons.transform_rounded,
                  color: MeiColors.white,
                  size: 18,
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
