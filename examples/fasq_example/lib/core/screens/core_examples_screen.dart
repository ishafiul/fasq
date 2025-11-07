import 'package:flutter/material.dart';
import '../basic_query/basic_query_widget_screen.dart';
import '../basic_query/basic_query_class_screen.dart';
import '../query_options/stale_time_screen.dart';
import '../query_options/cache_time_screen.dart';
import '../query_options/enabled_gating_screen.dart';
import '../query_options/refetch_on_mount_screen.dart';
import '../query_options/callbacks_screen.dart';
import '../mutations/basic_mutation_widget_screen.dart';
import '../mutations/basic_mutation_class_screen.dart';
import '../mutations/mutation_with_options_screen.dart';
import '../mutations/optimistic_updates_screen.dart';
import '../mutations/offline_mutation_screen.dart';
import '../cache_management/cache_invalidation_screen.dart';
import '../cache_management/eviction_policies_screen.dart';
import '../cache_management/manual_cache_control_screen.dart';
import '../infinite_queries/page_number_pagination_screen.dart';
import '../infinite_queries/cursor_pagination_screen.dart';
import '../infinite_queries/load_more_button_screen.dart';
import '../infinite_queries/infinite_scroll_screen.dart';
import '../dependent_queries/user_posts_screen.dart';
import '../dependent_queries/category_products_screen.dart';
import '../offline_queue/basic_offline_queue_screen.dart';
import '../offline_queue/multi_api_offline_screen.dart';
import '../prefetching/prefetch_single_screen.dart';
import '../prefetching/prefetch_multiple_screen.dart';
import '../performance/performance_options_screen.dart';
import '../performance/hot_cache_screen.dart';
import '../performance/metrics_screen.dart';
import '../advanced/request_deduplication_screen.dart';
import '../advanced/shared_queries_screen.dart';
import '../advanced/secure_queries_screen.dart';

