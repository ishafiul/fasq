import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Represents an uploaded image item.
class ImageUploadItem {
  const ImageUploadItem({
    this.key,
    required this.url,
    this.thumbnailUrl,
    this.extra,
  });

  /// Optional unique key for the item.
  final String? key;

  /// Image URL.
  final String url;

  /// Optional thumbnail URL.
  final String? thumbnailUrl;

  /// Optional extra data.
  final Object? extra;
}

/// Upload task status.
enum UploadTaskStatus {
  pending,
  success,
  fail,
}

/// Represents an upload task.
class UploadTask {
  const UploadTask({
    required this.id,
    required this.file,
    required this.status,
    this.url,
  });

  /// Unique task ID.
  final int id;

  /// File being uploaded.
  final XFile file;

  /// Current upload status.
  final UploadTaskStatus status;

  /// Uploaded URL (when status is success).
  final String? url;
}

/// A widget that allows users to select, upload, preview, and delete images.
///
/// Features:
/// - Grid and wrap layouts
/// - Upload states (pending, success, fail)
/// - Max count limits
/// - Customizable rendering
/// - Preview and delete functionality
///
/// Usage:
/// ```dart
/// ImageUploader(
///   upload: (file) async {
///     // Upload file and return ImageUploadItem
///     return ImageUploadItem(url: 'https://example.com/image.jpg');
///   },
///   onChange: (items) {
///     print('Uploaded ${items.length} images');
///   },
/// )
/// ```
class ImageUploader extends StatefulWidget {
  const ImageUploader({
    super.key,
    required this.upload,
    this.value,
    this.defaultValue,
    this.onChange,
    this.columns,
    this.maxCount = 0,
    this.onCountExceed,
    this.multiple = false,
    this.accept = 'image/*',
    this.deletable = true,
    this.deleteIcon,
    this.showUpload = true,
    this.disableUpload = false,
    this.preview = true,
    this.onPreview,
    this.beforeUpload,
    this.onDelete,
    this.onUploadQueueChange,
    this.showFailed = true,
    this.imageFit = BoxFit.cover,
    this.renderItem,
    this.cellSize,
    this.gap,
    this.gapVertical,
    this.gapHorizontal,
    this.child,
  });

  /// Upload function that takes a file and returns an ImageUploadItem.
  final Future<ImageUploadItem> Function(XFile file) upload;

  /// Controlled value.
  final List<ImageUploadItem>? value;

  /// Default value.
  final List<ImageUploadItem>? defaultValue;

  /// Change callback.
  final void Function(List<ImageUploadItem>)? onChange;

  /// Grid columns (null = wrap layout).
  final int? columns;

  /// Maximum number of images (0 = unlimited).
  final int maxCount;

  /// Called when maxCount is exceeded.
  final void Function(int exceed)? onCountExceed;

  /// Allow multiple selection.
  final bool multiple;

  /// File type filter.
  final String accept;

  /// Show delete button.
  final bool deletable;

  /// Custom delete icon.
  final Widget? deleteIcon;

  /// Show upload button.
  final bool showUpload;

  /// Disable upload button.
  final bool disableUpload;

  /// Enable preview on tap.
  final bool preview;

  /// Preview callback.
  final void Function(int index, ImageUploadItem item)? onPreview;

  /// Transform file before upload (return null to skip).
  final Future<XFile?> Function(XFile file, List<XFile> files)? beforeUpload;

  /// Delete callback (return false to prevent deletion).
  final Future<bool> Function(ImageUploadItem item)? onDelete;

  /// Upload queue change callback.
  final void Function(List<UploadTask> tasks)? onUploadQueueChange;

  /// Show failed uploads.
  final bool showFailed;

  /// Image fit mode.
  final BoxFit imageFit;

  /// Custom render function.
  final Widget Function(Widget originNode, ImageUploadItem item, List<ImageUploadItem> items)? renderItem;

  /// Custom cell size (default: calculated from columns).
  final double? cellSize;

  /// Custom gap between items (default: 12.0).
  final double? gap;

  /// Vertical gap override.
  final double? gapVertical;

  /// Horizontal gap override.
  final double? gapHorizontal;

  /// Custom upload button widget.
  final Widget? child;

  @override
  State<ImageUploader> createState() => _ImageUploaderState();
}

