import 'package:ajna/screens/parking/parking_context.dart';
import 'package:ajna/screens/parking/parking_models.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared chrome for the parking screens, so entry / exit / shift stay
/// visually identical and the layout lives in one place.

/// Hero-gradient app bar, matching the rest of Ajna.
PreferredSizeWidget parkingAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
          stops: AppColors.heroStops,
        ),
      ),
    ),
    title: Text(title),
    centerTitle: true,
    actions: actions,
  );
}

/// Text field styling shared by every parking form.
InputDecoration parkingFieldDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.bg,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
    ),
  );
}

/// Plates and pass numbers are always upper case — forcing it here means the
/// attendant never has to reach for shift at a barrier.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// A titled surface card.
class ParkingCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets padding;

  const ParkingCard({
    Key? key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Shows the lane the attendant is posted at, with a way to change it.
///
/// Entry cannot happen without a lane, so this doubles as the prompt when
/// nothing is selected yet.
class LanePostingChip extends StatelessWidget {
  final VoidCallback onChange;

  const LanePostingChip({Key? key, required this.onChange}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool has = ParkingContext.hasLane;
    final Color accent = has ? AppColors.primary : AppColors.warning;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChange,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.tint(accent, 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(has ? Icons.place : Icons.error_outline,
                  color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      has
                          ? '${ParkingContext.siteName ?? ""} · ${ParkingContext.laneName ?? ""}'
                          : 'No lane selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      has
                          ? ParkingConstants.label(ParkingContext.laneDirection)
                          : 'Tap to choose the lane you are working',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text('Change',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal wrap of selectable values (vehicle type, credential, payment).
class ChoiceChipRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  /// Override the auto-generated label for a value, where the API constant
  /// does not read well ("INSIDE" -> "Inside now").
  final Map<String, String>? labels;

  const ChoiceChipRow({
    Key? key,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.labels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final bool on = v == selected;
        return InkWell(
          onTap: () => onChanged(v),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on
                  ? AppColors.primary
                  : AppColors.tint(AppColors.primary, 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: on ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Text(
              labels?[v] ?? ParkingConstants.label(v),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Vehicle type as a row of icon cards.
///
/// Bigger than a text chip on purpose: this is chosen for every single vehicle
/// at a barrier, often one-handed, so it is the one control worth the space.
class VehicleTypePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  /// Optional free-bay count per type, shown under the label.
  final Map<String, String>? badges;

  const VehicleTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ParkingConstants.vehicleTypes.map((t) {
        final bool on = t == selected;
        final String? badge = badges?[t];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => onChanged(t),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: on
                      ? AppColors.primary
                      : AppColors.tint(AppColors.primary, 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.divider,
                    width: on ? 1.6 : 1,
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(vehicleIcon(t),
                        size: 24,
                        color:
                            on ? AppColors.onPrimary : AppColors.textSecondary),
                    const SizedBox(height: 5),
                    Text(
                      _short(t),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: on ? AppColors.onPrimary : AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: on
                              ? AppColors.onPrimary.withOpacity(0.85)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// "Four Wheeler" does not fit a quarter-width card on a small phone.
  static String _short(String t) {
    switch (t) {
      case ParkingConstants.vehicleFourWheeler:
        return 'Car';
      case ParkingConstants.vehicleTwoWheeler:
        return 'Bike';
      case ParkingConstants.vehicleCommercial:
        return 'Truck';
      case ParkingConstants.vehicleEv:
        return 'EV';
      default:
        return ParkingConstants.label(t);
    }
  }
}

/// Tinted status strip — success, warning or error.
class ParkingBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const ParkingBanner({
    Key? key,
    required this.text,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label/value line inside a card.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasise;

  const KeyValueRow({
    Key? key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasise = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasise ? 18 : 13.5,
                fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The icon for a vehicle type.
///
/// A silhouette is read faster than the words "Two Wheeler" — at a barrier or
/// scanning a list of stays, shape carries before text does.
IconData vehicleIcon(String? vehicleType) {
  switch ((vehicleType ?? '').toUpperCase()) {
    case ParkingConstants.vehicleTwoWheeler:
      return Icons.two_wheeler;
    case ParkingConstants.vehicleCommercial:
      return Icons.local_shipping;
    case ParkingConstants.vehicleEv:
      return Icons.electric_car;
    case ParkingConstants.vehicleFourWheeler:
      return Icons.directions_car;
    default:
      return Icons.directions_car_outlined;
  }
}

/// Fades and slides a row in once, the first time it appears.
///
/// Keyed by the row's own id so pagination animates only the newly appended
/// rows — re-animating the whole list on every filter keystroke would be
/// motion for its own sake, and slow.
class AnimatedEntry extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedEntry({super.key, required this.child, this.index = 0});

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    // Stagger, but cap it — a long page should not take a second to settle.
    final int delay = (widget.index.clamp(0, 8)) * 45;
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// A number that counts up when it changes, so a refreshed total is noticed.
class AnimatedCount extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String Function(double)? format;

  const AnimatedCount(
      {super.key, required this.value, this.style, this.format});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        format?.call(v) ?? v.round().toString(),
        style: style,
      ),
    );
  }
}

/// A softly pulsing dot — used to mark a stay that is still open.
class LivePulse extends StatefulWidget {
  final Color color;
  final double size;
  const LivePulse({super.key, required this.color, this.size = 8});

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Formats an amount as Indian rupees for display.
String money(double? v) {
  final d = v ?? 0;
  return '₹${d.toStringAsFixed(2)}';
}

/// "2h 15m" from a minute count.
String durationLabel(int? minutes) {
  if (minutes == null) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}
