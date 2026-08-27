import 'package:flutter/material.dart';

/// Layout helpers so the app works on phones **and** tablets.
///
/// Ajna is installed on tablets as well as phones. The screens were written
/// against a ~360dp phone: grids hard-coded `crossAxisCount: 3`, and forms
/// filled the full width. On a 10" tablet that stretched three tiles to ~300px
/// each and ran form fields edge to edge.
///
/// The rule here is: **keep elements a consistent physical size and add more of
/// them across**, rather than scaling a fixed number of columns up.

/// Number of grid columns for the given [width].
///
/// Divides the available width by [tileTarget] (the size a tile should stay,
/// roughly its current size on a phone) and clamps the result so a phone still
/// renders at least [minColumns] — i.e. phones are unchanged, tablets gain
/// columns instead of stretching.
int gridColumns(
  double width, {
  required int minColumns,
  double tileTarget = 150,
  int maxColumns = 8,
}) {
  if (width <= 0) return minColumns;
  return (width / tileTarget).floor().clamp(minColumns, maxColumns);
}

/// Widest a single column of content (a form, a login card, a detail panel)
/// should ever get.
///
/// Beyond this, long text lines get hard to scan and inputs look stranded, so
/// content is centred in a column of at most this width on large screens.
const double kMaxContentWidth = 560;

/// True for tablet-sized layouts.
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// Height of the device's system navigation bar — the gesture pill or the
/// 3-button row — in logical pixels. Zero on devices that have neither.
///
/// The app targets SDK 36, where Android draws every app edge to edge with no
/// opt-out, so anything pinned to the bottom of the screen (a footer, a
/// SAVE/RESET bar, a "Home" bar) renders *underneath* the system navigation
/// bar unless it reserves this much room. Add it to the bar's own bottom
/// padding rather than wrapping the bar in a `SafeArea`, so the bar's
/// background still paints behind the navigation bar instead of leaving a
/// stripe of page background there.
///
/// Uses `padding`, not `viewPadding`: when the keyboard is open the navigation
/// bar sits on top of it and the gap is no longer needed, and `padding`
/// collapses to zero in that case.
double bottomBarInset(BuildContext context) =>
    MediaQuery.of(context).padding.bottom;

/// Centres [child] and caps it at [maxWidth] so it does not run edge-to-edge
/// on a tablet. On a phone it is a no-op (the phone is already narrower).
class ContentWidthLimit extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  /// Where the capped column sits.
  ///
  /// **Top by default.** A `Center` here centres on BOTH axes, so a form
  /// shorter than the screen floats down to the middle and leaves a large gap
  /// under the app bar — content should start at the top and grow downwards.
  /// Pass [Alignment.center] only for a screen that is genuinely meant to be
  /// centred, such as the login card.
  final AlignmentGeometry alignment;

  const ContentWidthLimit({
    Key? key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.alignment = Alignment.topCenter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
