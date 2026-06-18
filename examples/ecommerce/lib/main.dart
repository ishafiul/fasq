import 'package:ecommerce/bootstrap.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/router/app_router.dart';
import 'package:ecommerce/core/services/navigator_key_service.dart';
import 'package:ecommerce/core/services/query_client_service.dart';
import 'package:ecommerce/core/theme.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await bootstrap(() => const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final fasqRuntime = locator<QueryClientService>();
    final navigatorKeyService = locator<NavigatorKeyService>();

    return FasqProvider(
      runtime: fasqRuntime,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: locator.router.config(),
        title: 'E-commerce App',
        theme: locator.lightTheme,
        darkTheme: locator.darkTheme,
        key: navigatorKeyService.navigatorKey,
      ),
    );
  }
}
