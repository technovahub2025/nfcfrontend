import 'package:flutter/material.dart';

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({super.key});

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _designationController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _googleBusinessController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _googleBusinessController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final result = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'company': _companyController.text.trim(),
      'designation': _designationController.text.trim(),
      'address': _addressController.text.trim(),
      'website': _websiteController.text.trim(),
      'linkedin': _linkedinController.text.trim(),
      'instagram': _instagramController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'twitter': _twitterController.text.trim(),
      'googleBusiness': _googleBusinessController.text.trim(),
      'type': 'MANUAL',
      'bio': '',
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Details'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildField(
                controller: _nameController,
                label: 'Name',
                icon: Icons.person,
                requiredField: true,
              ),
              _buildField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                requiredField: true,
              ),
              _buildField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildField(
                controller: _companyController,
                label: 'Business Name',
                icon: Icons.business,
              ),
              _buildField(
                controller: _designationController,
                label: 'Designation',
                icon: Icons.badge,
              ),
              _buildField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                maxLines: 2,
              ),
              _buildField(
                controller: _websiteController,
                label: 'Website',
                icon: Icons.language,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _linkedinController,
                label: 'LinkedIn Link',
                icon: Icons.work,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _instagramController,
                label: 'Instagram Link',
                icon: Icons.camera_alt,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _facebookController,
                label: 'Facebook Link',
                icon: Icons.facebook,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _twitterController,
                label: 'Twitter/X Link',
                icon: Icons.alternate_email,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                controller: _googleBusinessController,
                label: 'Google Business Link',
                icon: Icons.store,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
