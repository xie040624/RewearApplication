import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});
  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sizeCtrl  = TextEditingController(); // for free-text size (accessory)

  String? _selectedSize;
  String? _selectedCategory;
  bool _loading = false;
  File? _pickedImage;

  // Clothing sizes shown as chips
  final List<String> _clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'Free Size'];
  // Shoe sizes
  final List<String> _shoeSizes = ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45'];
  // Hat sizes
  final List<String> _hatSizes = ['S/M', 'L/XL', 'Free Size'];

  final List<Map<String, dynamic>> _categories = [
    {'key': 'shirt',     'label': 'Shirt',      'icon': Icons.checkroom_outlined},
    {'key': 'pants',     'label': 'Pants',      'icon': Icons.straighten_outlined},
    {'key': 'hat',       'label': 'Hat',        'icon': Icons.face_outlined},
    {'key': 'shoes',     'label': 'Shoes',      'icon': Icons.directions_walk_outlined},
    {'key': 'accessory', 'label': 'Accessory',  'icon': Icons.watch_outlined},
  ];

  bool get _isAccessory => _selectedCategory == 'accessory';
  bool get _isShoes    => _selectedCategory == 'shoes';
  bool get _isHat      => _selectedCategory == 'hat';
  bool get _isClothing => _selectedCategory == 'shirt' || _selectedCategory == 'pants';

  List<String> get _availableSizes {
    if (_isShoes) return _shoeSizes;
    if (_isHat)   return _hatSizes;
    return _clothingSizes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String? cat) {
    setState(() {
      _selectedCategory = cat;
      _selectedSize = null;
      _sizeCtrl.clear();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _imageSourceSheet(),
    );
    if (source == null) return;
    final xfile = await picker.pickImage(source: source, imageQuality: 80);
    if (xfile == null) return;
    setState(() => _pickedImage = File(xfile.path));
  }

  Widget _imageSourceSheet() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_outlined, size: 18)),
            title: const Text('Take a photo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined, size: 18)),
            title: const Text('Choose from gallery',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<String?> _uploadImage(File file) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;
    final fileName = 'products/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('images').upload(
        fileName, file, fileOptions: const FileOptions(upsert: true));
    return supabase.storage.from('images').getPublicUrl(fileName);
  }

  Future<void> _publish() async {
    if (_nameCtrl.text.trim().isEmpty) { _err('Please enter a product name'); return; }
    if (_selectedCategory == null)     { _err('Please select a category'); return; }

    // Validate size based on category
    final sizeValue = _isAccessory
        ? _sizeCtrl.text.trim()
        : _selectedSize;
    if (!_isAccessory && sizeValue == null) { _err('Please select a size'); return; }

    if (_priceCtrl.text.trim().isEmpty ||
        int.tryParse(_priceCtrl.text.trim()) == null) {
      _err('Please enter a valid price'); return;
    }

    setState(() => _loading = true);
    try {
      String? imageUrl;
      if (_pickedImage != null) imageUrl = await _uploadImage(_pickedImage!);

      await SupabaseService.addProduct({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': int.parse(_priceCtrl.text.trim()),
        'size': sizeValue?.isEmpty == true ? 'One Size' : (sizeValue ?? 'One Size'),
        'category': _selectedCategory,
        'condition': '90% New',
        'status': 'Active',
        if (imageUrl != null) 'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product published ✓'), backgroundColor: Colors.black),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _err('Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  InputDecoration _dec(String label, String hint, {int? maxLen}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black, width: 1.2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    counterText: '',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Listing',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.4)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _loading ? null : _publish,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _loading
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Publish',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ──────────────────────────────────────
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: _pickedImage != null
                    ? Stack(fit: StackFit.expand, children: [
                        Image.file(_pickedImage!, fit: BoxFit.cover),
                        Positioned(
                          bottom: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Change photo',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                                blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.add_photo_alternate_outlined, size: 22, color: Colors.black)),
                        const SizedBox(height: 10),
                        const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Tap to upload from camera or gallery',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A))),
                      ]),
              ),
            ),

            const SizedBox(height: 28),

            // ── Category ───────────────────────────────────
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return GestureDetector(
                  onTap: () => _onCategoryChanged(cat['key']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat['icon'] as IconData, size: 14,
                            color: isSelected ? Colors.white : const Color(0xFF666666)),
                        const SizedBox(width: 6),
                        Text(cat['label'],
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF555555),
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Name ──────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Product Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${_nameCtrl.text.length}/120',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A))),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: _dec('Product Name', 'e.g. Navy Blue Polo Shirt'),
            ),

            const SizedBox(height: 20),

            // ── Description ───────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${_descCtrl.text.length}/400',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A))),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLength: 400,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: _dec('Description', 'Condition, brand, how often worn...'),
            ),

            const SizedBox(height: 20),

            // ── Size (dynamic based on category) ──────────
            if (_selectedCategory != null) ...[
              const Text('Size', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),

              if (_isAccessory) ...[
                // Free text for accessories (dimensions, weight, etc.)
                TextField(
                  controller: _sizeCtrl,
                  decoration: _dec('Size / Dimensions',
                      'e.g. 20cm × 10cm, 38mm, Adjustable...'),
                ),
                const SizedBox(height: 4),
                const Text('Enter dimensions, diameter, or any relevant size info',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A))),
              ] else ...[
                // Chip selector for clothing / shoes / hat
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSizes.map((s) {
                    final isSelected = _selectedSize == s;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSize = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _isShoes ? 52 : 54,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF555555),
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
            ] else ...[
              // Placeholder before category selected
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF9A9A9A)),
                  SizedBox(width: 8),
                  Text('Select a category to choose size',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A))),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Price ────────────────────────────────────
            const Text('Price (THB)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Price', 'e.g. 299'),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}