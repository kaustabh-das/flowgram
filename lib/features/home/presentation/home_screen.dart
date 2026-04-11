import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

// ── Mock data ──────────────────────────────────────────────────────────────

class _FilterItem {
  const _FilterItem({required this.name});
  final String name;
}

const _filters = [
  _FilterItem(name: 'All'),
  _FilterItem(name: '🎬 Movie colors'),
  _FilterItem(name: '✨ Aesthetics'),
  _FilterItem(name: '❤️ Favorites'),
];

// Instead of colored squares, we will use mock network images or asset paths later.
// We'll use simple colors as placeholders but in large vertical card format.
final _recentColors = [
  [const Color(0xFF1A1A2E), const Color(0xFF9B5DE5)],
  [const Color(0xFF0D1B2A), const Color(0xFF00D4FF)],
  [const Color(0xFF2D1B00), const Color(0xFFFFB347)],
  [const Color(0xFF0A0A0A), const Color(0xFFE040FB)],
];

// ── Screen ─────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Dark solid prequel bg
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Bar
            _PrequelAppBar(topPad: topPad),

            // Categories
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, i) => _PrequelCategoryChip(
                  filter: _filters[i],
                  isSelected: _selectedFilter == i,
                  onTap: () => setState(() => _selectedFilter = i),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Hero Banner
            _PrequelHeroBanner(onTap: () => context.push(AppRoutes.editor)),

            const SizedBox(height: 32),

            // Section 1
            _SectionHeader(title: 'Popular FX & filters', subtitle: 'Explore the trendiest effects and filters that everyone loves using'),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (context, i) => _VerticalCard(colors: _recentColors[i], index: i),
              ),
            ),

            const SizedBox(height: 32),

            // Section 2
            _SectionHeader(title: 'New', subtitle: null),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (context, i) => _VerticalCard(
                  colors: _recentColors[(i + 2) % _recentColors.length], 
                  index: i + 4,
                  aspectRatio: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Components ─────────────────────────────────────────────────────────────

class _PrequelAppBar extends StatelessWidget {
  const _PrequelAppBar({required this.topPad});
  final double topPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPad + 12, left: 16, right: 16, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // PRO Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.black, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'PRO',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),

          // Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Flowgram',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB347),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),

          // Icons
          Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 16),
              const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrequelCategoryChip extends StatelessWidget {
  const _PrequelCategoryChip({required this.filter, required this.isSelected, required this.onTap});
  final _FilterItem filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          filter.name,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PrequelHeroBanner extends StatelessWidget {
  const _PrequelHeroBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF202020), 
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1515347619362-e9d6d1b73e51?q=80&w=1200&auto=format&fit=crop'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'sensual', 
              style: TextStyle(
                fontFamily: 'cursive', 
                fontSize: 64,
                color: Color(0xFFFFE4E1),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFDAB9), Color(0xFFEEDC82)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Try now',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ]
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Text('All', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.white, size: 14),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({required this.colors, required this.index, this.aspectRatio = 0.6});
  final List<Color> colors;
  final int index;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280 * aspectRatio,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.5), size: 40),
      ),
    );
  }
}
