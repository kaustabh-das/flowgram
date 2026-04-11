import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/template_repository.dart';
import '../domain/collage_layout.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen>
    with SingleTickerProviderStateMixin {
  int _selectedCategory = 0;
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<TemplateModel> _getFiltered(TemplateRepository repo) {
    if (repo.categories.isEmpty) return [];
    
    // Add "All" manually if not present, but our original static had "All".
    // For simplicity, we filter by exact category or show all if index == 0.
    // The JSON categories are ["Minimal", "Carousel", ...].
    // Let's prepend "All" visually in the UI.
    
    if (_selectedCategory == 0) return repo.templates;
    
    // Ensure index bounds
    if (_selectedCategory - 1 < repo.categories.length) {
      final cat = repo.categories[_selectedCategory - 1];
      return repo.templates.where((t) => t.category == cat).toList();
    }
    return repo.templates;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final initAsync = ref.watch(templatesInitializationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Solid dark prequel bg
      body: initAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
        error: (err, stack) => Center(child: Text('Error loading templates: $err', style: const TextStyle(color: Colors.white))),
        data: (_) {
          final repo = ref.read(templateRepositoryProvider);
          final categoriesWithAll = ['All', ...repo.categories];
          final filtered = _getFiltered(repo);

          return Column(
            children: [
              // ── App bar ─────────────────────────────────────────
              _TemplatesAppBar(topPad: topPad),

              // ── Category chips ──────────────────────────────────
              _CategoryChips(
                categories: categoriesWithAll,
                selectedIndex: _selectedCategory,
                onSelect: (i) => setState(() => _selectedCategory = i),
              ),

              const SizedBox(height: 16),

              // ── Template grid ────────────────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _fadeCtrl,
                  child: _TemplateGrid(
                    templates: filtered,
                    onUse: (template) {
                      context.push('${AppRoutes.storyEditor}?layoutId=${template.id}&filterName=');
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


// ── App Bar ──────────────────────────────────────────────────────────────────

class _TemplatesAppBar extends StatelessWidget {
  const _TemplatesAppBar({required this.topPad});
  final double topPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPad + 8, left: 20, right: 20, bottom: 12),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.accentGradient.createShader(b),
            blendMode: BlendMode.srcIn,
            child: const Icon(Icons.grid_view_rounded, size: 26),
          ),
          const SizedBox(width: 10),
          Text(
            'Templates',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const Spacer(),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: 12,
            blur: 8,
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Search',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
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

// ── Category Chips ────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isSelected ? AppColors.accentGradient : null,
                color: isSelected ? null : AppColors.surfaceMid,
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppColors.divider,
                        width: 1,
                      ),
              ),
              child: Text(
                categories[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Template Grid ─────────────────────────────────────────────────────────────

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({
    required this.templates,
    required this.onUse,
  });

  final List<TemplateModel> templates;
  final ValueChanged<TemplateModel> onUse;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.layers_clear_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No templates in this category',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: templates.length,
      itemBuilder: (context, i) => _TemplateCard(
        template: templates[i],
        index: i,
        onUse: () => onUse(templates[i]),
      ),
    );
  }
}

// ── Template Card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  const _TemplateCard({
    required this.template,
    required this.index,
    required this.onUse,
  });

  final TemplateModel template;
  final int index;
  final VoidCallback onUse;

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;

    // Generate gradient based on background color
    final HSLColor baseColor = HSLColor.fromColor(template.backgroundColor);
    final isDark = template.backgroundColor.computeLuminance() < 0.5;
    
    // Create a dynamic gradient depending on luminance
    final gradientColors = [
      template.backgroundColor,
      baseColor.withLightness((baseColor.lightness + (isDark ? 0.1 : -0.1)).clamp(0.0, 1.0)).toColor(),
    ];

    return GestureDetector(
      onTapDown: (_) {
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onUse();
      },
      onTapCancel: () {
        _ctrl.reverse();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative geometry
              _TemplatePattern(seed: widget.index),

              // Center icon
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.panorama_rounded, color: Colors.white70, size: 28),
                ),
              ),

              // Multiple frames indicator
              if (template.frames > 1)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.accentCyan,
                    ),
                    child: Text(
                      '${template.frames} FRAMES',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

              // Bottom label
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            template.category,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: AppColors.accentGradient,
                            ),
                            child: const Text(
                              'Use Template',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Decorative pattern for templates ─────────────────────────────────────────

class _TemplatePattern extends StatelessWidget {
  const _TemplatePattern({required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: _PatternPainter(seed: seed),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed * 31 + 7);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height * 0.6;
      final r = 40.0 + rng.nextDouble() * 60;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = size.height * (0.15 + i * 0.18) * rng.nextDouble();
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), linePaint);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.seed != seed;
}