class _ImageUploaderState extends State<ImageUploader> {
  late List<ImageUploadItem> _value;
  final List<UploadTask> _tasks = [];
  final ImagePicker _picker = ImagePicker();
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.value ?? widget.defaultValue ?? [];
  }

  @override
  void didUpdateWidget(ImageUploader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value ?? [];
    }
  }

  void _setValue(List<ImageUploadItem> newValue) {
    if (widget.value == null) {
      setState(() {
        _value = newValue;
      });
    }
    widget.onChange?.call(newValue);
  }

  Future<void> _pickImages() async {
    if (widget.disableUpload) return;

    final List<XFile> pickedFiles;

    if (widget.multiple) {
      pickedFiles = await _picker.pickMultiImage();
    } else {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      pickedFiles = file != null ? [file] : [];
    }

    if (pickedFiles.isEmpty) return;

    // Apply beforeUpload transformation
    List<XFile> files = pickedFiles;
    if (widget.beforeUpload != null) {
      final transformedFiles = <XFile>[];
      for (final file in files) {
        final transformed = await widget.beforeUpload!(file, files);
        if (transformed != null) {
          transformedFiles.add(transformed);
        }
      }
      files = transformedFiles;
    }

    if (files.isEmpty) return;

    // Check maxCount
    final currentCount = _value.length + _getVisibleTasks().length;
    if (widget.maxCount > 0 && currentCount + files.length > widget.maxCount) {
      final exceed = currentCount + files.length - widget.maxCount;
      widget.onCountExceed?.call(exceed);
      files = files.take(widget.maxCount - currentCount).toList();
      if (files.isEmpty) return;
    }

    // Create tasks
    final newTasks = files.map((file) {
      return UploadTask(
        id: _idCounter++,
        file: file,
        status: UploadTaskStatus.pending,
      );
    }).toList();

    setState(() {
      _tasks.addAll(newTasks);
    });

    _notifyUploadQueueChange();

    // Upload files
    final newItems = <ImageUploadItem>[];
    for (final task in newTasks) {
      try {
        final result = await widget.upload(task.file);
        newItems.add(result);

        // Remove successful task immediately - it's now in the items list
        setState(() {
          _tasks.removeWhere((t) => t.id == task.id);
        });
        _notifyUploadQueueChange();
      } catch (e) {
        setState(() {
          final index = _tasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _tasks[index] = UploadTask(
              id: task.id,
              file: task.file,
              status: UploadTaskStatus.fail,
            );
          }
        });
        _notifyUploadQueueChange();
      }
    }

    // Add successful uploads to value
    if (newItems.isNotEmpty) {
      _setValue([..._value, ...newItems]);
    }
  }

  void _cleanupTasks() {
    setState(() {
      _tasks.removeWhere((task) {
        if (task.url == null) return false;
        return _value.any((item) => item.url == task.url);
      });
    });
    _notifyUploadQueueChange();
  }

  List<UploadTask> _getVisibleTasks() {
    // Don't show successful tasks - they're already in the items list
    final filtered = _tasks.where((task) => task.status != UploadTaskStatus.success).toList();

    if (widget.showFailed) {
      return filtered;
    }
    return filtered.where((task) => task.status != UploadTaskStatus.fail).toList();
  }

  void _notifyUploadQueueChange() {
    widget.onUploadQueueChange?.call(
      _tasks.map((t) => UploadTask(id: t.id, file: t.file, status: t.status, url: t.url)).toList(),
    );
  }

  Future<void> _handleDelete(ImageUploadItem item) async {
    final canDelete = await widget.onDelete?.call(item);
    if (canDelete == false) return;

    _setValue(_value.where((i) => i.url != item.url).toList());
    _cleanupTasks();
  }

  void _handlePreview(int index, ImageUploadItem item) {
    if (widget.preview) {
      widget.onPreview?.call(index, item);
    }
  }

  bool _shouldShowUpload() {
    if (!widget.showUpload) return false;
    if (widget.maxCount == 0) return true;
    final currentCount = _value.length + _getVisibleTasks().length;
    return currentCount < widget.maxCount;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final palette = context.palette;

    final effectiveGap = widget.gap ?? 12.0;
    final effectiveGapVertical = widget.gapVertical ?? effectiveGap;
    final effectiveGapHorizontal = widget.gapHorizontal ?? effectiveGap;

    final items = <Widget>[];
    for (int index = 0; index < _value.length; index++) {
      final item = _value[index];
      final originNode = PreviewItem(
        key: ValueKey(item.key ?? item.url),
        url: item.thumbnailUrl ?? item.url,
        deletable: widget.deletable,
        deleteIcon: widget.deleteIcon,
        imageFit: widget.imageFit,
        onClick: () => _handlePreview(index, item),
        onDelete: () => _handleDelete(item),
      );

      if (widget.renderItem != null) {
        items.add(widget.renderItem!(originNode, item, _value));
      } else {
        items.add(originNode);
      }
    }

    final tasks = _getVisibleTasks();
    final taskWidgets = <Widget>[];
    for (final task in tasks) {
      taskWidgets.add(
        PreviewItem(
          key: ValueKey('task-${task.id}'),
          file: task.file,
          status: task.status,
          deletable: task.status != UploadTaskStatus.pending,
          deleteIcon: widget.deleteIcon,
          imageFit: widget.imageFit,
          onDelete: () {
            setState(() {
              _tasks.removeWhere((t) => t.id == task.id);
            });
            _notifyUploadQueueChange();
          },
        ),
      );
    }

    final allItems = [...items, ...taskWidgets];

    if (_shouldShowUpload()) {
      allItems.add(_buildUploadButton(context, spacing, radius, palette));
    }

    if (widget.columns != null) {
      return _buildGridLayout(context, allItems, effectiveGapVertical, effectiveGapHorizontal, spacing, radius);
    }

    return _buildWrapLayout(context, allItems, effectiveGapVertical, effectiveGapHorizontal);
  }

  Widget _buildGridLayout(
    BuildContext context,
    List<Widget> items,
    double gapVertical,
    double gapHorizontal,
    Spacing spacing,
    RadiusScale radius,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = widget.columns!;
        final cellSize = widget.cellSize ?? ((constraints.maxWidth - gapHorizontal * (columns - 1)) / columns);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gapVertical,
            crossAxisSpacing: gapHorizontal,
            childAspectRatio: 1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: items[index],
            );
          },
        );
      },
    );
  }

  Widget _buildWrapLayout(
    BuildContext context,
    List<Widget> items,
    double gapVertical,
    double gapHorizontal,
  ) {
    final cellSize = widget.cellSize ?? 80.0;

    return Wrap(
      spacing: gapHorizontal,
      runSpacing: gapVertical,
      children: items.map((item) {
        return SizedBox(
          width: cellSize,
          height: cellSize,
          child: item,
        );
      }).toList(),
    );
  }

  Widget _buildUploadButton(
    BuildContext context,
    Spacing spacing,
    RadiusScale radius,
    AppPalette palette,
  ) {
    if (widget.child != null) {
      return Stack(
        children: [
          widget.child!,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.disableUpload ? null : _pickImages,
                borderRadius: radius.all(radius.xs),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: widget.disableUpload ? null : _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: radius.all(radius.xs),
        ),
        child: Center(
          child: SvgIcon(
            svg: Assets.icons.outlined.plus,
            size: 32,
            color: palette.weak,
          ),
        ),
      ),
    );
  }
}

