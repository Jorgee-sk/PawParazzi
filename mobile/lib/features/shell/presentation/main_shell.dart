import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'paw_nav_bar.dart';

/// Contenedor de las cinco pestañas (navegación fija; nav + safe area = 88 px de referencia).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: PawNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}
