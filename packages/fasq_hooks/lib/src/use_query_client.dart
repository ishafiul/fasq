import 'package:fasq_hooks/fasq_hooks.dart';

QueryClient useQueryClient({QueryClient? client}) {
  return client ?? QueryClient();
}
