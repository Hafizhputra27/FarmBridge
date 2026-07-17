import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../core/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ListingFormState {
  bool isLoading;
  bool isUploadingImage;
  String? fotoUrl;
  bool fotoError;
  final titleController = TextEditingController();
  bool titleError;
  final priceController = TextEditingController();
  bool priceError;
  String? category;
  bool categoryError;
  String? region;
  bool regionError;
  String unit;
  int quantity;

  ListingFormState({
    this.isLoading = false,
    this.isUploadingImage = false,
    this.fotoUrl,
    this.fotoError = false,
    String? title,
    this.titleError = false,
    String? price,
    this.priceError = false,
    this.category,
    this.categoryError = false,
    this.region,
    this.regionError = false,
    this.unit = 'kg',
    this.quantity = 1,
  }) {
    titleController.text = title ?? '';
    priceController.text = price ?? '';
  }

  bool get isValid =>
      fotoUrl != null &&
      titleController.text.trim().isNotEmpty &&
      (double.tryParse(priceController.text) ?? 0) > 0 &&
      category != null &&
      quantity >= 1;
}

class ListingForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? listing;
  final String buttonLabel;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const ListingForm({
    super.key,
    this.listing,
    required this.buttonLabel,
    required this.onSubmit,
  });

  bool get isEditing => listing != null;

  @override
  ConsumerState<ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends ConsumerState<ListingForm> {
  final _picker = ImagePicker();
  final _unitOptions = ['kg', 'head', 'flat', 'box', 'ikat'];
  // Taksonomi kategori konsisten dengan feed & search (Cabai/Sayuran/Umbi).
  final _categories = ['Cabai', 'Sayuran', 'Umbi'];
  final _regions = ['Jawa Barat', 'Jawa Tengah', 'Jawa Timur'];

  late ListingFormState _s;

  @override
  void initState() {
    super.initState();
    final d = widget.listing;
    _s = ListingFormState(
      fotoUrl: d?['foto_url']?.toString(),
      title: d?['title']?.toString(),
      price: d?['harga_per_unit']?.toString(),
      category: d?['category']?.toString(),
      region: d?['region']?.toString(),
      unit: d?['unit']?.toString() ?? 'kg',
      quantity: (d?['quantity_available'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  void dispose() {
    _s.titleController.dispose();
    _s.priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1200);
    if (file == null) return;

    setState(() => _s.isUploadingImage = true);

    try {
      final userId = ref.read(authProvider).userId!;
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = file.path;
      await Supabase.instance.client.storage
          .from('listing-photos')
          .upload(path, File(filePath));

      final url = Supabase.instance.client.storage
          .from('listing-photos')
          .getPublicUrl(path);

      setState(() {
        _s.fotoUrl = url;
        _s.fotoError = false;
        _s.isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _s.isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _validateAndSubmit() async {
    setState(() {
      _s.fotoError = _s.fotoUrl == null;
      _s.titleError = _s.titleController.text.trim().isEmpty;
      _s.priceError = (double.tryParse(_s.priceController.text) ?? 0) <= 0;
      _s.categoryError = _s.category == null;
    });

    if (!_s.isValid) return;

    setState(() => _s.isLoading = true);

    try {
      final data = {
        'title': _s.titleController.text.trim(),
        'category': _s.category,
        'region': _s.region ?? 'Jawa Barat',
        'harga_per_unit': double.parse(_s.priceController.text),
        'unit': _s.unit,
        'quantity_available': _s.quantity,
        'foto_url': _s.fotoUrl,
        'status': 'active',
        'farmer_id': ref.read(authProvider).userId,
      };
      await widget.onSubmit(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _s.isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _s.titleController,
                label: 'Listing Title',
                hint: 'Heirloom Tomato Crate',
                error: _s.titleError ? 'Judul tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                value: _s.category,
                label: 'Category',
                items: _categories,
                error: _s.categoryError ? 'Pilih kategori' : null,
                onChanged: (v) => setState(() {
                  _s.category = v;
                  _s.categoryError = false;
                }),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                value: _s.region,
                label: 'Region',
                items: _regions,
                onChanged: (v) => setState(() {
                  _s.region = v;
                  _s.regionError = false;
                }),
              ),
              const SizedBox(height: 16),
              _buildPriceSection(),
              const SizedBox(height: 16),
              _buildStepper(),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildStickyButton(),
        ),
      ],
    );
  }

  Widget _buildStickyButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed:
                (_s.isValid && !_s.isLoading && !_s.isUploadingImage)
                    ? _validateAndSubmit
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _s.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.buttonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_s.fotoUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _s.fotoUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          ),
        if (_s.isUploadingImage)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _photoButton(
                Icons.camera_alt,
                'Take Photo',
                () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _photoButton(
                Icons.photo_library,
                'Choose from Gallery',
                () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (_s.fotoError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Minimal 1 foto wajib diunggah',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _photoButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _s.isUploadingImage ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? error,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error != null ? Colors.red : AppTheme.brandGreen, width: 2),
        ),
        errorText: error,
      ),
      onChanged: (_) {
        if (_s.titleError || _s.priceError) {
          setState(() {
            _s.titleError = false;
            _s.priceError = false;
          });
        }
      },
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    String? error,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error != null ? Colors.red : AppTheme.brandGreen, width: 2),
        ),
        errorText: error,
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _s.priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Price per Unit',
              prefixText: 'Rp ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _s.priceError ? Colors.red : Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _s.priceError ? Colors.red : AppTheme.brandGreen, width: 2),
              ),
              errorText: _s.priceError ? 'Harga harus > 0' : null,
            ),
            onChanged: (_) {
              if (_s.priceError) setState(() => _s.priceError = false);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: _s.unit,
            decoration: InputDecoration(
              labelText: 'Unit',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _unitOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _s.unit = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _s.quantity > 1 ? () => setState(() => _s.quantity--) : null,
          icon: const Icon(Icons.remove_circle_outline, size: 32),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '${_s.quantity}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _s.quantity++),
          icon: const Icon(Icons.add_circle_outline, size: 32),
        ),
      ],
    );
  }

}
