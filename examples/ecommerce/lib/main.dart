import 'package:ecommerce/bootstrap.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/router/app_router.dart';
import 'package:ecommerce/core/theme.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await bootstrap(() => const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: locator.router.config(),
      title: 'E-commerce App',
      theme: locator.lightTheme,
      darkTheme: locator.darkTheme,
    );
  }
}
