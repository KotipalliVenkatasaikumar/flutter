import 'package:flutter/material.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int? currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    this.currentIndex, // Accepting null
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_add),
          label: "Open",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.manage_history),
          label: "In-Progress",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.verified),
          label: "Approval",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_return),
          label: "Reassign",
        ),
      ],
      currentIndex: currentIndex ?? 0, // Default to 0 if currentIndex is null
      selectedItemColor: currentIndex == null
          ? Colors.grey
          : const Color.fromARGB(255, 41, 83, 137),
      unselectedItemColor: Colors.grey,
      onTap: onTap, // Always enabled
    );
  }
}
