import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/vendor_get_vendor_response.dart';
import 'package:injectable/injectable.dart';

/// Service for vendor-related operations.
///
/// This service handles all vendor API calls including:
/// - Getting vendor details by ID
@singleton
class VendorService {
  final ApiClient _apiClient;

  VendorService(this._apiClient);

  /// Gets a single vendor by ID.
  ///
  /// Returns the vendor with business name, description, logo, and status.
  Future<VendorGetVendorResponse> getVendorById(String id) async {
    return await _apiClient.vendor.getVendorsId(id: id);
  }
}

