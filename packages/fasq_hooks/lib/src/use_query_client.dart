import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

QueryClient useQueryClient({QueryClient? client}) {
  return client ?? QueryClient();
}
