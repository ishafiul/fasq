import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/auth_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/mask.dart';
import 'package:ecommerce/core/widgets/page_indicator.dart';
import 'package:ecommerce/core/widgets/segmented.dart';
import 'package:ecommerce/core/widgets/spinner/rotating_dots.dart';
import 'package:ecommerce/core/widgets/steps/steps_export.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/core/widgets/swiper.dart';
import 'package:ecommerce/core/widgets/switch.dart';
import 'package:ecommerce/core/widgets/uploader/image_uploader.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart' hide Step, Switch;
import 'package:image_picker/image_picker.dart';

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
            Steps(
              current: 1,
              direction: StepsDirection.vertical,
              children: [
                Step(
                  title: Text('Step 1'),
                  description: Text('Description'),
                  icon: SvgIcon(svg: Assets.icons.filled.checkCircle),
                ),
                Step(
                  title: Text('Step 2'),
                  description: Text('Description'),
                  status: StepStatus.error,
                  icon: SvgIcon(svg: Assets.icons.filled.file),
                ),
                Step(title: Text('Step 3'), description: Text('Description')),
                Step(title: Text('Step 3'), description: Text('Description')),
              ],
            ),
            Segmented<String>(
              onValueChanged: (value) {
                print(value);
              },
              value: "1",
              options: [
                SegmentedOption(
                  value: "1",
                  child: Text("dddd"),
                ),
                SegmentedOption(
                    value: "2",
                    child: SvgIcon(
                      svg: Assets.icons.outlined.camera,
                      size: 42,
                    )),
                SegmentedOption(
                    value: "3",
                    child: Container(
                        padding: EdgeInsets.all(spacing.md),
                        color: Colors.white,
                        child: Text(
                          "dddd",
                        ))),
              ],
            ),
            Switch(
              checkedColor: context.palette.light,
              checkedText: Text('100'),
              uncheckedText: Text('000'),
            ),
            SizedBox(height: spacing.lg),
            // PageIndicator Examples
            Text(
              'PageIndicator Examples',
              style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
            ),
            SizedBox(height: spacing.md),
            Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Horizontal Primary',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const PageIndicator(
                      total: 5,
                      current: 2,
                      direction: PageIndicatorDirection.horizontal,
                      color: PageIndicatorColor.primary,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Horizontal White',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    Container(
                      padding: EdgeInsets.all(spacing.sm),
                      decoration: BoxDecoration(
                        color: palette.brand,
                        borderRadius: BorderRadius.circular(context.radius.sm),
                      ),
                      child: const PageIndicator(
                        total: 5,
                        current: 1,
                        direction: PageIndicatorDirection.horizontal,
                        color: PageIndicatorColor.white,
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Vertical Primary',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    Row(
                      children: [
                        const PageIndicator(
                          total: 4,
                          current: 0,
                          direction: PageIndicatorDirection.vertical,
                          color: PageIndicatorColor.primary,
                        ),
                        SizedBox(width: spacing.md),
                        const PageIndicator(
                          total: 4,
                          current: 1,
                          direction: PageIndicatorDirection.vertical,
                          color: PageIndicatorColor.primary,
                        ),
                        SizedBox(width: spacing.md),
                        const PageIndicator(
                          total: 4,
                          current: 2,
                          direction: PageIndicatorDirection.vertical,
                          color: PageIndicatorColor.primary,
                        ),
                        SizedBox(width: spacing.md),
                        const PageIndicator(
                          total: 4,
                          current: 3,
                          direction: PageIndicatorDirection.vertical,
                          color: PageIndicatorColor.primary,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Interactive Example',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _InteractivePageIndicator(),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
            // ImageUploader Examples
            Text(
              'ImageUploader Examples',
              style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
            ),
            SizedBox(height: spacing.md),
            Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grid Layout (3 columns)',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _BasicImageUploader(
                      columns: 3,
                      maxCount: 6,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Wrap Layout',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _BasicImageUploader(
                      columns: null,
                      maxCount: 4,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'With MaxCount Limit (3)',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _BasicImageUploader(
                      columns: 3,
                      maxCount: 3,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      'Custom Upload Button',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _CustomUploadButtonExample(),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
            // Mask Examples
            Text(
              'Mask Examples',
              style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
            ),
            SizedBox(height: spacing.md),
            Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Mask',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _BasicMaskExample(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Different Opacity Levels',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _OpacityMaskExamples(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Different Colors',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    _ColorMaskExamples(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Interactive Example',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _InteractiveMaskExample(),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
            // Swiper Examples
            Text(
              'Swiper Examples',
              style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
            ),
            SizedBox(height: spacing.md),
            Card(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Swiper',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _BasicSwiperExample(),
                    SizedBox(height: spacing.md),
                    Text(
                      'With Autoplay',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _AutoplaySwiperExample(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Loop Mode',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _LoopSwiperExample(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Without Indicator',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _NoIndicatorSwiperExample(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Custom Indicator',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _CustomIndicatorSwiperExample(),
                    SizedBox(height: spacing.md),
                    Text(
                      'Interactive Example',
                      style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    ),
                    SizedBox(height: spacing.xs),
                    const _InteractiveSwiperExample(),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.lg),
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
                        Text('Email', style: typography.bodyMedium.toTextStyle(color: palette.textSecondary)),
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
            // Login/Logout Button
            QueryBuilder<bool>(
              queryKey: QueryKeys.isLoggedIn,
              queryFn: () => locator.get<UserService>().isLoggedIn(),
              builder: (context, state) {
                if (state.isLoading) {
                  return const SizedBox.shrink();
                }

                final isLoggedIn = state.data ?? false;

                if (isLoggedIn) {
                  return const _LogoutButton();
                } else {
                  return const _LoginButton();
                }
              },
            ),
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

class _InteractivePageIndicator extends StatefulWidget {
  const _InteractivePageIndicator();

  @override
  State<_InteractivePageIndicator> createState() => _InteractivePageIndicatorState();
}

class _InteractivePageIndicatorState extends State<_InteractivePageIndicator> {
  int _currentIndex = 0;
  final int _total = 6;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIndicator(
          total: _total,
          current: _currentIndex,
          direction: PageIndicatorDirection.horizontal,
          color: PageIndicatorColor.primary,
        ),
        SizedBox(height: spacing.sm),
        Row(
          children: [
            Button(
              onPressed: _currentIndex > 0
                  ? () {
                      setState(() {
                        _currentIndex--;
                      });
                    }
                  : null,
              child: const Text('Previous'),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: Center(
                child: Text(
                  'Page ${_currentIndex + 1} of $_total',
                  style: context.typography.bodySmall.toTextStyle(color: palette.textSecondary),
                ),
              ),
            ),
            SizedBox(width: spacing.xs),
            Button(
              onPressed: _currentIndex < _total - 1
                  ? () {
                      setState(() {
                        _currentIndex++;
                      });
                    }
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BasicImageUploader extends StatefulWidget {
  const _BasicImageUploader({
    this.columns,
    this.maxCount = 0,
  });

  final int? columns;
  final int maxCount;

  @override
  State<_BasicImageUploader> createState() => _BasicImageUploaderState();
}

class _BasicImageUploaderState extends State<_BasicImageUploader> {
  List<ImageUploadItem> _items = [];

  Future<ImageUploadItem> _upload(XFile file) async {
    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 2));

    // In a real app, this would upload to your server
    // For demo purposes, we'll create a mock URL
    return ImageUploadItem(
      url: 'https://picsum.photos/seed/${file.name}/400/400',
      thumbnailUrl: 'https://picsum.photos/seed/${file.name}/200/200',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ImageUploader(
      upload: _upload,
      value: _items,
      onChange: (items) {
        setState(() {
          _items = items;
        });
      },
      columns: widget.columns,
      maxCount: widget.maxCount,
      onCountExceed: (exceed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum ${widget.maxCount} images allowed. $exceed image(s) exceeded.')),
        );
      },
      onPreview: (index, item) {
        // In a real app, you would open photo_view here
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview image ${index + 1}: ${item.url}')),
        );
      },
    );
  }
}

class _CustomUploadButtonExample extends StatefulWidget {
  const _CustomUploadButtonExample();

  @override
  State<_CustomUploadButtonExample> createState() => _CustomUploadButtonExampleState();
}

class _CustomUploadButtonExampleState extends State<_CustomUploadButtonExample> {
  List<ImageUploadItem> _items = [];

  Future<ImageUploadItem> _upload(XFile file) async {
    await Future.delayed(const Duration(seconds: 2));
    return ImageUploadItem(
      url: 'https://picsum.photos/seed/${file.name}/400/400',
      thumbnailUrl: 'https://picsum.photos/seed/${file.name}/200/200',
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final palette = context.palette;

    return ImageUploader(
      upload: _upload,
      value: _items,
      onChange: (items) {
        setState(() {
          _items = items;
        });
      },
      columns: 3,
      maxCount: 6,
      child: Container(
        padding: EdgeInsets.all(spacing.xs),
        decoration: BoxDecoration(
          color: palette.brand.withValues(alpha: 0.1),
          borderRadius: radius.all(radius.xs),
          border: Border.all(color: palette.brand, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgIcon(
              svg: Assets.icons.outlined.plus,
              size: 32,
              color: palette.brand,
            ),
            SizedBox(height: spacing.xs / 2),
            Text(
              'Add Photo',
              style: context.typography.labelSmall.toTextStyle(color: palette.brand),
            ),
          ],
        ),
      ),
      onPreview: (index, item) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview image ${index + 1}')),
        );
      },
    );
  }
}

class _BasicMaskExample extends StatefulWidget {
  const _BasicMaskExample();

  @override
  State<_BasicMaskExample> createState() => _BasicMaskExampleState();
}

class _BasicMaskExampleState extends State<_BasicMaskExample> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;

    return Button.primary(
      onPressed: () {
        _overlayEntry?.remove();
        _overlayEntry = showMask(
          context: context,
          onMaskClick: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
          child: Center(
            child: Container(
              padding: EdgeInsets.all(spacing.md),
              margin: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Basic Mask',
                    style: context.typography.titleMedium.toTextStyle(color: palette.textPrimary),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'Click outside to close',
                    style: context.typography.bodySmall.toTextStyle(color: palette.textSecondary),
                  ),
                  SizedBox(height: spacing.md),
                  Button(
                    onPressed: () {
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: const Text('Show Basic Mask'),
    );
  }
}

class _OpacityMaskExamples extends StatelessWidget {
  const _OpacityMaskExamples();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [
        _OpacityMaskButton(
          label: 'Thin',
          opacity: MaskOpacity.thin,
        ),
        _OpacityMaskButton(
          label: 'Default',
          opacity: MaskOpacity.default_,
        ),
        _OpacityMaskButton(
          label: 'Thick',
          opacity: MaskOpacity.thick,
        ),
        _OpacityMaskButton(
          label: 'Custom 0.3',
          opacity: MaskOpacity.default_,
          customOpacity: 0.3,
        ),
      ],
    );
  }
}

class _OpacityMaskButton extends StatefulWidget {
  const _OpacityMaskButton({
    required this.label,
    required this.opacity,
    this.customOpacity,
  });

  final String label;
  final MaskOpacity opacity;
  final double? customOpacity;

  @override
  State<_OpacityMaskButton> createState() => _OpacityMaskButtonState();
}

class _OpacityMaskButtonState extends State<_OpacityMaskButton> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;

    return Button(
      onPressed: () {
        _overlayEntry?.remove();
        _overlayEntry = showMask(
          context: context,
          opacity: widget.opacity,
          customOpacity: widget.customOpacity,
          onMaskClick: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
          child: Center(
            child: Container(
              padding: EdgeInsets.all(spacing.md),
              margin: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.label} Opacity',
                    style: context.typography.titleSmall.toTextStyle(color: palette.textPrimary),
                  ),
                  SizedBox(height: spacing.sm),
                  Button(
                    onPressed: () {
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Text(widget.label),
    );
  }
}

class _ColorMaskExamples extends StatelessWidget {
  const _ColorMaskExamples();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [
        _ColorMaskButton(
          label: 'Black',
          color: MaskColor.black,
        ),
        _ColorMaskButton(
          label: 'White',
          color: MaskColor.white,
        ),
        _ColorMaskButton(
          label: 'Custom',
          color: MaskColor.black,
          customColor: context.palette.brand,
        ),
      ],
    );
  }
}

class _ColorMaskButton extends StatefulWidget {
  const _ColorMaskButton({
    required this.label,
    required this.color,
    this.customColor,
  });

  final String label;
  final MaskColor color;
  final Color? customColor;

  @override
  State<_ColorMaskButton> createState() => _ColorMaskButtonState();
}

class _ColorMaskButtonState extends State<_ColorMaskButton> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;

    return Button(
      onPressed: () {
        _overlayEntry?.remove();
        _overlayEntry = showMask(
          context: context,
          color: widget.color,
          customColor: widget.customColor,
          onMaskClick: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
          child: Center(
            child: Container(
              padding: EdgeInsets.all(spacing.md),
              margin: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.label} Color',
                    style: context.typography.titleSmall.toTextStyle(
                      color: widget.color == MaskColor.white ? Colors.black : Colors.white,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Button(
                    onPressed: () {
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Text(widget.label),
    );
  }
}

class _InteractiveMaskExample extends StatefulWidget {
  const _InteractiveMaskExample();

  @override
  State<_InteractiveMaskExample> createState() => _InteractiveMaskExampleState();
}

class _InteractiveMaskExampleState extends State<_InteractiveMaskExample> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;
    final typography = context.typography;

    return Button.primary(
      onPressed: () {
        _overlayEntry?.remove();
        _overlayEntry = showMask(
          context: context,
          opacity: MaskOpacity.default_,
          afterShow: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mask shown')),
            );
          },
          afterClose: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mask closed')),
            );
          },
          onMaskClick: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
          child: Center(
            child: Container(
              padding: EdgeInsets.all(spacing.lg),
              margin: EdgeInsets.all(spacing.md),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(context.radius.lg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Interactive Mask',
                    style: typography.titleLarge.toTextStyle(color: palette.textPrimary),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'This mask demonstrates callbacks and content display.',
                    style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Button(
                        onPressed: () {
                          _overlayEntry?.remove();
                          _overlayEntry = null;
                        },
                        child: const Text('Close'),
                      ),
                      SizedBox(width: spacing.xs),
                      Button.primary(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Action button clicked')),
                          );
                        },
                        child: const Text('Action'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: const Text('Show Interactive Mask'),
    );
  }
}

class _BasicSwiperExample extends StatelessWidget {
  const _BasicSwiperExample();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 200,
      child: Swiper(
        children: [
          SwiperItem(
            child: Container(
              color: palette.brand,
              child: Center(
                child: Text(
                  'Slide 1',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.info,
              child: Center(
                child: Text(
                  'Slide 2',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.success,
              child: Center(
                child: Text(
                  'Slide 3',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoplaySwiperExample extends StatelessWidget {
  const _AutoplaySwiperExample();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 200,
      child: Swiper(
        autoplay: SwiperAutoplay.forward,
        autoplayInterval: const Duration(seconds: 2),
        children: [
          SwiperItem(
            child: Container(
              color: palette.warning,
              child: Center(
                child: Text(
                  'Auto 1',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.danger,
              child: Center(
                child: Text(
                  'Auto 2',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.brand,
              child: Center(
                child: Text(
                  'Auto 3',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopSwiperExample extends StatelessWidget {
  const _LoopSwiperExample();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 200,
      child: Swiper(
        loop: true,
        children: [
          SwiperItem(
            child: Container(
              color: palette.brand,
              child: Center(
                child: Text(
                  'Loop 1',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.info,
              child: Center(
                child: Text(
                  'Loop 2',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.success,
              child: Center(
                child: Text(
                  'Loop 3',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoIndicatorSwiperExample extends StatelessWidget {
  const _NoIndicatorSwiperExample();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 200,
      child: Swiper(
        showIndicator: false,
        children: [
          SwiperItem(
            child: Container(
              color: palette.warning,
              child: Center(
                child: Text(
                  'No Indicator 1',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.danger,
              child: Center(
                child: Text(
                  'No Indicator 2',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomIndicatorSwiperExample extends StatelessWidget {
  const _CustomIndicatorSwiperExample();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 200,
      child: Swiper(
        indicator: (total, current) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm, vertical: context.spacing.xs),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(context.radius.sm),
            ),
            child: Text(
              '${current + 1} / $total',
              style: context.typography.bodySmall.toTextStyle(color: Colors.white),
            ),
          );
        },
        children: [
          SwiperItem(
            child: Container(
              color: palette.brand,
              child: Center(
                child: Text(
                  'Custom 1',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.info,
              child: Center(
                child: Text(
                  'Custom 2',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          SwiperItem(
            child: Container(
              color: palette.success,
              child: Center(
                child: Text(
                  'Custom 3',
                  style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveSwiperExample extends StatefulWidget {
  const _InteractiveSwiperExample();

  @override
  State<_InteractiveSwiperExample> createState() => _InteractiveSwiperExampleState();
}

class _InteractiveSwiperExampleState extends State<_InteractiveSwiperExample> {
  final SwiperRef _swiperRef = SwiperRef();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: Swiper(
            ref: _swiperRef,
            defaultIndex: _currentIndex,
            onIndexChange: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              SwiperItem(
                child: Container(
                  color: palette.brand,
                  child: Center(
                    child: Text(
                      'Slide 1',
                      style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              SwiperItem(
                child: Container(
                  color: palette.info,
                  child: Center(
                    child: Text(
                      'Slide 2',
                      style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              SwiperItem(
                child: Container(
                  color: palette.success,
                  child: Center(
                    child: Text(
                      'Slide 3',
                      style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              SwiperItem(
                child: Container(
                  color: palette.warning,
                  child: Center(
                    child: Text(
                      'Slide 4',
                      style: context.typography.titleLarge.toTextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        Row(
          children: [
            Button(
              onPressed: _currentIndex > 0
                  ? () {
                      _swiperRef.swipePrev();
                    }
                  : null,
              child: const Text('Previous'),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: Center(
                child: Text(
                  'Slide ${_currentIndex + 1} of 4',
                  style: context.typography.bodySmall.toTextStyle(color: palette.textSecondary),
                ),
              ),
            ),
            SizedBox(width: spacing.xs),
            Button(
              onPressed: _currentIndex < 3
                  ? () {
                      _swiperRef.swipeNext();
                    }
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
