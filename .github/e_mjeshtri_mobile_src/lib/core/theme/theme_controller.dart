import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

ThemeMode initialThemeMode = ThemeMode.system;
final themeModeProvider = StateProvider<ThemeMode>((ref) => initialThemeMode);