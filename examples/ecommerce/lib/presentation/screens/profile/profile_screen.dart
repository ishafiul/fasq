import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/auth_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/presentation/widget/cart/cart_icon_button.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          CartIconButton(),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserProfileSection(context),
            AppDivider.base(axis: Axis.horizontal),
            _buildPromotionalBanner(context),
            AppDivider.base(axis: Axis.horizontal),
            _buildAccountSettingsSection(context),
            SizedBox(height: spacing.lg),
            QueryBuilder<bool>(
              queryKey: QueryKeys.isLoggedIn,
              queryFn: () => locator.get<UserService>().isLoggedIn(),
              builder: (context, state) {
                if (state.isLoading) {
                  return const SizedBox.shrink();
                }

                final isLoggedIn = state.data ?? false;

                if (isLoggedIn) {
                  return Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: const _LogoutButton(),
                  );
                } else {
                  return Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: const _LoginButton(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileSection(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return QueryBuilder<String?>(
      queryKey: QueryKeys.userEmail,
      queryFn: () => locator.get<UserService>().getUserEmail(),
      builder: (context, state) {
        final email = state.data;
        final userName = email?.split('@').first ?? 'Guest';

        return Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: palette.brand.withValues(alpha: 0.1),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'G',
                  style: typography.headlineMedium
                      .toTextStyle(
                        color: palette.brand,
                      )
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: typography.headlineSmall
                          .toTextStyle(
                            color: palette.textPrimary,
                          )
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: spacing.xs / 2),
                    GestureDetector(
                      onTap: () {
                        // TODO: Navigate to profile details
                      },
                      child: Text(
                        'View profile',
                        style: typography.bodyMedium
                            .toTextStyle(
                              color: palette.brand,
                            )
                            .copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: palette.brand,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionalBanner(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: palette.brand,
            size: 24,
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earn money from your extra space',
                  style: typography.bodyMedium.toTextStyle(
                    color: palette.textPrimary,
                  ),
                ),
                SizedBox(height: spacing.xs / 2),
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to learn more
                  },
                  child: Text(
                    'Learn more',
                    style: typography.bodyMedium
                        .toTextStyle(
                          color: palette.brand,
                        )
                        .copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: palette.brand,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettingsSection(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, spacing.sm),
          child: Text(
            'Account Settings',
            style: typography.titleLarge
                .toTextStyle(
                  color: palette.textPrimary,
                )
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListItem(
                prefix: Icon(Icons.location_on_outlined, color: palette.textPrimary, size: 20),
                title: const Text('Addresses'),
                arrowIcon: Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                onClick: () {
                  context.router.push(const AddressesRoute());
                },
              ),
              AppDivider.base(axis: Axis.horizontal),
              ListItem(
                prefix: Icon(Icons.shopping_bag_outlined, color: palette.textPrimary, size: 20),
                title: const Text('My Orders'),
                arrowIcon: Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                onClick: () {
                  context.router.push(const OrdersRoute());
                },
              ),
              AppDivider.base(axis: Axis.horizontal),
              ListItem(
                prefix: Icon(Icons.translate_outlined, color: palette.textPrimary, size: 20),
                title: const Text('Translation'),
                arrowIcon: Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                onClick: () {
                  // TODO: Navigate to translation settings
                },
              ),
              AppDivider.base(axis: Axis.horizontal),
              ListItem(
                prefix: Icon(Icons.notifications_outlined, color: palette.textPrimary, size: 20),
                title: const Text('Notifications'),
                arrowIcon: Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                onClick: () {
                  // TODO: Navigate to notifications
                },
              ),
              AppDivider.base(axis: Axis.horizontal),
              ListItem(
                prefix: Icon(Icons.lock_outline, color: palette.textPrimary, size: 20),
                title: const Text('Privacy and sharing'),
                arrowIcon: Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                onClick: () {
                  // TODO: Navigate to privacy settings
                },
              ),
              AppDivider.base(axis: Axis.horizontal),
              ListItem(
                prefix: Icon(Icons.business_center_outlined, color: palette.textPrimary, size: 20),
                title: const Text('Travel for work'),
                arrowIcon: Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                onClick: () {
                  // TODO: Navigate to travel settings
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    final authService = locator.get<AuthService>();

    return MutationBuilder<bool, void>(
      mutationFn: (_) => authService.logout(),
      options: MutationOptions(
        meta: const MutationMeta(successMessage: 'Logged out successfully', errorMessage: 'Failed to logout'),
        onSuccess: (_) async {
          final queryClient = context.queryClient;
          if (queryClient != null) {
            queryClient.invalidateQuery(QueryKeys.userEmail);
            queryClient.invalidateQuery(QueryKeys.isLoggedIn);
          }
          await context.router.replace(const LoginRoute());
        },
      ),
      builder: (context, state, mutate) {
        return Button.danger(
          onPressed: state.isLoading ? null : () => mutate(null),
          isBlock: true,
          child: state.isLoading ? const WaveDots(color: Colors.white, size: 24) : const Text('Logout'),
        );
      },
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return Button.primary(
      onPressed: () => context.router.push(const LoginRoute()),
      isBlock: true,
      child: const Text('Login'),
    );
  }
}
