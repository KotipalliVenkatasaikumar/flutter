import 'dart:async';

import 'package:ajna/screens/incident/incident_models.dart';
import 'package:ajna/screens/incident/incident_pickers.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The incident filter control panel.
///
/// Deliberately **not** a form of identical rows. Each filter is a different
/// kind of question, so each gets a control shaped like its answer: a site is a
/// place you pick, a type is one of ten icons, a severity is a level on a
/// ladder, a status is a three-way switch, a date range is two ends of a line.
/// Every category card carries its own icon and accent, so you navigate the
/// panel by colour and shape before reading a single label.
///
/// Opens as a modal sheet and edits a **working copy**, so backing out with the
/// handle or the system gesture leaves the list untouched. Only "Apply" returns
/// a value; a dismiss returns null.
Future<IncidentFilters?> showIncidentFilterSheet({
  required BuildContext context,
  required IncidentFilters current,
  required List<FilterOption> sites,
  required List<FilterOption> types,
  required List<FilterOption> severities,
  required List<FilterOption> employees,
  required bool mastersLoading,
}) {
  return showModalBottomSheet<IncidentFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (_) => _FilterSheet(
      current: current,
      sites: sites,
      types: types,
      severities: severities,
      employees: employees,
      mastersLoading: mastersLoading,
    ),
  );
}

/// Accents that give each category its identity. Kept together so the panel's
/// colour scheme is legible in one place rather than scattered down the build.
class _Accents {
  static const site = Color(0xFF0E7490); // teal — place
  static const type = Color(0xFF7C3AED); // violet — classification
  static const severity = AppColors.danger; // red — urgency
  static const people = Color(0xFF0284C7); // sky — who
  static const status = AppColors.accent; // emerald — state
  static const dates = AppColors.primary; // azure — time
}

class _FilterSheet extends StatefulWidget {
  final IncidentFilters current;
  final List<FilterOption> sites;
  final List<FilterOption> types;
  final List<FilterOption> severities;
  final List<FilterOption> employees;
  final bool mastersLoading;

  const _FilterSheet({
    Key? key,
    required this.current,
    required this.sites,
    required this.types,
    required this.severities,
    required this.employees,
    required this.mastersLoading,
  }) : super(key: key);

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late IncidentFilters _draft = widget.current;

  static final DateFormat _pretty = DateFormat('dd MMM yyyy');

