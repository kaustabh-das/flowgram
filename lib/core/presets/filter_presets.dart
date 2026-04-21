/// Flowgram built-in filter presets.
///
/// Each preset is an immutable [ToneParams] constant.
/// Apply them via [ToneEngine.buildFilter] or [ToneEngine.buildFilterList].
///
/// Naming convention: `kPreset<Name>` for constants; use [FilterPreset] as the
/// catalog entry for UI lists (name, description, thumbnail icon).
library;

import 'dart:ui' show Offset;
import 'package:flutter/material.dart';

import '../engine/tone_params.dart';
import '../engine/hsl_params.dart';

// ── Catalog entry ──────────────────────────────────────────────────────────

class FilterPreset {
  const FilterPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.params,
    this.category = PresetCategory.cinematic,
    this.isPremium = false,
  });

  final String id;
  final String name;
  final String description;
  final ToneParams params;
  final PresetCategory category;
  final bool isPremium;
}

enum PresetCategory { cinematic, portrait, landscape, vintage, minimal }

// ── All built-in presets ────────────────────────────────────────────────────

/// Full ordered catalog of built-in presets.
const List<FilterPreset> kBuiltInPresets = [
  FilterPreset(
    id: 'none',
    name: 'Original',
    description: 'No adjustments applied.',
    params: ToneParams(),
    category: PresetCategory.minimal,
  ),
  kPresetMatteFade,
  kPresetGoldenHour,
  kPresetDarkMood,
  kPresetCinematic,
  kPresetSoftGlow,
  kPresetCoolMinimal,
  kPresetVibrantPop,
  kPresetVintageFilm,
  kPresetSunsetBoost,
  kPresetSkinTonePro,
];

