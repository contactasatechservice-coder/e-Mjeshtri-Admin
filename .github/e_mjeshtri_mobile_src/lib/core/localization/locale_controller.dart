import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

Locale initialLocale = const Locale('sq');
final localeProvider = StateProvider<Locale>((ref) => initialLocale);