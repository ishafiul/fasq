import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

extension GetItAppThemeExtension on GetIt {
  ThemeData get lightTheme => appTheme(Brightness.light);
  ThemeData get darkTheme => appTheme(Brightness.dark);
}
