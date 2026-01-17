import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/address_response.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/address_service.dart';
import 'package:ecommerce/presentation/widget/cart/cart_icon_button.dart';
import 'package:ecommerce/presentation/widget/profile/address_form_sheet.dart';
import 'package:ecommerce/presentation/widget/profile/address_list_item.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          CartIconButton(),
        ],
      ),
      body: QueryBuilder<List<AddressResponse>>(
        queryKey: QueryKeys.addresses,
        queryFn: () => locator.get<AddressService>().getAddresses(),
        builder: (context, state) {
          if (state.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: palette.brand),
            );
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading addresses',
                    style: typography.bodyLarge.toTextStyle(
                      color: palette.danger,
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Button.primary(
                    onPressed: () {
                      context.queryClient?.invalidateQuery(QueryKeys.addresses);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final addresses = state.data ?? [];

          return Column(
            children: [
              Expanded(
                child: addresses.isEmpty
                    ? Center(
                        child: NoData(
                          message: 'No addresses found. Add your first address.',
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.all(spacing.md),
                        children: addresses.map((address) {
                          final json = address.toJson();
                          final isDefault = json['isDefault'] == true;
                          return AddressListItem(
                            address: address,
                            isDefault: isDefault,
                            onEdit: () => _showEditAddressSheet(context, address),
                            onDelete: () => _handleDeleteAddress(context, address),
                            onSetDefault: () => _handleSetDefaultAddress(context, address),
                          );
                        }).toList(),
                      ),
              ),
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Button.primary(
                  onPressed: () => _showAddAddressSheet(context),
                  isBlock: true,
                  child: const Text('Add New Address'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => AddressFormSheet(
          key: const ValueKey('add'),
        ),
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        _handleAddAddress(context, result);
      }
    });
  }

  void _showEditAddressSheet(BuildContext context, AddressResponse address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => AddressFormSheet(
          key: ValueKey('edit-${address.hashCode}'),
          address: address,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        _handleUpdateAddress(context, address, result);
      }
    });
  }

  Future<void> _handleAddAddress(BuildContext context, Map<String, dynamic> data) async {
    final addressService = locator.get<AddressService>();
    final queryClient = context.queryClient;

    try {
      await addressService.createAddress(
        fullName: data['fullName'] as String,
        phoneNumber: data['phoneNumber'] as String,
        addressLine1: data['addressLine1'] as String,
        city: data['city'] as String,
        state: data['state'] as String,
        postalCode: data['postalCode'] as String,
        country: data['country'] as String,
        addressLine2: data['addressLine2'] as String?,
        isDefault: data['isDefault'] as bool?,
      );

      queryClient?.invalidateQuery(QueryKeys.addresses);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address added successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding address: $e')),
        );
      }
    }
  }

  Future<void> _handleUpdateAddress(
    BuildContext context,
    AddressResponse address,
    Map<String, dynamic> data,
  ) async {
    final addressService = locator.get<AddressService>();
    final queryClient = context.queryClient;

    try {
      final json = address.toJson();
      final id = json['id']?.toString();
      if (id == null) return;

      await addressService.updateAddress(
        id: id,
        fullName: data['fullName'] as String?,
        phoneNumber: data['phoneNumber'] as String?,
        addressLine1: data['addressLine1'] as String?,
        addressLine2: data['addressLine2'] as String?,
        city: data['city'] as String?,
        state: data['state'] as String?,
        postalCode: data['postalCode'] as String?,
        country: data['country'] as String?,
      );

      queryClient?.invalidateQuery(QueryKeys.addresses);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address updated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating address: $e')),
        );
      }
    }
  }

  Future<void> _handleDeleteAddress(BuildContext context, AddressResponse address) async {
    final addressService = locator.get<AddressService>();
    final queryClient = context.queryClient;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final json = address.toJson();
      final id = json['id']?.toString();
      if (id == null) return;

      await addressService.deleteAddress(id);
      queryClient?.invalidateQuery(QueryKeys.addresses);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting address: $e')),
        );
      }
    }
  }

  Future<void> _handleSetDefaultAddress(BuildContext context, AddressResponse address) async {
    final addressService = locator.get<AddressService>();
    final queryClient = context.queryClient;

    try {
      final json = address.toJson();
      final id = json['id']?.toString();
      if (id == null) return;

      await addressService.setDefaultAddress(id);
      queryClient?.invalidateQuery(QueryKeys.addresses);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default address updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting default address: $e')),
        );
      }
    }
  }
}