class CoreExamplesScreen extends StatelessWidget {
  const CoreExamplesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Core Package Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: 'Basic Query',
            description: 'Learn the fundamentals of FASQ queries',
            examples: [
              _ExampleItem(
                title: 'QueryBuilder Widget',
                description:
                    'Using QueryBuilder widget for simple data fetching',
                screen: const BasicQueryWidgetScreen(),
              ),
              _ExampleItem(
                title: 'Query Class',
                description: 'Direct Query class usage with StreamBuilder',
                screen: const BasicQueryClassScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Query Options',
            description: 'Configure query behavior and caching',
            examples: [
              _ExampleItem(
                title: 'Stale Time',
                description: 'Control when data is considered fresh',
                screen: const StaleTimeScreen(),
              ),
              _ExampleItem(
                title: 'Cache Time',
                description: 'Configure cache retention duration',
                screen: const CacheTimeScreen(),
              ),
              _ExampleItem(
                title: 'Enabled Gating',
                description: 'Enable/disable queries conditionally',
                screen: const EnabledGatingScreen(),
              ),
              _ExampleItem(
                title: 'Refetch on Mount',
                description: 'Control refetching behavior',
                screen: const RefetchOnMountScreen(),
              ),
              _ExampleItem(
                title: 'Callbacks',
                description: 'Handle success and error events',
                screen: const CallbacksScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Mutations',
            description: 'Handle data modifications and server updates',
            examples: [
              _ExampleItem(
                title: 'MutationBuilder Widget',
                description: 'Using MutationBuilder for data mutations',
                screen: const BasicMutationWidgetScreen(),
              ),
              _ExampleItem(
                title: 'Mutation Class',
                description: 'Direct Mutation class usage',
                screen: const BasicMutationClassScreen(),
              ),
              _ExampleItem(
                title: 'Mutation Options',
                description: 'Configure mutation behavior and callbacks',
                screen: const MutationWithOptionsScreen(),
              ),
              _ExampleItem(
                title: 'Optimistic Updates',
                description: 'Update UI immediately before server response',
                screen: const OptimisticUpdatesScreen(),
              ),
              _ExampleItem(
                title: 'Offline Mutations',
                description: 'Queue mutations for when network comes back',
                screen: const OfflineMutationScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Cache Management',
            description: 'Control caching behavior and invalidation',
            examples: [
              _ExampleItem(
                title: 'Cache Invalidation',
                description: 'Invalidate cached data manually',
                screen: const CacheInvalidationScreen(),
              ),
              _ExampleItem(
                title: 'Eviction Policies',
                description: 'Configure cache eviction strategies',
                screen: const EvictionPoliciesScreen(),
              ),
              _ExampleItem(
                title: 'Manual Cache Control',
                description: 'Direct cache manipulation',
                screen: const ManualCacheControlScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Infinite Queries',
            description: 'Handle pagination and infinite scroll',
            examples: [
              _ExampleItem(
                title: 'Infinite Scroll',
                description: 'Auto-load posts as you scroll',
                screen: const InfiniteScrollScreen(),
              ),
              _ExampleItem(
                title: 'Page Number Pagination',
                description: 'Navigate pages with Previous/Next buttons',
                screen: const PageNumberPaginationScreen(),
              ),
              _ExampleItem(
                title: 'Cursor Pagination',
                description: 'Cursor-based infinite scroll',
                screen: const CursorPaginationScreen(),
              ),
              _ExampleItem(
                title: 'Load More Button',
                description: 'Manual load more trigger',
                screen: const LoadMoreButtonScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Dependent Queries',
            description: 'Chain queries based on other query results',
            examples: [
              _ExampleItem(
                title: 'User Posts',
                description: 'Fetch posts based on selected user',
                screen: const UserPostsScreen(),
              ),
              _ExampleItem(
                title: 'Category Products',
                description: 'Multiple dependent queries example',
                screen: const CategoryProductsScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Offline Queue',
            description: 'Queue mutations when offline',
            examples: [
              _ExampleItem(
                title: 'Basic Offline Queue',
                description: 'Simple offline mutation queuing',
                screen: const BasicOfflineQueueScreen(),
              ),
              _ExampleItem(
                title: 'Multi-API Offline',
                description: 'Multiple mutation types queued',
                screen: const MultiApiOfflineScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Prefetching',
            description: 'Preload data for better user experience',
            examples: [
              _ExampleItem(
                title: 'Prefetch Single',
                description: 'Prefetch individual queries',
                screen: const PrefetchSingleScreen(),
              ),
              _ExampleItem(
                title: 'Prefetch Multiple',
                description: 'Batch prefetching multiple queries',
                screen: const PrefetchMultipleScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Performance',
            description: 'Optimize query performance and monitoring',
            examples: [
              _ExampleItem(
                title: 'Performance Options',
                description: 'Configure performance settings',
                screen: const PerformanceOptionsScreen(),
              ),
              _ExampleItem(
                title: 'Hot Cache',
                description: 'Demonstrate hot cache benefits',
                screen: const HotCacheScreen(),
              ),
              _ExampleItem(
                title: 'Metrics',
                description: 'Monitor cache and query performance',
                screen: const MetricsScreen(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: 'Advanced',
            description: 'Advanced features and patterns',
            examples: [
              _ExampleItem(
                title: 'Request Deduplication',
                description: 'Multiple components, single network call',
                screen: const RequestDeduplicationScreen(),
              ),
              _ExampleItem(
                title: 'Shared Queries',
                description: 'Multiple widgets sharing query state',
                screen: const SharedQueriesScreen(),
              ),
              _ExampleItem(
                title: 'Secure Queries',
                description: 'Handle sensitive data securely',
                screen: const SecureQueriesScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<_ExampleItem> examples,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ...examples.map((example) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(example.title),
                  subtitle: Text(example.description),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => example.screen),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _ExampleItem {
  final String title;
  final String description;
  final Widget screen;

  const _ExampleItem({
    required this.title,
    required this.description,
    required this.screen,
  });
}
