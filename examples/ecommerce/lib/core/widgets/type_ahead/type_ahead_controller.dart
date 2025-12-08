import 'package:flutter/material.dart';

/// Controller for managing TypeAhead suggestions state.
///
/// Provides programmatic control over the suggestions overlay and exposes
/// the current state of suggestions.
///
/// Usage:
/// ```dart
/// final controller = TypeAheadController<Product>();
///
/// // Open/close suggestions
/// controller.open();
/// controller.close();
///
/// // Refresh suggestions
/// controller.refresh();
///
/// // Listen to changes
/// controller.addListener(() {
///   print('Suggestions: ${controller.suggestions}');
/// });
/// ```
class TypeAheadController<T> extends ChangeNotifier {
  List<T> _suggestions = [];
  bool _isLoading = false;
  Object? _error;
  bool _isOpen = false;

  /// Current list of suggestions.
  List<T> get suggestions => _suggestions;

  /// Whether suggestions are currently being loaded.
  bool get isLoading => _isLoading;

  /// Error that occurred during suggestion fetch, if any.
  Object? get error => _error;

  /// Whether the suggestions overlay is currently visible.
  bool get isOpen => _isOpen;

  /// Whether there's an error state.
  bool get hasError => _error != null;

  /// Whether there are suggestions available.
  bool get hasSuggestions => _suggestions.isNotEmpty;

  /// Opens the suggestions overlay.
  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  /// Closes the suggestions overlay.
  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  /// Toggles the suggestions overlay.
  void toggle() {
    _isOpen ? close() : open();
  }

  /// Clears all suggestions.
  void clear() {
    _suggestions = [];
    _error = null;
    notifyListeners();
  }

  /// For external refresh, the widget needs to be aware of this call.
  /// Callback that can be set to trigger refresh operation.
  VoidCallback? onRefresh;

  /// Triggers a refresh of suggestions with the current query.
  void refresh() {
    onRefresh?.call();
  }

  /// Updates the loading state (internal use).
  void setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  /// Updates the suggestions list (internal use).
  void setSuggestions(List<T> suggestions) {
    _suggestions = suggestions;
    _error = null;
    notifyListeners();
  }

  /// Sets the error state (internal use).
  void setError(Object error) {
    _error = error;
    _suggestions = [];
    notifyListeners();
  }
}
