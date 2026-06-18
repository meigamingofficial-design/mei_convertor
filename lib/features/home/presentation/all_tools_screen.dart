import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../routing/app_router.dart';

class ToolItem {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final String category;
  final Color accentColor;
  final Color accentBackground;
  final String route;
  final String? badge;

  const ToolItem({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.category,
    required this.accentColor,
    required this.accentBackground,
    required this.route,
    this.badge,
  });
}

/// All Tools screen listing all available tools in the application with category filters and search
class AllToolsScreen extends ConsumerStatefulWidget {
  const AllToolsScreen({super.key});

  @override
  ConsumerState<AllToolsScreen> createState() => _AllToolsScreenState();
}

class _AllToolsScreenState extends ConsumerState<AllToolsScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isGridView = true;
  String _searchQuery = '';

  final List<String> _categories = ['All', 'Image', 'PDF', 'Documents'];

  final List<ToolItem> _tools = const [
    ToolItem(
      icon: Icons.swap_horiz_rounded,
      titleKey: 'tool_convert_image_title',
      descriptionKey: 'tool_convert_image_desc',
      category: 'Image',
      accentColor: MeiColors.imageBlueDeep,
      accentBackground: MeiColors.imageBlueLight,
      route: '${MeiRoutes.imageTools}?tab=convert',
      badge: 'JPG PNG WEBP',
    ),
    ToolItem(
      icon: Icons.compress_rounded,
      titleKey: 'tool_compress_image_title',
      descriptionKey: 'tool_compress_image_desc',
      category: 'Image',
      accentColor: MeiColors.imageBlueDeep,
      accentBackground: MeiColors.imageBlueLight,
      route: '${MeiRoutes.imageTools}?tab=compress',
      badge: 'COMPRESS',
    ),
    ToolItem(
      icon: Icons.aspect_ratio_rounded,
      titleKey: 'tool_resize_image_title',
      descriptionKey: 'tool_resize_image_desc',
      category: 'Image',
      accentColor: MeiColors.imageBlueDeep,
      accentBackground: MeiColors.imageBlueLight,
      route: '${MeiRoutes.imageTools}?tab=resize',
      badge: 'RESIZE',
    ),
    ToolItem(
      icon: Icons.picture_as_pdf_rounded,
      titleKey: 'tool_images_to_pdf_title',
      descriptionKey: 'tool_images_to_pdf_desc',
      category: 'PDF',
      accentColor: MeiColors.pdfRedDeep,
      accentBackground: MeiColors.pdfRedLight,
      route: '${MeiRoutes.pdfTools}?tab=imagesToPdf',
      badge: 'IMAGES → PDF',
    ),
    ToolItem(
      icon: Icons.compress_rounded,
      titleKey: 'tool_compress_pdf_title',
      descriptionKey: 'tool_compress_pdf_desc',
      category: 'PDF',
      accentColor: MeiColors.pdfRedDeep,
      accentBackground: MeiColors.pdfRedLight,
      route: '${MeiRoutes.pdfTools}?tab=compress',
      badge: 'COMPRESS',
    ),
    ToolItem(
      icon: Icons.call_merge_rounded,
      titleKey: 'tool_merge_pdf_title',
      descriptionKey: 'tool_merge_pdf_desc',
      category: 'PDF',
      accentColor: MeiColors.pdfRedDeep,
      accentBackground: MeiColors.pdfRedLight,
      route: '${MeiRoutes.pdfTools}?tab=merge',
      badge: 'PDF',
    ),
    ToolItem(
      icon: Icons.content_cut_rounded,
      titleKey: 'tool_split_pdf_title',
      descriptionKey: 'tool_split_pdf_desc',
      category: 'PDF',
      accentColor: MeiColors.pdfRedDeep,
      accentBackground: MeiColors.pdfRedLight,
      route: '${MeiRoutes.pdfTools}?tab=split',
      badge: 'PDF',
    ),
    ToolItem(
      icon: Icons.notes_rounded,
      titleKey: 'tool_txt_to_pdf_title',
      descriptionKey: 'tool_txt_to_pdf_desc',
      category: 'Documents',
      accentColor: MeiColors.docGreenDeep,
      accentBackground: MeiColors.docGreenLight,
      route: '${MeiRoutes.documents}?tab=toPdf',
      badge: 'TXT',
    ),
    ToolItem(
      icon: Icons.description_rounded,
      titleKey: 'tool_txt_to_docx_title',
      descriptionKey: 'tool_txt_to_docx_desc',
      category: 'Documents',
      accentColor: MeiColors.docGreenDeep,
      accentBackground: MeiColors.docGreenLight,
      route: '${MeiRoutes.documents}?tab=toDocx',
      badge: 'DOCX',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ToolItem> _filteredTools(WidgetRef ref) {
    return _tools.where((tool) {
      final matchesCategory = _selectedCategory == 'All' || tool.category == _selectedCategory;
      final title = ref.tr(tool.titleKey);
      final desc = ref.tr(tool.descriptionKey);
      final matchesSearch = title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          desc.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  String _categoryDisplayName(WidgetRef ref, String cat) {
    switch (cat) {
      case 'All':
        return ref.tr('cat_all');
      case 'Image':
        return ref.tr('cat_image');
      case 'PDF':
        return ref.tr('cat_pdf');
      case 'Documents':
        return ref.tr('cat_documents');
      default:
        return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTools(ref);

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(
          ref.tr('all_tools_title'),
          style: MeiTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: MeiColors.textSecondary,
            ),
            tooltip: _isGridView ? ref.tr('all_tools_switch_list') : ref.tr('all_tools_switch_grid'),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const Gap(MeiSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MeiSpacing.lg,
                MeiSpacing.sm,
                MeiSpacing.lg,
                MeiSpacing.md,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: MeiColors.white,
                  borderRadius: MeiRadius.xlAll,
                  border: Border.all(
                    color: MeiColors.border.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x041C1A18),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: MeiTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: ref.tr('all_tools_search_hint'),
                    hintStyle: MeiTextStyles.bodyMedium.copyWith(color: MeiColors.textTertiary),
                    prefixIcon: const Icon(Icons.search_rounded, color: MeiColors.textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: MeiColors.textSecondary, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MeiSpacing.lg,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // Category filter chips
            SizedBox(
              height: 38,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: MeiSpacing.lg),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: MeiSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? MeiColors.sakuraDeep : MeiColors.white,
                          borderRadius: MeiRadius.fullAll,
                          border: Border.all(
                            color: isSelected ? MeiColors.sakuraDeep : MeiColors.border.withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: MeiColors.sakuraDeep.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x041C1A18),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  )
                                ],
                        ),
                        child: Center(
                          child: Text(
                            _categoryDisplayName(ref, cat),
                            style: MeiTextStyles.labelMedium.copyWith(
                              color: isSelected ? MeiColors.white : MeiColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Gap(MeiSpacing.lg),

            // Tools List/Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: MeiColors.gray100,
                              borderRadius: MeiRadius.xlAll,
                            ),
                            child: const Icon(Icons.search_off_rounded, size: 28, color: MeiColors.gray400),
                          ),
                          const Gap(MeiSpacing.md),
                          Text(
                            ref.tr('all_tools_no_tools'),
                            style: MeiTextStyles.headlineSmall.copyWith(color: MeiColors.textPrimary),
                          ),
                          const Gap(MeiSpacing.xs),
                          Text(
                            ref.tr('all_tools_adjust_search'),
                            style: MeiTextStyles.bodySmall,
                          ),
                        ],
                      ).animate().fadeIn(duration: 300.ms),
                    )
                  : _isGridView
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            MeiSpacing.lg,
                            MeiSpacing.md,
                            MeiSpacing.lg,
                            MeiSpacing.massive,
                          ),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: MeiSpacing.md,
                            mainAxisSpacing: MeiSpacing.md,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final tool = filtered[index];
                            return _GridViewToolCard(
                              tool: tool,
                              title: ref.tr(tool.titleKey),
                              description: ref.tr(tool.descriptionKey),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (index * 40).ms)
                                .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            MeiSpacing.lg,
                            MeiSpacing.md,
                            MeiSpacing.lg,
                            MeiSpacing.massive,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final tool = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: MeiSpacing.md),
                              child: _ListViewToolCard(
                                tool: tool,
                                title: ref.tr(tool.titleKey),
                                description: ref.tr(tool.descriptionKey),
                              )
                                  .animate()
                                  .fadeIn(duration: 300.ms, delay: (index * 40).ms)
                                  .slideX(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridViewToolCard extends StatefulWidget {
  final ToolItem tool;
  final String title;
  final String description;

  const _GridViewToolCard({
    required this.tool,
    required this.title,
    required this.description,
  });

  @override
  State<_GridViewToolCard> createState() => _GridViewToolCardState();
}

class _GridViewToolCardState extends State<_GridViewToolCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        context.push(widget.tool.route);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: MeiColors.white,
            borderRadius: MeiRadius.lgAll,
            border: Border.all(
              color: widget.tool.accentColor.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tool.accentColor.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x041C1A18),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.tool.accentBackground,
                          widget.tool.accentBackground.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: MeiRadius.mdAll,
                      border: Border.all(
                        color: widget.tool.accentColor.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      widget.tool.icon,
                      color: widget.tool.accentColor,
                      size: 18,
                    ),
                  ),
                  if (widget.tool.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.tool.accentBackground.withValues(alpha: 0.8),
                        borderRadius: MeiRadius.fullAll,
                        border: Border.all(
                          color: widget.tool.accentColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.tool.badge!,
                        style: MeiTextStyles.labelSmall.copyWith(
                          color: widget.tool.accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const Gap(MeiSpacing.md),
              Text(
                widget.title,
                style: MeiTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MeiColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Gap(4),
              Expanded(
                child: Text(
                  widget.description,
                  style: MeiTextStyles.bodySmall.copyWith(
                    color: MeiColors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListViewToolCard extends StatefulWidget {
  final ToolItem tool;
  final String title;
  final String description;

  const _ListViewToolCard({
    required this.tool,
    required this.title,
    required this.description,
  });

  @override
  State<_ListViewToolCard> createState() => _ListViewToolCardState();
}

class _ListViewToolCardState extends State<_ListViewToolCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        context.push(widget.tool.route);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(MeiSpacing.lg),
          decoration: BoxDecoration(
            color: MeiColors.white,
            borderRadius: MeiRadius.lgAll,
            border: Border.all(
              color: widget.tool.accentColor.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tool.accentColor.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              const BoxShadow(
                color: Color(0x031C1A18),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.tool.accentBackground,
                      widget.tool.accentBackground.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: MeiRadius.mdAll,
                  border: Border.all(
                    color: widget.tool.accentColor.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  widget.tool.icon,
                  color: widget.tool.accentColor,
                  size: 20,
                ),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: MeiTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: MeiColors.textPrimary,
                          ),
                        ),
                        if (widget.tool.badge != null) ...[
                          const Gap(MeiSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.tool.accentBackground.withValues(alpha: 0.8),
                              borderRadius: MeiRadius.fullAll,
                              border: Border.all(
                                color: widget.tool.accentColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.tool.badge!,
                              style: MeiTextStyles.labelSmall.copyWith(
                                color: widget.tool.accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(4),
                    Text(
                      widget.description,
                      style: MeiTextStyles.bodySmall.copyWith(
                        color: MeiColors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(MeiSpacing.sm),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: MeiColors.gray300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
