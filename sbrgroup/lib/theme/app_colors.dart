import 'package:flutter/material.dart';

/// Central colour palette for the whole Ajna app.
///
/// Change a value HERE and every screen that reads from [AppColors] updates —
/// this is the single place to re-theme the app. Point every screen at these
/// instead of hard-coding colours (the legacy `Color.fromRGBO(6, 73, 105, 1)`
/// appeared ~115 times across `lib/` and has now been fully migrated here).
///
/// ---------------------------------------------------------------------------
/// PALETTE SOURCE — the Ajna logo (`lib/assets/images/ajna.png`)
/// ---------------------------------------------------------------------------
/// The logo is two overlapping chevrons around the third-eye motif. Their exact
/// pixel values were sampled and are kept verbatim below as [brandAzure] and
/// [brandEmerald]; every other brand colour is derived from those two.
///
///   • Azure   #36A2E2  — the blue chevron
///   • Emerald #15DE74  — the green chevron
///
/// Both logo colours are too light to carry white text (azure is only 2.8:1 on
/// white, emerald 1.5:1), so the *interactive* colours are deepened versions:
/// [primary] #1272B8 hits 5.1:1 on white and [success] #0FA958 hits 3.1:1 —
/// safe for filled buttons, chips and large text.
///
/// ---------------------------------------------------------------------------
/// LIGHT ONLY (for now) — but dark-ready
/// ---------------------------------------------------------------------------
/// The app currently ships **light mode only**. Every neutral is exposed as a
/// plain static getter (`AppColors.surface`, `AppColors.bg`, …) that reads the
/// single [isDark] flag below, so screens carry **no per-screen theme state at
/// all** — no `_isDark` field, no `_loadTheme()`, no SharedPreferences read.
///
/// The dark values are already filled in. When dark mode is scheduled, the only
/// work is: read the pref into [isDark] at startup, and rebuild on toggle.
/// **No screen file has to change.** That is the whole point of routing every
/// colour through this file now.
class AppColors {
  AppColors._(); // no instances — static only.

  /// Master light/dark switch. Left `false` — the app is light-only today.
  /// Flip this (plus a rebuild) to light up the dark ramp below; see the class
  /// doc. Nothing else in the app needs to change.
  static bool isDark = false;

  // ---------------------------------------------------------------------------
  // Brand — sampled straight from the logo. Do not "tidy" these hexes.
  // ---------------------------------------------------------------------------
  /// The logo's blue chevron, exact.
  static const Color brandAzure = Color(0xFF36A2E2);

  /// The logo's green chevron, exact.
  static const Color brandEmerald = Color(0xFF15DE74);

  // ---------------------------------------------------------------------------
  // Interactive brand ramp (derived — WCAG-safe with white text)
  // ---------------------------------------------------------------------------
  /// Primary action colour — deepened [brandAzure]. 5.1:1 on white.
  /// Buttons, active tabs, links, selected states, progress indicators.
  static const Color primary = Color(0xFF1272B8);

  /// Pressed / deep variant of [primary] — for gradients and pressed fills.
  static const Color primaryDeep = Color(0xFF0B5285);

  /// Light brand tint — the logo azure itself. Icon washes, soft accents,
  /// decorative strokes. Not for text.
  static const Color primaryLight = brandAzure;

  /// Secondary brand accent — deepened [brandEmerald]. 3.1:1 on white.
  /// The "positive / go / scanned" half of the identity.
  static const Color accent = Color(0xFF0FA958);

  /// Money / totals figure.
  static const Color amount = Color(0xFFB45309);

  /// Text and icons that sit ON [primary] / [accent] / the hero gradient.
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------
  /// Reuses the brand emerald ramp — in a facility-management app "success"
  /// (scanned, present, completed) IS the brand's green half.
  static const Color success = Color(0xFF0FA958);
  static const Color warning = Color(0xFFE08600);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF1272B8);

  // ---------------------------------------------------------------------------
  // Hero — the brand gradient used by AppBars and header cards.
  // ---------------------------------------------------------------------------
  // Deliberately BRIGHT and brand-coloured (not a dark navy slab): it runs deep
  // azure → brand azure → emerald, tracing the logo's two chevrons across the
  // diagonal. `heroStops` keeps blue dominant so the emerald only warms the
  // bottom-right corner instead of reading as a rainbow.
  static const Color heroDeep = Color(0xFF06456F); // deep ocean ink — start
  static const Color heroMid = primary; // brand azure — middle
  static const Color heroEdge = accent; // brand emerald — end

  /// Top-left → bottom-right gradient for every hero header.
  /// Change these three and EVERY hero follows.
  static const List<Color> heroGradient = [heroDeep, heroMid, heroEdge];

  /// Weighted so azure holds ~85% of the sweep and emerald just tips the corner.
  static const List<double> heroStops = [0.0, 0.62, 1.0];

  /// Shadow cast by hero surfaces onto the page.
  static const Color heroShadow = Color(0xFF06456F);

  /// Decorative glow blobs layered inside the hero.
  static const Color azureGlow = brandAzure;
  static const Color emeraldGlow = brandEmerald;

  /// Fixed ink for text on an always-white element floating on the hero
  /// (e.g. a search box), plus its hint colour.
  static const Color onLight = Color(0xFF10202B);
  static const Color searchHint = Color(0xFF94A6B3);

  // ---------------------------------------------------------------------------
  // Neutrals — the only tokens that flip with [isDark].
  // ---------------------------------------------------------------------------
  /// Card / sheet / dialog / dropdown-popup background.
  static Color get surface =>
      isDark ? const Color(0xFF12222E) : const Color(0xFFFFFFFF);

  /// Page background. A faintly cool off-white so white cards lift off it.
  static Color get bg =>
      isDark ? const Color(0xFF0A1620) : const Color(0xFFF3F7FA);

  /// Inset panels, field fills, chips, table stripes — one step off [surface].
  static Color get surfaceAlt =>
      isDark ? const Color(0xFF1B2E3D) : const Color(0xFFEEF4F8);

  /// Heading / value text.
  static Color get textPrimary =>
      isDark ? const Color(0xFFEAF2F8) : const Color(0xFF10202B);

  /// Label / muted text.
  static Color get textSecondary =>
      isDark ? const Color(0xFF9DB2C0) : const Color(0xFF5C7180);

  /// Placeholder / disabled / timestamp text.
  static Color get textFaint =>
      isDark ? const Color(0xFF6D8494) : const Color(0xFF94A6B3);

  /// Dividers, hairlines, card borders.
  static Color get divider =>
      isDark ? const Color(0xFF253A4A) : const Color(0xFFDDE7EE);

  /// Standard card shadow.
  static Color get shadow => isDark
      ? Colors.black.withOpacity(0.35)
      : const Color(0xFF06456F).withOpacity(0.07);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  /// A soft brand-tinted wash for icon plates and highlight rows.
  /// Opacity is nudged up in dark mode so the tint survives a dark surface.
  static Color tint(Color c, [double opacity = 0.10]) =>
      c.withOpacity(isDark ? opacity + 0.06 : opacity);

  /// Home-tile accent rotation. Each module tile picks one by index so the grid
  /// reads as a set rather than 20 identical blue squares — all drawn from the
  /// brand ramp plus its supporting semantics.
  static const List<Color> tileAccents = [
    primary, // azure
    accent, // emerald
    Color(0xFF0E7490), // teal
    Color(0xFF7C3AED), // violet
    Color(0xFFE08600), // amber
    Color(0xFF0EA5E9), // sky
  ];

  /// The tile accent for a given grid position.
  static Color tileAccent(int index) => tileAccents[index % tileAccents.length];
}
