import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

// ── Mock data ──────────────────────────────────────────────────────────────

class _FilterItem {
  const _FilterItem({required this.name, required this.gradient, required this.icon});
  final String name;
  final Gradient gradient;
  final IconData icon;
}

const _filters = [
  _FilterItem(
    name: 'Cinematic',
    icon: Icons.movie_filter_rounded,
    gradient: LinearGradient(
      colors: [Color(0xFF9B5DE5), Color(0xFF6A0DAD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _FilterItem(
    name: 'Moody',
    icon: Icons.wb_twilight_rounded,
    gradient: LinearGradient(
      colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _FilterItem(
    name: 'Golden',
    icon: Icons.wb_sunny_rounded,
    gradient: LinearGradient(
      colors: [Color(0xFFFFB347), Color(0xFFFF7043)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _FilterItem(
    name: 'Neon',
    icon: Icons.electric_bolt_rounded,
    gradient: LinearGradient(
      colors: [Color(0xFF00D4FF), Color(0xFF9B5DE5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _FilterItem(
    name: 'Film',
    icon: Icons.camera_roll_rounded,
    gradient: LinearGradient(
      colors: [Color(0xFF3D5A80), Color(0xFF293241)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  _FilterItem(
    name: 'Dreamy',
    icon: Icons.cloud_rounded,
    gradient: LinearGradient(
      colors: [Color(0xFFE040FB), Color(0xFF7E57C2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
];

final _recentColors = [
  [const Color(0xFF1A1A2E), const Color(0xFF9B5DE5)],
  [const Color(0xFF0D1B2A), const Color(0xFF00D4FF)],
  [const Color(0xFF2D1B00), const Color(0xFFFFB347)],
  [const Color(0xFF0A0A0A), const Color(0xFFE040FB)],
  [const Color(0xFF1C0A2E), const Color(0xFF6A0DAD)],
  [const Color(0xFF0A1A1A), const Color(0xFF30D158)],
];

// ── Screen ─────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero header ─────────────────────────────────────────
            _HeroHeader(
              topPad: topPad,
              fadeAnim: _headerFade,
              slideAnim: _headerSlide,
              onEditorTap: () => context.go(AppRoutes.editor),
              onTemplatesTap: () => context.go(AppRoutes.templates),
            ),

            const SizedBox(height: 28),

            // ── Featured Filters ────────────────────────────────────
            _SectionHeader(title: 'Featured Filters', onSeeAll: () {}),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                itemBuilder: (context, i) => _FilterChip(
                  filter: _filters[i],
                  isSelected: _selectedFilter == i,
                  onTap: () => setState(() => _selectedFilter = i),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Quick Actions ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.add_photo_alternate_rounded,
                      label: 'New Edit',
                      gradient: AppColors.accentGradient,
                      onTap: () => context.go(AppRoutes.editor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.grid_view_rounded,
                      label: 'Templates',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF007AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => context.go(AppRoutes.templates),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Recently Edited ──────────────────────────────────────
            _SectionHeader(title: 'Recently Edited', onSeeAll: () {}),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: _recentColors.length,
              itemBuilder: (context, i) => _RecentCard(
                colors: _recentColors[i],
                index: i,
                onTap: () => context.go(AppRoutes.editor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.topPad,
    required this.fadeAnim,
    required this.slideAnim,
    required this.onEditorTap,
    required this.onTemplatesTap,
  });

  final double topPad;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final VoidCallback onEditorTap;
  final VoidCallback onTemplatesTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: topPad + 16, left: 20, right: 20, bottom: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF0A0A0A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Ambient orbs
          Positioned(
            top: -20,
            right: -30,
            child: _AmbientOrb(
              color: AppColors.accentPurple.withValues(alpha: 0.18),
              size: 180,
            ),
          ),
          Positioned(
            top: 40,
            left: -40,
            child: _AmbientOrb(
              color: AppColors.accentCyan.withValues(alpha: 0.10),
              size: 140,
            ),
          ),
          // Content
          SlideTransition(
            position: slideAnim,
            child: FadeTransition(
              opacity: fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    'Good evening ✨',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  // Title with gradient
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.accentGradient.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      'Flowgram',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create. Edit. Flow.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                  const SizedBox(height: 24),
                  // CTA pill
                  GestureDetector(
                    onTap: onEditorTap,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      borderRadius: 16,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0x339B5DE5),
                          Color(0x2200D4FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.accentGradient.createShader(b),
                            blendMode: BlendMode.srcIn,
                            child: const Icon(Icons.add_rounded, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Start New Edit',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ───────────────────────────────────────────────────────

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: ShaderMask(
              shaderCallback: (b) => AppColors.accentGradient.createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(
                'See all',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final _FilterItem filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: filter.gradient,
          border: isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (filter.gradient as LinearGradient)
                        .colors
                        .first
                        .withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(filter.icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              filter.name,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.colors,
    required this.index,
    required this.onTap,
  });

  final List<Color> colors;
  final int index;
  final VoidCallback onTap;

  static const _labels = ['Portrait', 'Landscape', 'Story', 'Reel', 'Abstract', 'Minimal'];
  static const _times = ['2h ago', 'Yesterday', '3 days ago', 'Last week', '2 weeks ago', '1 month ago'];

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative pattern
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              left: -10,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Edit icon
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
              ),
            ),
            // Bottom info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labels[index % _labels.length],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _times[index % _times.length],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
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
    );
  }
}
