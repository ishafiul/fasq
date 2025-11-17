import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// The main router for the application.
///
/// This class defines the routes for the application and the guards that are required to access the routes.
/// It also includes the splash route that is displayed when the app is launched.
@singleton
@AutoRouterConfig()
final class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          path: '/',
          page: HomeRoute.page,
        ),
      ];
}

/// Extension to easily access the [AppRouter] from GetIt.
///
/// This extension provides a convenient way to access the [AppRouter] instance
/// from the dependency injection container.
extension GetItRouterExtension on GetIt {
  AppRouter get router => get<AppRouter>();
}
