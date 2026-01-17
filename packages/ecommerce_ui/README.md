# Ecommerce UI

A comprehensive Flutter design system package with theme, widgets, icons, and fonts.

## Features

- **Complete Theme System**: Material 3 theme with light/dark mode support
- **Rich Widget Library**: 30+ pre-built widgets following Ant Design Mobile patterns
- **Icon Library**: 200+ SVG icons (filled, outlined, twotone variants)
- **Typography System**: Golden ratio-based typography scale
- **Spacing & Radius**: 8-point grid spacing and 4-point grid radius scales
- **Color Palette**: Semantic color system with light/dark variants

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ecommerce_ui:
    path: ../packages/ecommerce_ui
```

## Usage

### Theme Setup

```dart
import 'package:ecommerce_ui/ecommerce_ui.dart';

MaterialApp(
  theme: appTheme(Brightness.light),
  darkTheme: appTheme(Brightness.dark),
  // ...
)
```

### Using Widgets

```dart
import 'package:ecommerce_ui/ecommerce_ui.dart';

Button.primary(
  onPressed: () {},
  child: Text('Submit'),
)

TextInputField(
  controller: _controller,
  labelText: 'Email',
  placeholder: 'Enter email',
)
```

### Using Icons

```dart
import 'package:ecommerce_ui/gen/assets.gen.dart';

SvgIcon(
  svg: Assets.icons.filled.home,
  size: 24,
)
```

### Using Theme Extensions

```dart
// Spacing
SizedBox(height: context.spacing.md)

// Colors
Container(color: context.palette.brand)

// Typography
Text('Hello', style: context.typography.bodyLarge.toTextStyle())

// Radius
BorderRadius.circular(context.radius.md)
```

## Widget Catalog

### Form Widgets
- `TextInputField` - Enhanced text input with validation
- `OTPInput` - One-time password input
- `NumberStepper` - Number input with increment/decrement
- `Switch` - Animated toggle switch
- `SearchBar` - Search input with cancel button

### Display Widgets
- `Button` - Customizable button with multiple variants
- `Badge` - Notification badge
- `Tag` - Label/category tag
- `Rating` - Star rating component
- `Card` - Card with header and body
- `ListItem` - List item with title/description
- `NoData` - Empty state widget

### Navigation & Layout
- `Swiper` - Carousel/swiper widget
- `Steps` - Step indicator
- `PageIndicator` - Page dots indicator
- `Segmented` - Segmented control
- `Collapse` - Collapsible panels

### Feedback
- `SnackBar` - Custom snackbar
- `Mask` - Overlay mask
- `PullToRefresh` - Pull-to-refresh widget

### Loading & States
- `CircularProgressSpinner` - Loading spinner
- `Shimmer` - Shimmer loading effect
- `ShimmerLoading` - Conditional shimmer wrapper

### Media
- `ImageViewer` - Full-screen image viewer
- `ImageUploader` - Image upload widget
- `SvgIcon` - SVG icon wrapper

## Theme System

### Colors

The package provides a semantic color palette:

```dart
final palette = context.palette;
// palette.brand, palette.info, palette.warning, palette.success, palette.danger
// palette.textPrimary, palette.textSecondary, palette.background, palette.surface
```

### Typography

Typography scale with Golden Ratio:

```dart
context.typography.displayLarge
context.typography.headlineLarge
context.typography.titleLarge
context.typography.bodyLarge
context.typography.labelLarge
```

### Spacing

8-point grid system:

```dart
context.spacing.xs   // 8px
context.spacing.sm   // 16px
context.spacing.md   // 24px
context.spacing.lg   // 32px
// ... up to xxxxl (80px)
```

### Radius

4-point grid system:

```dart
context.radius.xs   // 4px
context.radius.sm   // 8px
context.radius.md   // 12px
context.radius.lg   // 16px
// ... up to xxxl (32px)
```

## License

See LICENSE file for details.
