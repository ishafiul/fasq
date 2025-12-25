import 'package:ecommerce/core/services/auth_service.dart';
import 'package:injectable/injectable.dart';

/// Service for user-related operations.
///
/// This service extends AuthService functionality for user profile operations.
@singleton
class UserService {
  final AuthService _authService;

  UserService(this._authService);

  /// Gets the current user's email.
  ///
  /// Returns the email stored during login, or null if not logged in.
  Future<String?> getUserEmail() async {
    return await _authService.getUserEmail();
  }

  /// Checks if the user is currently logged in.
  ///
  /// Returns true if an access token exists, false otherwise.
  Future<bool> isLoggedIn() async {
    return await _authService.isLoggedIn();
  }
}
