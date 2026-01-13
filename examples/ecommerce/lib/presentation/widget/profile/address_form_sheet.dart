import 'package:ecommerce/api/models/address_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/input.dart';
import 'package:flutter/material.dart';

class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({
    super.key,
    this.address,
  });

  final AddressResponse? address;

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _countryController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressLine1Controller = TextEditingController();
    _addressLine2Controller = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _postalCodeController = TextEditingController();
    _countryController = TextEditingController();

    if (widget.address != null) {
      _loadAddressData();
    }
  }

  void _loadAddressData() {
    try {
      final json = widget.address!.toJson();
      _fullNameController.text = json['fullName']?.toString() ?? '';
      _phoneController.text = json['phoneNumber']?.toString() ?? '';
      _addressLine1Controller.text = json['addressLine1']?.toString() ?? '';
      _addressLine2Controller.text = json['addressLine2']?.toString() ?? '';
      _cityController.text = json['city']?.toString() ?? '';
      _stateController.text = json['state']?.toString() ?? '';
      _postalCodeController.text = json['postalCode']?.toString() ?? '';
      _countryController.text = json['country']?.toString() ?? '';
      _isDefault = json['isDefault'] == true;
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;

    return Container(
      padding: EdgeInsets.only(
        left: spacing.md,
        right: spacing.md,
        top: spacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + spacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radius.lg),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.address == null ? 'Add Address' : 'Edit Address',
              style: context.typography.titleLarge.toTextStyle(
                color: palette.textPrimary,
              ),
            ),
            SizedBox(height: spacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextInputField(
                      controller: _fullNameController,
                      labelText: 'Full Name',
                      isRequired: true,
                      placeholder: 'Enter full name',
                    ),
                    SizedBox(height: spacing.sm),
                    TextInputField(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      isRequired: true,
                      placeholder: 'Enter phone number',
                    ),
                    SizedBox(height: spacing.sm),
                    TextInputField(
                      controller: _addressLine1Controller,
                      labelText: 'Address Line 1',
                      isRequired: true,
                      placeholder: 'Enter address line 1',
                    ),
                    SizedBox(height: spacing.sm),
                    TextInputField(
                      controller: _addressLine2Controller,
                      labelText: 'Address Line 2',
                      placeholder: 'Enter address line 2 (optional)',
                    ),
                    SizedBox(height: spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextInputField(
                            controller: _cityController,
                            labelText: 'City',
                            isRequired: true,
                            placeholder: 'Enter city',
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        Expanded(
                          child: TextInputField(
                            controller: _stateController,
                            labelText: 'State',
                            isRequired: true,
                            placeholder: 'Enter state',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextInputField(
                            controller: _postalCodeController,
                            labelText: 'Postal Code',
                            isRequired: true,
                            placeholder: 'Enter postal code',
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        Expanded(
                          child: TextInputField(
                            controller: _countryController,
                            labelText: 'Country',
                            isRequired: true,
                            placeholder: 'Enter country',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.sm),
                    CheckboxListTile(
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() => _isDefault = value ?? false);
                      },
                      title: Text(
                        'Set as default address',
                        style: context.typography.bodyMedium.toTextStyle(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.md),
            Button.primary(
              onPressed: _handleSubmit,
              isBlock: true,
              child: Text(widget.address == null ? 'Add Address' : 'Update Address'),
            ),
            SizedBox(height: spacing.sm),
            Button(
              onPressed: () => Navigator.pop(context),
              isBlock: true,
              fill: ButtonFill.outline,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(
        context,
        {
          'fullName': _fullNameController.text,
          'phoneNumber': _phoneController.text,
          'addressLine1': _addressLine1Controller.text,
          'addressLine2': _addressLine2Controller.text.isEmpty ? null : _addressLine2Controller.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'postalCode': _postalCodeController.text,
          'country': _countryController.text,
          'isDefault': _isDefault,
        },
      );
    }
  }
}
