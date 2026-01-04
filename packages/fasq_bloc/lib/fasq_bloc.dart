/// Bloc/Cubit adapters for the FASQ async data layer.
///
/// Provides cubits, builders, and prefetch helpers that wrap FASQ queries while
/// integrating naturally with `flutter_bloc`.
library;

export 'package:fasq/fasq.dart';
export 'package:flutter_bloc/flutter_bloc.dart';

export 'src/infinite_query_cubit.dart';
export 'src/mixins/fasq_subscription_mixin.dart';
export 'src/multi_query_builder.dart';
export 'src/mutation_cubit.dart';
export 'src/prefetch_builder.dart';
export 'src/prefetch_cubit.dart';
export 'src/query_cubit.dart';
export 'src/widgets/fasq_bloc_provider.dart';
