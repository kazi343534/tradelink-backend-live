import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/supabase_config.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final String currentLanguage;

  const EditProfileScreen({super.key, required this.initialData, this.currentLanguage = 'English'});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _businessNameController;
  late TextEditingController _categoryController;
  late TextEditingController _addressController;
  late TextEditingController _openingTimeController;
  late TextEditingController _closingTimeController;
  late TextEditingController _taxIdController;

  bool _isLoading = false;

  final Map<String, Map<String, String>> _localizedStrings = {
    'English': {
      'Edit Profile': 'Edit Profile',
      'Personal Details': 'Personal Details',
      'Full Name': 'Full Name',
      'Phone Number': 'Phone Number',
      'Email': 'Email',
      'Shop Details': 'Shop Details',
      'Business Name': 'Business Name',
      'Category': 'Category',
      'Address': 'Address',
      'Opening Time': 'Opening Time (e.g. 09:00 AM)',
      'Closing Time': 'Closing Time (e.g. 10:00 PM)',
      'Tax ID': 'Tax ID',
      'Save Changes': 'Save Changes',
      'Profile updated successfully': 'Profile updated successfully',
      'Error updating profile:': 'Error updating profile:',
    },
    'Bangla': {
      'Edit Profile': 'প্রোফাইল সম্পাদনা করুন',
      'Personal Details': 'ব্যক্তিগত বিবরণ',
      'Full Name': 'পুরো নাম',
      'Phone Number': 'ফোন নম্বর',
      'Email': 'ইমেইল',
      'Shop Details': 'দোকানের বিবরণ',
      'Business Name': 'ব্যবসার নাম',
      'Category': 'বিভাগ',
      'Address': 'ঠিকানা',
      'Opening Time': 'খোলার সময় (যেমন সকাল ০৯:০০)',
      'Closing Time': 'বন্ধ করার সময় (যেমন রাত ১০:০০)',
      'Tax ID': 'ট্যাক্স আইডি',
      'Save Changes': 'পরিবর্তন সংরক্ষণ করুন',
      'Profile updated successfully': 'প্রোফাইল সফলভাবে আপডেট হয়েছে',
      'Error updating profile:': 'প্রোফাইল আপডেট করতে ত্রুটি:',
    }
  };

  String _t(String key) {
    return _localizedStrings[widget.currentLanguage]?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.initialData['full_name']?.toString() ?? '');
    _phoneController = TextEditingController(text: widget.initialData['phone_number']?.toString() ?? '');
    _emailController = TextEditingController(text: widget.initialData['email']?.toString() ?? '');
    _businessNameController = TextEditingController(text: widget.initialData['business_name']?.toString() ?? '');
    _categoryController = TextEditingController(text: widget.initialData['category']?.toString() ?? '');
    _addressController = TextEditingController(text: widget.initialData['address']?.toString() ?? '');
    _openingTimeController = TextEditingController(text: widget.initialData['opening_time']?.toString() ?? '');
    _closingTimeController = TextEditingController(text: widget.initialData['closing_time']?.toString() ?? '');
    _taxIdController = TextEditingController(text: widget.initialData['tax_id']?.toString() ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final updates = {
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'category': _categoryController.text.trim(),
        'address': _addressController.text.trim(),
        'opening_time': _openingTimeController.text.trim(),
        'closing_time': _closingTimeController.text.trim(),
        'tax_id': _taxIdController.text.trim(),
      };

      await SupabaseConfig.client
          .from(SupabaseConfig.tableUsers)
          .update(updates)
          .eq('id', widget.initialData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Profile updated successfully')), backgroundColor: AppColors.delivered),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('Error updating profile:')} $e'), backgroundColor: AppColors.cancelled),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryTeal),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_t('Edit Profile'), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('Personal Details'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    _buildTextField(_t('Full Name'), _fullNameController),
                    _buildTextField(_t('Phone Number'), _phoneController, keyboardType: TextInputType.phone),
                    _buildTextField(_t('Email'), _emailController, keyboardType: TextInputType.emailAddress),
                    
                    const SizedBox(height: 24),
                    Text(_t('Shop Details'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    _buildTextField(_t('Business Name'), _businessNameController),
                    _buildTextField(_t('Category'), _categoryController),
                    _buildTextField(_t('Address'), _addressController),
                    
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_t('Opening Time'), _openingTimeController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_t('Closing Time'), _closingTimeController)),
                      ],
                    ),
                    _buildTextField(_t('Tax ID'), _taxIdController),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_t('Save Changes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
