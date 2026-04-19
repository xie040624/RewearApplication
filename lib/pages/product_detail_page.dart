import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'checkout_page.dart';
import 'login_page.dart';
import 'user_profile_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailPage({super.key, required this.product});
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Map<String, dynamic> _product;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _fetchLiveStatus();
  }

  // ดึงสถานะล่าสุดจาก Supabase ทุกครั้งที่เปิดหน้า
  Future<void> _fetchLiveStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final productId = _product['id']?.toString();
      if (productId == null) return;

      final res = await supabase
          .from('products')
          .select(
            'id, status, name, price, size, condition, category, description, image_url, seller_id, seller_name',
          )
          .eq('id', productId)
          .maybeSingle();

      if (mounted && res != null) {
        setState(() => _product = {..._product, ...res});
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
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
    final imageUrl = _product['image_url'] as String?;
    final isSold = _product['status'] == 'Sold';
    final sellerId = _product['seller_id'] as String?;
    final sellerName = _product['seller_name'] as String? ?? 'Unknown';
    final isOwnProduct = sellerId == SupabaseService.currentUserId;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Image ─────────────────────────────────────
          Stack(
            children: [
              SizedBox(
                height: 360,
                width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPh(),
                      )
                    : _imgPh(),
              ),

              // Sold overlay
              if (isSold)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This item is no longer available',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // Loading spinner (กำลังตรวจสอบสถานะ)
              if (_loadingStatus && !isSold)
                Positioned(
                  top: 60,
                  right: 16,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),

              // Gradient bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.white, Colors.white.withOpacity(0)],
                    ),
                  ),
                ),
              ),

              // Back + category buttons
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded, size: 17),
                        ),
                      ),
                      if (_product['category'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _catLabel(_product['category']),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Details ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _product['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_product['price']} ฿',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: isSold
                              ? const Color(0xFFAAAAAA)
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tags row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _tag(_product['size'] ?? '-'),
                      if ((_product['condition'] ?? '').isNotEmpty)
                        _tag(_product['condition']),
                      if (isSold)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SOLD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Seller card ─────────────────────────
                  GestureDetector(
                    onTap: sellerId == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfilePage(
                                  userId: sellerId,
                                  sellerName: sellerName,
                                ),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                sellerName.isNotEmpty
                                    ? sellerName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sellerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Text(
                                  'View profile →',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9A9A9A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFFBBBBBB),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_product['description'] as String?)?.isNotEmpty == true
                        ? _product['description']
                        : 'No description provided.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Buy button ────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: _buildBottomButton(context, isSold, isOwnProduct),
        ),
      ),
    );
  }

  Widget _buildBottomButton(
    BuildContext context,
    bool isSold,
    bool isOwnProduct,
  ) {
    // กำลังโหลดสถานะ
    if (_loadingStatus) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // สินค้าขายแล้ว
    if (isSold) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.do_not_disturb_outlined,
              size: 16,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(
              'This item has been sold',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    // สินค้าของตัวเอง
    if (isOwnProduct) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 16,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(
              'This is your listing',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    // ปุ่มซื้อปกติ
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (!SupabaseService.isLoggedIn) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CheckoutPage(product: _product)),
          ).then((_) => _fetchLiveStatus()); // refresh สถานะหลังกลับมา
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Buy Now',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _imgPh() => Container(
    color: const Color(0xFFF0F0F0),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 80, color: Color(0xFFCCCCCC)),
    ),
  );

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF555555),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
