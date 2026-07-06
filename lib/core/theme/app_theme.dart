import 'package:flutter/material.dart';

import 'dark_theme.dart';
import 'light_theme.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => LightTheme.build();

  static ThemeData get dark => DarkTheme.build();
}
