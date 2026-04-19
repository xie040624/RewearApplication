import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'add_product_page.dart';
import 'login_page.dart';
import 'seller_sales_page.dart';

class MyShopPage extends StatefulWidget {
  const MyShopPage({super.key});
  @override
  State<MyShopPage> createState() => _MyShopPageState();
}

class _MyShopPageState extends State<MyShopPage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!SupabaseService.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMyProducts();
      if (mounted) setState(() => _products = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete item?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deleteProduct(id);
      _loadProducts();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    }
  }

  String _catLabel(String? cat) =>
      const {
        'shirt': 'Shirt',
        'pants': 'Pants',
        'hat': 'Hat',
        'shoes': 'Shoes',
        'accessory': 'Accessory',
      }[cat] ??
      cat ??
      '';

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 24,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign in to manage your shop',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 13,
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final active = _products.where((p) => p['status'] == 'Active').length;
    final sold = _products.where((p) => p['status'] == 'Sold').length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Shop',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: false,
        actions: [
          // Sales orders button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerSalesPage()),
              ).then((_) => _loadProducts()),
              icon: const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: Colors.black,
              ),
              label: const Text(
                'Orders',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Stats ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              children: [
                _statItem('${_products.length}', 'Total'),
                const SizedBox(width: 32),
                _statItem('$active', 'Active'),
                const SizedBox(width: 32),
                _statItem('$sold', 'Sold'),
              ],
            ),
          ),
          const SizedBox(height: 1),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 1.5,
                    ),
                  )
                : _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            size: 28,
                            color: Color(0xFFBBBBBB),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No listings yet',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _products[i];
                      final imageUrl = p['image_url'] as String?;
                      final isActive = p['status'] == 'Active';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _thumb(),
                                      )
                                    : _thumb(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${p['price']} THB  ·  ${p['size']}  ·  ${_catLabel(p['category'])}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9A9A9A),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.black
                                          : const Color(0xFFEEEEEE),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      p['status'] ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? Colors.white
                                            : const Color(0xFF888888),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: Color(0xFFCCCCCC),
                                ),
                                onPressed: () => _delete(p['id']),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── Add button ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductPage()),
                  );
                  if (added == true) _loadProducts();
                },
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'New Listing',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
      ),
    ],
  );

  Widget _thumb() => Container(
    color: const Color(0xFFF5F5F5),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFFCCCCCC)),
    ),
  );
}
