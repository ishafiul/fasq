import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/address_create_address_request.dart';
import 'package:ecommerce/api/models/address_create_address_response.dart';
import 'package:ecommerce/api/models/address_delete_address_request.dart';
import 'package:ecommerce/api/models/address_response.dart';
import 'package:ecommerce/api/models/address_set_default_address_request.dart';
import 'package:ecommerce/api/models/address_update_address_request.dart';
import 'package:injectable/injectable.dart';

@singleton
class AddressService {
  final ApiClient _apiClient;

  AddressService(this._apiClient);

  Future<List<AddressResponse>> getAddresses() async {
    return await _apiClient.address.getAddresses();
  }

  Future<AddressCreateAddressResponse> createAddress({
    required String fullName,
    required String phoneNumber,
    required String addressLine1,
    required String city,
    required String state,
    required String postalCode,
    required String country,
    String? addressLine2,
    bool? isDefault,
  }) async {
    final request = AddressCreateAddressRequest(
      fullName: fullName,
      phoneNumber: phoneNumber,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      isDefault: isDefault,
    );
    final response = await _apiClient.address.postAddresses(body: request);
    return response;
  }

  Future<void> updateAddress({
    required String id,
    String? fullName,
    String? phoneNumber,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
  }) async {
    final request = AddressUpdateAddressRequest(
      id: id,
      fullName: fullName,
      phoneNumber: phoneNumber,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
    );
    await _apiClient.address.patchAddressesId(body: request);
  }

  Future<void> deleteAddress(String id) async {
    final request = AddressDeleteAddressRequest(id: id);
    await _apiClient.address.deleteAddressesId(body: request);
  }

  Future<void> setDefaultAddress(String id) async {
    final request = AddressSetDefaultAddressRequest(id: id);
    await _apiClient.address.patchAddressesIdDefault(body: request);
  }
}
