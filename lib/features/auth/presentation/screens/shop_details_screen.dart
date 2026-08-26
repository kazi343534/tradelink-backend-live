import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/profile_localization.dart';

class ShopDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const ShopDetailsScreen({super.key, required this.initialData});

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _loc = ProfileLocalization();
  bool _isSubmitting = false;

  late final TextEditingController _businessNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _openingTimeController;
  late final TextEditingController _closingTimeController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _descriptionController;

  String _selectedCategory = 'Grocery';
  static const List<String> _categories = ['Grocery', 'Pharmacy', 'Hardware', 'Electronics', 'Clothing'];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _businessNameController = TextEditingController(text: data['business_name'] ?? '');
    _addressController = TextEditingController(text: data['address'] ?? '');
    _openingTimeController = TextEditingController(text: data['opening_time'] ?? '');
    _closingTimeController = TextEditingController(text: data['closing_time'] ?? '');
    _taxIdController = TextEditingController(text: data['tax_id'] ?? '');
    _descriptionController = TextEditingController(text: data['description'] ?? '');

    if (_categories.contains(data['category'])) {
      _selectedCategory = data['category'];
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _taxIdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) throw Exception("User ID not found");

      final updates = {
        'business_name': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'category': _selectedCategory,
        'opening_time': _openingTimeController.text.trim().isEmpty ? null : _openingTimeController.text.trim(),
        'closing_time': _closingTimeController.text.trim().isEmpty ? null : _closingTimeController.text.trim(),
        'tax_id': _taxIdController.text.trim(),
        'description': _descriptionController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseConfig.client.from(SupabaseConfig.tableUsers).update(updates).eq('id', userId);

      await prefs.setString('user_business', _businessNameController.text.trim());
      await prefs.setString('user_address', _addressController.text.trim());
      await prefs.setString('user_category', _selectedCategory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loc.translate('success_update')), backgroundColor: AppColors.primaryTeal),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_loc.translate('failed_update')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _loc,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _loc.translate('shop_details'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFFE2E8F0), height: 1),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(label: _loc.translate('business_name'), controller: _businessNameController),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: _loc.translate('category'),
                  value: _selectedCategory,
                  options: _categories,
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                _buildTextField(label: _loc.translate('address'), controller: _addressController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(label: _loc.translate('opening_time'), hintText: _loc.translate('e_g_09_00'), controller: _openingTimeController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(label: _loc.translate('closing_time'), hintText: _loc.translate('e_g_21_00'), controller: _closingTimeController)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(label: _loc.translate('tax_id'), controller: _taxIdController),
                const SizedBox(height: 16),
                _buildTextField(label: _loc.translate('description'), controller: _descriptionController, maxLines: 3),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomActionBar(context),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    String? hintText,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
              items: options.map((option) => DropdownMenuItem<String>(value: option, child: Text(option))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text(_loc.translate('save_changes'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
