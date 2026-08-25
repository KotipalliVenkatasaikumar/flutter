import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared form and dropdown styling.
///
/// dropdown_button2 lays a menu out unbounded unless it is given a
/// [DropdownStyleData]. On a list of twenty-odd sites or a few hundred
/// employees that means the menu covers the entire screen — the form behind it
/// disappears, so nothing is left to say what you were choosing for. Every
/// dropdown in the app should be built through these.

/// The outlined field decoration used across the HRM forms.
InputDecoration fieldDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    hintStyle: const TextStyle(color: AppColors.searchHint, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
}

/// A bounded, rounded dropdown menu that leaves the page visible around it.
DropdownStyleData menuStyle(BuildContext context, {double maxHeight = 320}) {
  return DropdownStyleData(
    maxHeight: maxHeight,
    width: MediaQuery.of(context).size.width * 0.86,
    padding: EdgeInsets.zero,
    offset: const Offset(0, -4),
    elevation: 3,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
  );
}

/// Menu rows sized for a thumb rather than a mouse.
const MenuItemStyleData kMenuItemStyle = MenuItemStyleData(
  height: 44,
  padding: EdgeInsets.symmetric(horizontal: 14),
);

/// Height of [menuSearchField], and the value to pass as
/// `searchInnerWidgetHeight`.
///
/// dropdown_button2 uses that number to work out the menu's limits and scroll
/// offset, so a search field that renders taller than it claims leaves the menu
/// mis-measured — the last row sits under the edge and cannot be reached. The
/// field is pinned to this height rather than left to size itself.
const double kMenuSearchHeight = 60;

/// The search box that goes inside a long dropdown menu.
///
/// dropdown_button2 listens to the controller itself and re-filters the rows,
/// so this only has to own the text — no rebuild is wired up by hand.
Widget menuSearchField(TextEditingController controller, String hint) {
  return SizedBox(
    height: kMenuSearchHeight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: TextFormField(
        controller: controller,
        autofocus: false,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.searchHint, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textFaint),
          // Left at its default the icon claims a 48px box, which pushes the
          // field past the height declared above.
          prefixIconConstraints:
              const BoxConstraints(minWidth: 34, minHeight: 34),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    ),
  );
}
