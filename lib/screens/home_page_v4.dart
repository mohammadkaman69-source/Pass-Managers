import 'package:flutter/material.dart';

import 'home_page.dart';

/// Entry home after login. Delegates to [HomePage] which owns tree UI,
/// three-dot menu (backup/restore/biometric/language), and PDF export.
class HomePageV4 extends StatelessWidget {
  const HomePageV4({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