  void _update(IncidentFilters next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      // Keeps the Apply bar above the keyboard when a search field is open.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ContentWidthLimit(
            maxWidth: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _grabHandle(),
                _panelHeader(),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    children: [
                      _siteCard(),
                      const SizedBox(height: 13),
                      _typeCard(),
                      const SizedBox(height: 13),
                      _severityCard(),
                      const SizedBox(height: 13),
                      _employeeCard(),
                      const SizedBox(height: 13),
                      _statusCard(),
                      const SizedBox(height: 13),
                      _dateCard(),
                    ],
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- chrome ---------------------------------------------------------------

  Widget _grabHandle() => Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(99),
        ),
      );

  Widget _panelHeader() {
    final count = _draft.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 10, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.primary, 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Refine incidents',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    count == 0
                        ? 'No filters applied'
                        : '$count filter${count == 1 ? '' : 's'} applied',
                    key: ValueKey(count),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: count == 0
                          ? AppColors.textFaint
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _draft.isActive
                  ? () => _update(const IncidentFilters())
                  : null,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _draft),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(_draft.isActive
                  ? 'Apply ${_draft.activeCount} filter${_draft.activeCount == 1 ? '' : 's'}'
                  : 'Show all incidents'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- category 1: site -----------------------------------------------------
  //
  // A place you choose from a long list, so it reads as a destination plate
  // with the chosen site set large — not a dropdown row.

  Widget _siteCard() {
    final site = _draft.site;
    return _CategoryCard(
      icon: Icons.place_rounded,
      title: 'Site',
      caption: 'Where it happened',
      accent: _Accents.site,
      active: site != null,
      onClear: site == null ? null : () => _update(_draft.copyWith(clearSite: true)),
      child: _HeroSelector(
        accent: _Accents.site,
        icon: Icons.apartment_rounded,
        loading: widget.mastersLoading,
        emptyLabel: 'All sites',
        emptyHint: 'Incidents from every location',
        valueLabel: site?.label,
        valueHint: site == null ? null : 'Location ID ${site.id}',
        onTap: () async {
          final picked = await _pickOption(
            title: 'Select site',
            accent: _Accents.site,
            icon: Icons.place_rounded,
            options: widget.sites,
            selected: site,
          );
          if (picked != null && mounted) _update(_draft.copyWith(site: picked));
        },
      ),
    );
  }

  // -- category 2: incident type -------------------------------------------
  //
  // Ten fixed options, each with a strong icon and its own hue: a tile grid is
  // faster to scan than ten near-identical text chips.

  Widget _typeCard() {
    final selected = _draft.incidentType;
    return _CategoryCard(
      icon: Icons.category_rounded,
      title: 'Incident type',
      caption: 'What kind of incident',
      accent: _Accents.type,
      active: selected != null,
      onClear:
          selected == null ? null : () => _update(_draft.copyWith(clearType: true)),
      child: _TypeGrid(
        options: widget.types,
        selected: selected,
        loading: widget.mastersLoading,
        onSelected: (o) => _update(o == null
            ? _draft.copyWith(clearType: true)
            : _draft.copyWith(incidentType: o)),
      ),
    );
  }

  // -- category 3: severity -------------------------------------------------
  //
  // Severity is ordered, so it is drawn as a ladder with a filled meter per
  // level. The control itself communicates that Critical outranks Low.

  Widget _severityCard() {
    final selected = _draft.severity;
    return _CategoryCard(
      icon: Icons.speed_rounded,
      title: 'Severity',
      caption: 'How serious',
      accent: _Accents.severity,
      active: selected != null,
      onClear: selected == null
          ? null
          : () => _update(_draft.copyWith(clearSeverity: true)),
      child: _SeverityLadder(
        options: widget.severities,
        selected: selected,
        loading: widget.mastersLoading,
        onSelected: (o) => _update(o == null
            ? _draft.copyWith(clearSeverity: true)
            : _draft.copyWith(severity: o)),
      ),
    );
  }

  // -- category 4: responsible employee ------------------------------------
  //
  // People are recognised by face, not by name in a dropdown — so the control
  // is a rail of initials avatars, with search for the full roster.

  Widget _employeeCard() {
    final selected = _draft.employee;
    return _CategoryCard(
      icon: Icons.engineering_rounded,
      title: 'Responsible employee',
      caption: 'Who owns it',
      accent: _Accents.people,
      active: selected != null,
      onClear: selected == null
          ? null
          : () => _update(_draft.copyWith(clearEmployee: true)),
      child: _EmployeeRail(
        employees: widget.employees,
        selected: selected,
        loading: widget.mastersLoading,
        onSelected: (o) => _update(o == null
            ? _draft.copyWith(clearEmployee: true)
            : _draft.copyWith(employee: o)),
        onSearch: () async {
          final picked = await _pickOption(
            title: 'Select employee',
            accent: _Accents.people,
            icon: Icons.person_rounded,
            options: widget.employees,
            selected: selected,
            avatars: true,
          );
          if (picked != null && mounted) {
            _update(_draft.copyWith(employee: picked));
          }
        },
      ),
    );
  }

  // -- category 5: status ---------------------------------------------------
  //
  // Exactly three mutually exclusive states — a sliding segmented switch, the
  // one control here that can never be "none selected".

  Widget _statusCard() {
    return _CategoryCard(
      icon: Icons.flag_rounded,
      title: 'Status',
      caption: 'Open or resolved',
      accent: _Accents.status,
      active: _draft.status.isNotEmpty,
      onClear: _draft.status.isEmpty
          ? null
          : () => _update(_draft.copyWith(status: '')),
      child: _StatusSwitch(
        value: _draft.status,
        onChanged: (v) => _update(_draft.copyWith(status: v)),
      ),
    );
  }

  // -- category 6: date range ----------------------------------------------
  //
  // Two ends of a span, drawn as a connected line with presets — picking "Last
  // 7 days" is one tap instead of two calendar visits.

  Widget _dateCard() {
    final active = _draft.startDate != null || _draft.endDate != null;
    return _CategoryCard(
      icon: Icons.date_range_rounded,
      title: 'Date range',
      caption: 'When it happened',
      accent: _Accents.dates,
      active: active,
      onClear: !active
          ? null
          : () => _update(_draft.copyWith(clearStart: true, clearEnd: true)),
      child: _DateRangeControl(
        start: _draft.startDate,
        end: _draft.endDate,
        format: _pretty,
        onPickStart: () => _pickDate(isStart: true),
        onPickEnd: () => _pickDate(isStart: false),
        onPreset: (from, to) =>
            _update(_draft.copyWith(startDate: from, endDate: to)),
        onClearStart: () => _update(_draft.copyWith(clearStart: true)),
        onClearEnd: () => _update(_draft.copyWith(clearEnd: true)),
      ),
    );
  }

  // -- interactions ---------------------------------------------------------

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _draft.startDate : _draft.endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: _Accents.dates,
                onPrimary: AppColors.onPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        // Keep the range coherent: a start after the current end would ask the
        // backend for an empty window, which reads as "no incidents" rather
        // than as a bad range.
        final end = _draft.endDate;
        _draft = _draft.copyWith(
          startDate: picked,
          endDate: (end != null && end.isBefore(picked)) ? picked : end,
        );
      } else {
        final start = _draft.startDate;
        _draft = _draft.copyWith(
          endDate: picked,
          startDate: (start != null && start.isAfter(picked)) ? picked : start,
        );
      }
    });
  }

  Future<FilterOption?> _pickOption({
    required String title,
    required Color accent,
    required IconData icon,
    required List<FilterOption> options,
    required FilterOption? selected,
    bool avatars = false,
  }) {
    return showIncidentOptionPicker(
      context: context,
      title: title,
      accent: accent,
      icon: icon,
      options: options,
      selected: selected,
      avatars: avatars,
    );
  }
}

