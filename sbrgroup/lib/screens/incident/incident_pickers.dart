import 'dart:async';

import 'package:ajna/screens/incident/incident_models.dart';
import 'package:ajna/theme/app_colors.dart';
import 'package:ajna/theme/responsive.dart';
import 'package:flutter/material.dart';

/// The searchable option picker, shared by the filter panel and the incident
/// form.
///
/// Both need the same thing — pick one of a few hundred sites or employees, by
/// name — so they share one implementation rather than two that drift. Returns
/// the chosen option, or null if the sheet was dismissed without a choice,
/// which callers read as "leave the current selection alone".
Future<FilterOption?> showIncidentOptionPicker({
  required BuildContext context,
  required String title,
  required Color accent,
  required IconData icon,
  required List<FilterOption> options,
  required FilterOption? selected,
  bool avatars = false,
}) {
  return showModalBottomSheet<FilterOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OptionListSheet(
      title: title,
      accent: accent,
      icon: icon,
      options: options,
      selected: selected,
      avatars: avatars,
    ),
  );
}

/// Searchable list of options, shown over the panel.
///
/// Sites and employees can run to hundreds of rows, so this filters as you type
/// with a short debounce rather than rebuilding on every keystroke.
class _OptionListSheet extends StatefulWidget {
  final String title;
  final Color accent;
  final IconData icon;
  final List<FilterOption> options;
  final FilterOption? selected;
  final bool avatars;

  const _OptionListSheet({
    Key? key,
    required this.title,
    required this.accent,
    required this.icon,
    required this.options,
    required this.selected,
    this.avatars = false,
  }) : super(key: key);

  @override
  State<_OptionListSheet> createState() => _OptionListSheetState();
}

class _OptionListSheetState extends State<_OptionListSheet> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final visible = _query.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.label.toLowerCase().contains(_query))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ContentWidthLimit(
            maxWidth: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18, right: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.tint(widget.accent, 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon,
                            size: 15, color: widget.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${visible.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Explicit way out. This sheet opens on top of the filter
                      // panel, so dismissing it should not mean guessing at the
                      // drag handle or a back gesture. Popping without a result
                      // leaves the current selection untouched.
                      Tooltip(
                        message: 'Close',
                        child: Material(
                          color: AppColors.surfaceAlt,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: _onChanged,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: TextStyle(color: AppColors.textFaint),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: widget.accent, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: widget.accent, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: visible.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'Nothing matches “${_search.text}”',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding:
                              EdgeInsets.only(bottom: 16 + media.padding.bottom),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 18,
                            endIndent: 18,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (context, i) {
                            final option = visible[i];
                            final isSelected = widget.selected == option;
                            return ListTile(
                              leading: widget.avatars
                                  ? InitialsAvatar(
                                      name: option.label,
                                      size: 34,
                                      selected: isSelected,
                                    )
                                  : Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.tint(
                                            widget.accent, 0.14),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(widget.icon,
                                          size: 16, color: widget.accent),
                                    ),
                              title: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded,
                                      color: widget.accent, size: 21)
                                  : null,
                              onTap: () => Navigator.pop(context, option),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
