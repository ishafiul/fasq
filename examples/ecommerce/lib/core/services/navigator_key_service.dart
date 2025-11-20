import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@singleton
class NavigatorKeyService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