// ---------------------------------------------------------------------------
// The category shell
// ---------------------------------------------------------------------------

/// One filter category: accent-coded header, its own control below.
///
/// The card is what creates the separation the panel needs — an active category
/// lifts with a tinted border and a coloured glow, so which filters are engaged
/// is visible without reading any values.
class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final Color accent;
  final bool active;
  final VoidCallback? onClear;
  final Widget child;

  const _CategoryCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.accent,
    required this.active,
    required this.child,
    this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.tint(accent, 0.45) : AppColors.divider,
          width: active ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: active ? accent.withOpacity(0.16) : AppColors.shadow,
            blurRadius: active ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : AppColors.tint(accent, 0.13),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: accent.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: active ? AppColors.onPrimary : accent,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                // The clear affordance only exists while there is something to
                // clear, so an untouched panel has no dead controls in it.
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: active ? 1 : 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 17,
                    icon: Icon(Icons.backspace_rounded, color: accent),
                    onPressed: onClear,
                    tooltip: 'Clear $title',
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category 1 — hero selector (site)
// ---------------------------------------------------------------------------

class _HeroSelector extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final bool loading;
  final String emptyLabel;
  final String emptyHint;
  final String? valueLabel;
  final String? valueHint;
  final VoidCallback onTap;

  const _HeroSelector({
    Key? key,
    required this.accent,
    required this.icon,
    required this.loading,
    required this.emptyLabel,
    required this.emptyHint,
    required this.valueLabel,
    required this.valueHint,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final has = valueLabel != null && valueLabel!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: has ? AppColors.tint(accent, 0.09) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: has ? AppColors.tint(accent, 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: has ? accent : AppColors.tint(accent, 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 19, color: has ? AppColors.onPrimary : accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loading ? 'Loading sites…' : (has ? valueLabel! : emptyLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      loading ? 'Please wait' : (has ? valueHint! : emptyHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category 2 — icon tile grid (incident type)
// ---------------------------------------------------------------------------

class _TypeGrid extends StatelessWidget {
  final List<FilterOption> options;
  final FilterOption? selected;
  final bool loading;
  final ValueChanged<FilterOption?> onSelected;

  const _TypeGrid({
    Key? key,
    required this.options,
    required this.selected,
    required this.loading,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _PlaceholderGrid(count: 6, height: 68);
    }
    if (options.isEmpty) {
      return _Unavailable(label: 'Incident types could not be loaded');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tiles hold ~92dp so the label survives; wider screens simply fit
        // more per row rather than stretching four of them.
        const spacing = 8.0;
        final columns =
            (constraints.maxWidth / 92).floor().clamp(3, 6);
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: options.map((o) {
            final isSelected = selected == o;
            final accent = incidentTypeAccent(o.label);
            return SizedBox(
              width: tileWidth,
              child: _TypeTile(
                label: o.label,
                icon: incidentTypeIcon(o.label),
                accent: accent,
                selected: isSelected,
                onTap: () => onSelected(isSelected ? null : o),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    Key? key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint(accent, 0.14) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.26),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              scale: selected ? 1.12 : 1,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? accent : AppColors.tint(accent, 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    size: 15,
                    color: selected ? AppColors.onPrimary : accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category 3 — severity ladder
// ---------------------------------------------------------------------------

/// Severity as ranked rows, each with a meter filled to its weight, so the
/// ordering is part of the control rather than something you have to know.
class _SeverityLadder extends StatelessWidget {
  final List<FilterOption> options;
  final FilterOption? selected;
  final bool loading;
  final ValueChanged<FilterOption?> onSelected;

  const _SeverityLadder({
    Key? key,
    required this.options,
    required this.selected,
    required this.loading,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(
          4,
          (i) => Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    if (options.isEmpty) {
      return _Unavailable(label: 'Severity levels could not be loaded');
    }

    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 7),
            child: _SeverityRow(
              option: options[i],
              selected: selected == options[i],
              onTap: () =>
                  onSelected(selected == options[i] ? null : options[i]),
            ),
          ),
      ],
    );
  }
}

class _SeverityRow extends StatelessWidget {
  final FilterOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityRow({
    Key? key,
    required this.option,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = severityStyleFor(option.label);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tint(style.color, 0.13)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? style.color : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? style.color : AppColors.tint(style.color, 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(style.icon,
                  size: 14,
                  color: selected ? AppColors.onPrimary : style.color),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 62,
              child: Text(
                style.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // The meter: how far up the ladder this level sits.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 6,
                  color: AppColors.divider,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: style.weight,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      decoration: BoxDecoration(
                        color: style.color
                            .withOpacity(selected ? 1 : 0.55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? style.color : Colors.transparent,
                border: Border.all(
                  color: selected ? style.color : AppColors.divider,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: AppColors.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category 4 — employee rail
// ---------------------------------------------------------------------------

/// A horizontal rail of faces, plus search for the rest of the roster.
///
/// Only the first slice is shown inline — the roster runs to hundreds, and a
/// rail you can flick through beats a dropdown for the handful of people who
/// actually recur. A selection outside that slice is pinned to the front so it
/// is always visible.
class _EmployeeRail extends StatelessWidget {
  final List<FilterOption> employees;
  final FilterOption? selected;
  final bool loading;
  final ValueChanged<FilterOption?> onSelected;
  final VoidCallback onSearch;

  static const int _inlineCount = 12;

  const _EmployeeRail({
    Key? key,
    required this.employees,
    required this.selected,
    required this.loading,
    required this.onSelected,
    required this.onSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 72,
        child: Row(
          children: List.generate(
            5,
            (i) => Container(
              width: 54,
              height: 54,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    if (employees.isEmpty) {
      return _Unavailable(label: 'Employee list could not be loaded');
    }

    final inline = employees.take(_inlineCount).toList();
    if (selected != null && !inline.contains(selected)) {
      inline.insert(0, selected!);
    }

    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _railSearchButton(),
          const SizedBox(width: 10),
          _railAnyone(),
          const SizedBox(width: 10),
          for (final e in inline) ...[
            _railPerson(e),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _railSearchButton() => GestureDetector(
        onTap: onSearch,
        child: SizedBox(
          width: 54,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(_Accents.people, 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.tint(_Accents.people, 0.4)),
                ),
                child: Icon(Icons.search_rounded,
                    size: 20, color: _Accents.people),
              ),
              const SizedBox(height: 4),
              Text(
                'Search',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: _Accents.people,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _railAnyone() {
    final isSelected = selected == null;
    return GestureDetector(
      onTap: () => onSelected(null),
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? _Accents.people
                    : AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _Accents.people : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 20,
                color: isSelected ? AppColors.onPrimary : AppColors.textFaint,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Anyone',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railPerson(FilterOption employee) {
    final isSelected = selected == employee;
    return GestureDetector(
      onTap: () => onSelected(isSelected ? null : employee),
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                InitialsAvatar(
                  name: employee.label,
                  size: 46,
                  selected: isSelected,
                ),
                if (isSelected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 9, color: AppColors.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              employee.label.split(RegExp(r'\s+')).first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category 5 — status switch
// ---------------------------------------------------------------------------

/// Three-way segmented switch with a sliding indicator.
///
/// The indicator takes the colour of the state it lands on — amber for Open,
/// green for Closed — so the switch itself signals what you are looking at.
class _StatusSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  static const List<_StatusChoice> _choices = [
    _StatusChoice('', 'All', Icons.all_inclusive_rounded, AppColors.primary),
    _StatusChoice(
        'Open', 'Open', Icons.radio_button_checked_rounded, AppColors.warning),
    _StatusChoice(
        'Close', 'Closed', Icons.check_circle_rounded, AppColors.success),
  ];

  const _StatusSwitch({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final index = _choices.indexWhere((c) => c.key == value);
    final activeIndex = index < 0 ? 0 : index;

    return LayoutBuilder(
      builder: (context, constraints) {
        final segment = constraints.maxWidth / _choices.length;
        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: segment * activeIndex,
                top: 0,
                bottom: 0,
                width: segment,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    decoration: BoxDecoration(
                      color: _choices[activeIndex].color,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color:
                              _choices[activeIndex].color.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: _choices.map((choice) {
                  final isActive = choice.key == _choices[activeIndex].key;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(choice.key),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              choice.icon,
                              size: 14,
                              color: isActive
                                  ? AppColors.onPrimary
                                  : AppColors.textFaint,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              choice.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isActive
                                    ? AppColors.onPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChoice {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const _StatusChoice(this.key, this.label, this.icon, this.color);
}

// ---------------------------------------------------------------------------
// Category 6 — date range
// ---------------------------------------------------------------------------

/// Presets plus a two-ended span.
///
/// The connecting line is the point: start and end are one range, not two
/// unrelated fields that happen to sit next to each other.
class _DateRangeControl extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final DateFormat format;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final void Function(DateTime from, DateTime to) onPreset;
  final VoidCallback onClearStart;
  final VoidCallback onClearEnd;

  const _DateRangeControl({
    Key? key,
    required this.start,
    required this.end,
    required this.format,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPreset,
    required this.onClearStart,
    required this.onClearEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _presets(),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _DateNode(
                caption: 'From',
                value: start,
                format: format,
                onTap: onPickStart,
                onClear: start == null ? null : onClearStart,
              ),
            ),
            // The span line, tying the two ends into one control.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 2,
                    color: AppColors.divider,
                  ),
                  const SizedBox(height: 3),
                  Icon(Icons.arrow_forward_rounded,
                      size: 12, color: AppColors.textFaint),
                ],
              ),
            ),
            Expanded(
              child: _DateNode(
                caption: 'To',
                value: end,
                format: format,
                onTap: onPickEnd,
                onClear: end == null ? null : onClearEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _presets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <String, List<DateTime>>{
      'Today': [today, today],
      'Last 7 days': [today.subtract(const Duration(days: 6)), today],
      'Last 30 days': [today.subtract(const Duration(days: 29)), today],
      'This month': [DateTime(now.year, now.month, 1), today],
    };

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: presets.entries.map((entry) {
        final from = entry.value[0];
        final to = entry.value[1];
        final isActive = start != null &&
            end != null &&
            _sameDay(start!, from) &&
            _sameDay(end!, to);
        return GestureDetector(
          onTap: () => onPreset(from, to),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isActive
                  ? _Accents.dates
                  : AppColors.tint(_Accents.dates, 0.09),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: isActive
                    ? _Accents.dates
                    : AppColors.tint(_Accents.dates, 0.26),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 12,
                    color:
                        isActive ? AppColors.onPrimary : _Accents.dates),
                const SizedBox(width: 4),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isActive ? AppColors.onPrimary : _Accents.dates,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateNode extends StatelessWidget {
  final String caption;
  final DateTime? value;
  final DateFormat format;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateNode({
    Key? key,
    required this.caption,
    required this.value,
    required this.format,
    required this.onTap,
    this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final has = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color:
                has ? AppColors.tint(_Accents.dates, 0.09) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: has
                  ? AppColors.tint(_Accents.dates, 0.42)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: has ? _Accents.dates : AppColors.divider,
                  border: Border.all(
                    color: has ? _Accents.dates : AppColors.textFaint,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      caption.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      has ? format.format(value!) : 'Any date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: has ? FontWeight.w800 : FontWeight.w500,
                        color:
                            has ? AppColors.textPrimary : AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (has && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.cancel_rounded,
                      size: 15, color: AppColors.textFaint),
                )
              else
                Icon(Icons.calendar_month_rounded,
                    size: 14, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class _Unavailable extends StatelessWidget {
  final String label;

  const _Unavailable({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.textFaint),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderGrid extends StatelessWidget {
  final int count;
  final double height;

  const _PlaceholderGrid({
    Key? key,
    required this.count,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = (constraints.maxWidth / 92).floor().clamp(3, 6);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            count,
            (i) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      },
    );
  }
}

