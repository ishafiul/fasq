import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/auth_request_otp_response.dart';
import 'package:ecommerce/api/models/auth_verify_otp_request.dart';
import 'package:ecommerce/api/models/auth_verify_otp_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/router/app_router.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/auth_service.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/input.dart';
import 'package:ecommerce/core/widgets/otp_input.dart';
import 'package:ecommerce/core/widgets/snackbar.dart';
import 'package:ecommerce/core/widgets/spinner/rotating_dots.dart';
import 'package:ecommerce/core/widgets/un_focus.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _AuthStep { email, otp }

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _otpValueNotifier = ValueNotifier<String>('');
  final _otpErrorNotifier = ValueNotifier<String?>(null);
  final _isTrustedDeviceNotifier = ValueNotifier<bool>(false);
  _AuthStep _currentStep = _AuthStep.email;

  @override
  void dispose() {
    _emailController.dispose();
    _otpValueNotifier.dispose();
    _otpErrorNotifier.dispose();
    _isTrustedDeviceNotifier.dispose();
    super.dispose();
  }

  void _handleStepChange(_AuthStep step) {
    setState(() => _currentStep = step);
  }

  @override
  Widget build(BuildContext context) {
    return Unfocus(
      child: Scaffold(
        appBar: _LoginAppBar(currentStep: _currentStep, onBackPressed: () => _handleStepChange(_AuthStep.email)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(context.spacing.md),
              children: [
                SizedBox(height: context.spacing.md),
                _LoginHeader(currentStep: _currentStep, email: _emailController.text),
                SizedBox(height: context.spacing.xl),
                if (_currentStep == _AuthStep.email)
                  _EmailStepContent(
                    formKey: _formKey,
                    emailController: _emailController,
                    onStepChanged: _handleStepChange,
                  )
                else
                  _OtpStepContent(
                    emailController: _emailController,
                    otpValueNotifier: _otpValueNotifier,
                    otpErrorNotifier: _otpErrorNotifier,
                    isTrustedDeviceNotifier: _isTrustedDeviceNotifier,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginAppBar extends StatelessWidget implements PreferredSizeWidget {
  final _AuthStep currentStep;
  final VoidCallback onBackPressed;

  const _LoginAppBar({required this.currentStep, required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('Sign in', style: context.typography.bodyLarge.toTextStyle()),
      centerTitle: true,
      elevation: 0,
      leading: currentStep == _AuthStep.otp
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBackPressed)
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _LoginHeader extends StatelessWidget {
  final _AuthStep currentStep;
  final String email;

  const _LoginHeader({required this.currentStep, required this.email});

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentStep == _AuthStep.email ? 'Welcome back' : 'Verify your email',
          style: typography.titleLarge.toTextStyle(color: palette.textPrimary),
        ),
        SizedBox(height: context.spacing.xs / 2),
        Text(
          currentStep == _AuthStep.email
              ? 'Sign in to continue to your account'
              : 'We sent a verification code to $email',
          style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _EmailStepContent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final void Function(_AuthStep) onStepChanged;

  const _EmailStepContent({required this.formKey, required this.emailController, required this.onStepChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextInputField(
          controller: emailController,
          labelText: 'Email address',
          placeholder: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          isRequired: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: context.spacing.xl),
        _RequestOtpButton(formKey: formKey, emailController: emailController, onStepChanged: onStepChanged),
        SizedBox(height: context.spacing.md),
        Center(
          child: Text(
            'You will receive a verification code',
            style: context.typography.labelSmall.toTextStyle(color: context.palette.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _OtpStepContent extends StatelessWidget {
  final TextEditingController emailController;
  final ValueNotifier<String> otpValueNotifier;
  final ValueNotifier<String?> otpErrorNotifier;
  final ValueNotifier<bool> isTrustedDeviceNotifier;

  const _OtpStepContent({
    required this.emailController,
    required this.otpValueNotifier,
    required this.otpErrorNotifier,
    required this.isTrustedDeviceNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: otpErrorNotifier,
          builder: (context, errorText, _) {
            return ValueListenableBuilder<String>(
              valueListenable: otpValueNotifier,
              builder: (context, otpValue, __) {
                return OTPInput(
                  value: otpValue,
                  length: 5,
                  errorText: errorText,
                  onChange: (otp) {
                    otpValueNotifier.value = otp;
                    otpErrorNotifier.value = null;
                  },
                );
              },
            );
          },
        ),
        SizedBox(height: context.spacing.xl),
        ValueListenableBuilder<bool>(
          valueListenable: isTrustedDeviceNotifier,
          builder: (context, isTrusted, _) {
            return _TrustDeviceCheckbox(
              isTrusted: isTrusted,
              onChanged: (value) => isTrustedDeviceNotifier.value = value,
            );
          },
        ),
        SizedBox(height: context.spacing.lg),
        ValueListenableBuilder<String>(
          valueListenable: otpValueNotifier,
          builder: (context, otpValue, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: isTrustedDeviceNotifier,
              builder: (context, isTrusted, __) {
                return _VerifyOtpButton(
                  emailController: emailController,
                  otpValue: otpValue,
                  isTrustedDevice: isTrusted,
                  onError: (error) => otpErrorNotifier.value = error,
                );
              },
            );
          },
        ),
        SizedBox(height: context.spacing.lg),
        _ResendButton(emailController: emailController),
      ],
    );
  }
}

class _RequestOtpButton extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final void Function(_AuthStep) onStepChanged;

  const _RequestOtpButton({required this.formKey, required this.emailController, required this.onStepChanged});

  @override
  Widget build(BuildContext context) {
    final authService = locator.get<AuthService>();

    return MutationBuilder<AuthRequestOtpResponse, String>(
      mutationFn: (email) => authService.requestOtp(email),
      options: MutationOptions(
        onSuccess: (result) async {
          if (result.accessToken != null) {
            context.queryClient?.invalidateQuery(const TypedQueryKey<bool>('isLoggedIn', bool));
            await showSnackBar(context: context, type: SnackBarType.info, message: result.message, withIcon: true);
            await locator.router.replace(const HomeRoute());
          } else {
            await showSnackBar(context: context, type: SnackBarType.info, message: result.message, withIcon: true);
            onStepChanged(_AuthStep.otp);
          }
        },
      ),
      builder: (context, state, mutate) {
        return Button.primary(
          onPressed: state.isLoading
              ? null
              : () async {
                  if (formKey.currentState?.validate() ?? false) {
                    await mutate(emailController.text.trim());
                  }
                },
          buttonSize: ButtonSize.large,
          isBlock: true,
          child: state.isLoading ? const WaveDots(color: Colors.white, size: 24) : const Text('Continue'),
        );
      },
    );
  }
}

class _VerifyOtpButton extends StatelessWidget {
  final TextEditingController emailController;
  final String otpValue;
  final bool isTrustedDevice;
  final void Function(String) onError;

  const _VerifyOtpButton({
    required this.emailController,
    required this.otpValue,
    required this.isTrustedDevice,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    final authService = locator.get<AuthService>();

    return MutationBuilder<AuthVerifyOtpResponse, AuthVerifyOtpRequest>(
      mutationFn: (params) {
        return authService.verifyOtp(request: params);
      },
      options: MutationOptions(
        meta: const MutationMeta(successMessage: 'Successfully signed in', errorMessage: 'Unable to verify otp'),
        onSuccess: (result) async {
          if (result.success) {
            context.queryClient?.invalidateQuery(const TypedQueryKey<bool>('isLoggedIn', bool));
            await context.router.replace(const HomeRoute());
          }
        },
        onError: (error) {
          onError(error.toString());
        },
      ),
      builder: (context, state, mutate) {
        return Button.primary(
          onPressed: state.isLoading
              ? null
              : () async {
                  if (otpValue.length == 5) {
                    final deviceId = await authService.getDeviceId();
                    if (deviceId == null) {
                      return;
                    }
                    await mutate(
                      AuthVerifyOtpRequest(
                        email: emailController.text.trim(),
                        otp: int.parse(otpValue),
                        deviceUuId: deviceId,
                        isTrusted: isTrustedDevice,
                      ),
                    );
                  } else {
                    onError('Please enter the complete code');
                  }
                },
          buttonSize: ButtonSize.large,
          isBlock: true,
          child: state.isLoading ? const WaveDots(color: Colors.white, size: 24) : const Text('Verify & Sign In'),
        );
      },
    );
  }
}

class _ResendButton extends StatelessWidget {
  final TextEditingController emailController;

  const _ResendButton({required this.emailController});

  @override
  Widget build(BuildContext context) {
    final authService = locator.get<AuthService>();
    final palette = context.palette;

    return MutationBuilder<AuthRequestOtpResponse, String>(
      mutationFn: (email) => authService.requestOtp(email),
      options: const MutationOptions(meta: MutationMeta(successMessage: 'New code sent to your email')),
      builder: (context, state, mutate) {
        return Center(
          child: Button.primary(
            fill: ButtonFill.none,
            onPressed: state.isLoading ? null : () => mutate(emailController.text.trim()),
            child: state.isLoading ? WaveDots(color: palette.brand, size: 16) : const Text('Resend Code'),
          ),
        );
      },
    );
  }
}

class _TrustDeviceCheckbox extends StatelessWidget {
  final bool isTrusted;
  final void Function(bool) onChanged;

  const _TrustDeviceCheckbox({required this.isTrusted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;
    final spacing = context.spacing;

    return InkWell(
      onTap: () => onChanged(!isTrusted),
      borderRadius: BorderRadius.circular(context.radius.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.all(spacing.xs / 2),
              child: Checkbox(
                value: isTrusted,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: palette.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trust this device', style: typography.bodySmall.toTextStyle(color: palette.textPrimary)),
                  Text(
                    'Skip verification next time',
                    style: typography.labelSmall.toTextStyle(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