// ══════════════════════════════════════════════════════════════════════════════
// MATTE FADE PRESET
// ══════════════════════════════════════════════════════════════════════════════
//
// Goal: soft, low-contrast, faded look with lifted blacks and a cinematic
// matte finish — aesthetic, minimal, modern (Prequel / Instagram style).
//
// Design decisions
// ────────────────
// 1. `fade` (0.52) is the PRIMARY effect — aggressive exponential black lift
//    that creates the signature matte floor without touching midtones.
//
// 2. `blacks` (0.35) adds a *secondary*, linear lift with a slight cool cast
//    to the bottom tones (see `_blacksMatrix`), giving a faint analogue chill.
//
// 3. `contrast` (–0.14) softens without going full flat. We keep 86 % of the
//    original contrast so the image retains depth and dimensionality.
//
// 4. `highlights` (–0.18) gently compresses the top zone around a 0.75 pivot.
//    Combined with `highlightProtection: true`, we get a double shoulder to
//    prevent any hard clipping at bright areas.
//
// 5. `brightness` (+0.08) nudges only the true midtone band (30–70 %)
//    to compensate for the perceived darkening that the desaturation causes.
//
// 6. `shadows` (+0.12) provides the feathered lift of the shadow *zone*,
//    complementary to the flat black floor created by `fade` + `blacks`.
//
// 7. `saturation` (–0.14) and `vibrance` (–0.10): saturation hits all
//    channels equally; vibrance reduces more-saturated colours first,
//    which tones down vivid blues/greens while naturally preserving warm skin
//    (reds get only ~55 % of the vibrance delta per `_vibranceMatrix`).
//
// 8. `warmth` (+0.08): a gentle +amber push that prevents the desaturation
//    from making skin look ashy. Keeps the overall tone neutral-warm rather
//    than cool-grey.
//
// 9. `clarity` (–0.15) and `texture` (–0.10): both reduce local contrast,
//    giving the image a soft, skin-smoothing finish without ghosting.
//
// 10. `grain` (0.22): a moderate organic grain overlay adds the tactile,
//     analogue film quality that distinguishes a premium preset from a basic
//     faded look. Kept below 0.25 to avoid distracting from fine detail.
//
// 11. `toneCurve: ToneCurvePreset.matteFade` activates the engine's built-in
//     matte curve matrix (lifted floor + slight desaturation), which compounds
//     with the explicit `fade`/`blacks` parameters for a richer end result.
//
// 12. `curvePoints`: four Bezier anchor deltas that model the S-curve described
//     in the spec:
//       [0] shadow anchor  → +0.08 (lift blacks)
//       [1] low-mid anchor → –0.03 (very slight toe reduction for depth)
//       [2] high-mid anchor→ –0.04 (compress high-mids softly)
//       [3] highlight anchor→ –0.07 (pull down highlights without clipping)
//     These work ON TOP of toneCurve inside `_buildMatrix`? No — `curvePoints`
//     overrides `toneCurve` in the engine. We therefore set `toneCurve: none`
//     and lean on `curvePoints` alone for the curve pass, keeping the matte
//     character coming from the `fade` + `blacks` params instead.
//
// 13. HSL channel tweaks:
//     • Red: sat –0.10  → prevents oversaturated skin in warm light
//     • Orange: lum +0.12 → brightens mid-tones of skin, golden hour light
//     • Blue: sat –0.18  → tones down electric blue skies / denim
//     • Aqua: sat –0.12  → softens teal in shadows (complements warm push)
//
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetMatteFade = FilterPreset(
  id: 'matte_fade',
  name: 'Matte Fade',
  description:
      'Soft, low-contrast, faded look with lifted blacks and a cinematic matte finish.',
  isPremium: true,
  category: PresetCategory.cinematic,
  params: ToneParams(
    // ── Light ───────────────────────────────────────────────────────────────
    brightness:          0.08,   // gentle midtone lift to counter desaturation
    contrast:           -0.14,   // soft contrast — not flat, not punchy
    highlights:         -0.18,   // compress bright zone (pivot 0.75)
    shadows:             0.12,   // feathered lift of the shadow zone
    whites:             -0.06,   // very gently pull back extreme whites
    blacks:              0.35,   // linear black-point lift (slight cool cast)
    fade:                0.52,   // PRIMARY: exponential black lift → matte floor
    blackPoint:          0.10,   // shifts minimum threshold without detail loss

    // ── Detail ──────────────────────────────────────────────────────────────
    clarity:            -0.15,   // soft local contrast — skin-smoothing finish
    texture:            -0.10,   // reduces micro-detail for a dreamy quality
    grain:               0.22,   // organic film grain (analogue character)
    sharpen:             0.00,   // no sharpening — preserves the soft look

    // ── Color ───────────────────────────────────────────────────────────────
    saturation:         -0.14,   // uniform chroma reduction (all channels)
    vibrance:           -0.10,   // smart sat: protects skin tones (reds –45 %)
    warmth:              0.08,   // neutral-warm to prevent ashy skin

    // ── Protection ──────────────────────────────────────────────────────────
    highlightProtection: true,   // double shoulder → no hard blowout

    // ── Tone curve (Bezier deltas from neutral diagonal) ────────────────────
    // Using curvePoints overrides toneCurve — matte character from fade/blacks.
    toneCurve: ToneCurvePreset.none,
    curvePoints: [
      Offset(0.00,  0.08),   // shadow anchor:   lift blacks gently
      Offset(0.33, -0.03),   // low-mid anchor:  very slight toe pull for depth
      Offset(0.66, -0.04),   // high-mid anchor: soft compression of upper mids
      Offset(1.00, -0.07),   // highlight anchor: recover top end without clipping
    ],

    // ── HSL channel adjustments ─────────────────────────────────────────────
    hslAdjustments: {
      HslColor.red: HslAdjustment(
        saturation: -0.10,        // prevent over-red skin in warm light
      ),
      HslColor.orange: HslAdjustment(
        luminance:   0.12,        // brighten skin/golden-hour midtones
        saturation: -0.05,        // keep oranges slightly subdued
      ),
      HslColor.blue: HslAdjustment(
        saturation: -0.18,        // tone down electric-blue skies / denim
        luminance:   0.04,        // slight brightness keeps blues from going muddy
      ),
      HslColor.aqua: HslAdjustment(
        saturation: -0.12,        // soften teal in shadows (pairs with warmth push)
      ),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 1. GOLDEN HOUR
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetGoldenHour = FilterPreset(
  id: 'golden_hour',
  name: 'Golden Hour',
  description: 'Warm, soft, slightly bright.',
  category: PresetCategory.landscape,
  params: ToneParams(
    exposure: 0.10,
    brightness: 0.15,
    contrast: -0.10,
    highlights: -0.30,
    shadows: 0.25,
    whites: -0.10,
    blacks: 0.10,
    brilliance: 0.25,
    warmth: 0.60,
    vibrance: 0.30,
    saturation: -0.05,
    texture: -0.10,
    clarity: -0.05,
    hslAdjustments: {
      HslColor.orange: HslAdjustment(luminance: 0.15, saturation: 0.20),
      HslColor.yellow: HslAdjustment(hue: -0.15, saturation: 0.30, luminance: 0.10),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 2. DARK MOOD
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetDarkMood = FilterPreset(
  id: 'dark_mood',
  name: 'Dark Mood',
  description: 'Low exposure, high contrast, deep shadows.',
  category: PresetCategory.cinematic,
  params: ToneParams(
    exposure: -0.40,
    contrast: 0.35,
    highlights: -0.20,
    shadows: -0.40,
    whites: -0.15,
    blacks: -0.20,
    fade: 0.15,
    warmth: -0.20,
    vibrance: -0.10,
    saturation: -0.30,
    clarity: 0.30,
    texture: 0.20,
    grain: 0.15,
    hslAdjustments: {
      HslColor.blue: HslAdjustment(saturation: -0.40, luminance: -0.10),
      HslColor.aqua: HslAdjustment(saturation: -0.40),
      HslColor.green: HslAdjustment(saturation: -0.30, luminance: -0.20),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 3. CINEMATIC
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetCinematic = FilterPreset(
  id: 'cinematic',
  name: 'Cinematic',
  description: 'Warm highlights, cool shadows, film-like separation.',
  category: PresetCategory.cinematic,
  params: ToneParams(
    contrast: 0.25,
    highlights: -0.25,
    shadows: 0.15,
    blacks: 0.15,
    fade: 0.20,
    warmth: 0.15,
    vibrance: 0.25,
    saturation: -0.20,
    clarity: 0.15,
    grain: 0.20,
    hslAdjustments: {
      HslColor.orange: HslAdjustment(saturation: 0.25, luminance: 0.10),
      HslColor.blue: HslAdjustment(hue: -0.35, saturation: 0.40, luminance: -0.15),
      HslColor.aqua: HslAdjustment(hue: 0.15, saturation: 0.30),
      HslColor.green: HslAdjustment(saturation: -0.30),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 4. SOFT GLOW
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetSoftGlow = FilterPreset(
  id: 'soft_glow',
  name: 'Soft Glow',
  description: 'Bright, soft, dreamy.',
  category: PresetCategory.portrait,
  params: ToneParams(
    exposure: 0.25,
    contrast: -0.25,
    highlights: -0.40,
    shadows: 0.35,
    whites: -0.20,
    blacks: 0.15,
    fade: 0.25,
    brilliance: 0.15,
    warmth: 0.10,
    vibrance: 0.10,
    saturation: -0.10,
    clarity: -0.50,
    texture: -0.25,
    sharpen: -0.15,
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 5. COOL MINIMAL
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetCoolMinimal = FilterPreset(
  id: 'cool_minimal',
  name: 'Cool Minimal',
  description: 'Clean, slightly cool tone.',
  category: PresetCategory.minimal,
  params: ToneParams(
    exposure: 0.15,
    brightness: 0.10,
    contrast: 0.10,
    highlights: -0.15,
    shadows: 0.15,
    blacks: 0.15,
    warmth: -0.35,
    vibrance: -0.10,
    saturation: -0.40,
    clarity: 0.15,
    texture: 0.05,
    hslAdjustments: {
      HslColor.blue: HslAdjustment(saturation: -0.20, luminance: 0.25),
      HslColor.orange: HslAdjustment(saturation: 0.15, luminance: 0.10),
      HslColor.green: HslAdjustment(saturation: -0.40, luminance: 0.10),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 6. VIBRANT POP
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetVibrantPop = FilterPreset(
  id: 'vibrant_pop',
  name: 'Vibrant Pop',
  description: 'High saturation and vibrance.',
  category: PresetCategory.landscape,
  params: ToneParams(
    exposure: 0.10,
    contrast: 0.30,
    highlights: -0.30,
    shadows: 0.15,
    whites: 0.10,
    blacks: -0.10,
    brilliance: 0.40,
    vibrance: 0.50,
    saturation: 0.20,
    warmth: 0.05,
    clarity: 0.20,
    sharpen: 0.10,
    hslAdjustments: {
      HslColor.red: HslAdjustment(saturation: 0.20, luminance: -0.05),
      HslColor.green: HslAdjustment(saturation: 0.20, luminance: 0.10),
      HslColor.blue: HslAdjustment(saturation: 0.20, luminance: -0.05),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 7. VINTAGE FILM
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetVintageFilm = FilterPreset(
  id: 'vintage_film',
  name: 'Vintage Film',
  description: 'Warm faded tones, reduced saturation.',
  category: PresetCategory.vintage,
  params: ToneParams(
    contrast: -0.30,
    highlights: -0.20,
    shadows: 0.40,
    whites: -0.25,
    blacks: 0.50,
    fade: 0.65,
    blackPoint: 0.15,
    warmth: 0.35,
    vibrance: -0.20,
    saturation: -0.35,
    clarity: -0.20,
    texture: -0.15,
    grain: 0.50,
    hslAdjustments: {
      HslColor.green: HslAdjustment(hue: 0.15, saturation: -0.40),
      HslColor.yellow: HslAdjustment(hue: -0.10, saturation: -0.20),
      HslColor.blue: HslAdjustment(saturation: -0.45, luminance: -0.10),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 8. SUNSET BOOST
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetSunsetBoost = FilterPreset(
  id: 'sunset_boost',
  name: 'Sunset Boost',
  description: 'Strong warm tones, enhanced sky.',
  category: PresetCategory.landscape,
  params: ToneParams(
    exposure: -0.10,
    contrast: 0.15,
    highlights: -0.15,
    shadows: 0.20,
    blacks: -0.10,
    warmth: 0.50,
    vibrance: 0.40,
    saturation: 0.10,
    clarity: 0.20,
    hslAdjustments: {
      HslColor.orange: HslAdjustment(hue: -0.05, saturation: 0.35, luminance: 0.15),
      HslColor.yellow: HslAdjustment(hue: -0.20, saturation: 0.40, luminance: 0.10),
      HslColor.red: HslAdjustment(saturation: 0.25),
      HslColor.blue: HslAdjustment(hue: -0.05, saturation: -0.10, luminance: -0.20),
    },
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 9. SKIN TONE PRO
// ══════════════════════════════════════════════════════════════════════════════

const FilterPreset kPresetSkinTonePro = FilterPreset(
  id: 'skin_tone_pro',
  name: 'Skin Tone Pro',
  description: 'Natural portrait enhancement.',
  category: PresetCategory.portrait,
  params: ToneParams(
    exposure: 0.15,
    contrast: -0.10,
    highlights: -0.25,
    shadows: 0.20,
    whites: -0.10,
    blacks: 0.10,
    warmth: 0.10,
    vibrance: 0.15,
    saturation: -0.05,
    clarity: -0.30,
    texture: -0.20,
    sharpen: 0.15,
    hslAdjustments: {
      HslColor.orange: HslAdjustment(hue: 0.05, saturation: -0.10, luminance: 0.25),
      HslColor.red: HslAdjustment(saturation: -0.05, luminance: 0.10),
      HslColor.yellow: HslAdjustment(saturation: -0.20),
    },
  ),
);
