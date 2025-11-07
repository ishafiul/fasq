#!/bin/bash

# List of all the remaining files to create
files=(
  "query_options/refetch_on_mount_screen.dart:RefetchOnMount"
  "query_options/callbacks_screen.dart:Callbacks"
  "mutations/basic_mutation_widget_screen.dart:BasicMutationWidget"
  "mutations/basic_mutation_class_screen.dart:BasicMutationClass"
  "mutations/mutation_with_options_screen.dart:MutationWithOptions"
  "mutations/optimistic_updates_screen.dart:OptimisticUpdates"
  "cache_management/cache_invalidation_screen.dart:CacheInvalidation"
  "cache_management/eviction_policies_screen.dart:EvictionPolicies"
  "cache_management/manual_cache_control_screen.dart:ManualCacheControl"
  "infinite_queries/page_number_pagination_screen.dart:PageNumberPagination"
  "infinite_queries/cursor_pagination_screen.dart:CursorPagination"
  "infinite_queries/load_more_button_screen.dart:LoadMoreButton"
  "dependent_queries/user_posts_screen.dart:UserPosts"
  "dependent_queries/category_products_screen.dart:CategoryProducts"
  "offline_queue/basic_offline_queue_screen.dart:BasicOfflineQueue"
  "offline_queue/multi_api_offline_screen.dart:MultiApiOffline"
  "prefetching/prefetch_single_screen.dart:PrefetchSingle"
  "prefetching/prefetch_multiple_screen.dart:PrefetchMultiple"
  "performance/performance_options_screen.dart:PerformanceOptions"
  "performance/hot_cache_screen.dart:HotCache"
  "performance/metrics_screen.dart:Metrics"
  "advanced/request_deduplication_screen.dart:RequestDeduplication"
  "advanced/shared_queries_screen.dart:SharedQueries"
  "advanced/secure_queries_screen.dart:SecureQueries"
)

for file_info in "${files[@]}"; do
  file_path=$(echo "$file_info" | cut -d: -f1)
  class_name=$(echo "$file_info" | cut -d: -f2)
  
  cat > "$file_path" << TEMPLATE
import 'package:flutter/material.dart';
import '../../widgets/example_scaffold.dart';

class ${class_name}Screen extends StatelessWidget {
  const ${class_name}Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: '${class_name}',
      description: 'Coming soon - This example will be implemented.',
      child: const Center(
        child: Text('This example will be implemented soon'),
      ),
    );
  }
}
TEMPLATE
done