/// Preview item widget for displaying individual images in the uploader.
class PreviewItem extends StatelessWidget {
  const PreviewItem({
    super.key,
    this.url,
    this.thumbnailUrl,
    this.file,
    this.status,
    required this.deletable,
    this.deleteIcon,
    this.onClick,
    this.onDelete,
    this.imageFit = BoxFit.cover,
  });

  /// Image URL.
  final String? url;

  /// Thumbnail URL.
  final String? thumbnailUrl;

  /// Local file (for preview before upload).
  final XFile? file;

  /// Upload status.
  final UploadTaskStatus? status;

  /// Show delete button.
  final bool deletable;

  /// Custom delete icon.
  final Widget? deleteIcon;

  /// Tap callback.
  final VoidCallback? onClick;

  /// Delete callback.
  final VoidCallback? onDelete;

  /// Image fit mode.
  final BoxFit imageFit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = context.radius;
    final spacing = context.spacing;

    final imageUrl = url ?? thumbnailUrl;
    final isFailed = status == UploadTaskStatus.fail;
    final isLoading = status == UploadTaskStatus.pending;

    return GestureDetector(
      onTap: onClick,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius.all(radius.xs),
          border: isFailed ? Border.all(color: palette.danger, width: 1) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: imageFit,
                placeholder: (context, url) => ColoredBox(
                  color: palette.surface,
                  child: Center(
                    child: CircularProgressSpinner(color: palette.brand, size: 24, strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => ColoredBox(
                  color: palette.surface,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: palette.weak,
                    size: spacing.lg,
                  ),
                ),
              )
            else if (file != null)
              Image.file(
                File(file!.path),
                fit: imageFit,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: palette.surface,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: palette.weak,
                    size: spacing.lg,
                  ),
                ),
              )
            else
              ColoredBox(
                color: palette.surface,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: palette.weak,
                  size: spacing.lg,
                ),
              ),

            // Loading overlay
            if (isLoading)
              Container(
                color: const Color(0xFF323233).withValues(alpha: 0.88),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressSpinner(color: Colors.white, size: 24, strokeWidth: 2),
                    SizedBox(height: spacing.xs / 2),
                    Text(
                      'Uploading',
                      style: context.typography.bodySmall.toTextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),

            // Delete button
            if (deletable && onDelete != null)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: deleteIcon ??
                          SvgIcon(
                            svg: Assets.icons.outlined.close,
                            size: 8,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
