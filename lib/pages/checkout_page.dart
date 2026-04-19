// ═══════════════════════════════════════════════════
// checkout_page.dart
// ═══════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'thank_you_page.dart';

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic> product;
  const CheckoutPage({super.key, required this.product});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.currentUser;
    _nameCtrl.text = user?.userMetadata?['full_name'] ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _addressCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseService.buyProduct(
        product: widget.product,
        buyerName: _nameCtrl.text.trim(),
        buyerAddress: _addressCtrl.text.trim(),
        buyerPhone: _phoneCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ThankYouPage()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        prefixIcon: Icon(icon, size: 17, color: const Color(0xFFAAAAAA)),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 1.2)),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final imageUrl = p['image_url'] as String?;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Summary',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.1)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 68, height: 68,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _thumb())
                          : _thumb(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2)),
                        const SizedBox(height: 3),
                        Text('Size: ${p['size'] ?? '-'}  ·  ${p['seller_name'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A))),
                      ],
                    ),
                  ),
                  Text('${p['price']} ฿',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),

            const SizedBox(height: 28),
            const Text('Shipping Details',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.1)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: _dec('Full Name', 'e.g. John Doe', Icons.person_outline_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: _dec('Phone', 'e.g. 0812345678', Icons.phone_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: _dec('Shipping Address',
                  'House, Street, District, Province, Postal Code',
                  Icons.location_on_outlined),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Order',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb() => Container(
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFFCCCCCC)),
        ),
      );
}