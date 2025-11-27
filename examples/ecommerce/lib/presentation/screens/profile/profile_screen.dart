import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/auth_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/spinner/rotating_dots.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Email Section
            QueryBuilder<String?>(
              queryKey: QueryKeys.userEmail,
              queryFn: () => locator.get<UserService>().getUserEmail(),
              builder: (context, state) {
                if (state.isLoading) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.xl),
                      child: CircularProgressIndicator(color: palette.brand),
                    ),
                  );
                }

                final email = state.data;

                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email', style: typography.labelSmall.toTextStyle(color: palette.textSecondary)),
                        SizedBox(height: spacing.xs),
                        Text(
                          email ?? 'Not logged in',
                          style: typography.bodyLarge.toTextStyle(color: palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: spacing.lg),
            // Logout Button
            _LogoutButton(),
          ],
        ),
      ),
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
