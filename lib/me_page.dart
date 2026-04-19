import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'my_purchases_page.dart';
import 'my_shop_page.dart';
import 'eco_page.dart';
import 'seller_sales_page.dart';
import 'product_detail_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _myProducts = [];
  List<Map<String, dynamic>> _myPurchases = [];
  List<Map<String, dynamic>> _mySales = [];
  int _buyCount = 0;
  bool _loading = true;
  bool _uploadingAvatar = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getBuyCount(),
        SupabaseService.getMyProducts(),
        SupabaseService.getMyPurchases(),
        SupabaseService.getMySales(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _buyCount = results[1] as int;
          _myProducts = results[2] as List<Map<String, dynamic>>;
          _myPurchases = results[3] as List<Map<String, dynamic>>;
          _mySales = results[4] as List<Map<String, dynamic>>;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _ecoLevel(int count) {
    if (count >= 21) return 'Planet Saver';
    if (count >= 11) return 'Green Hero';
    if (count >= 6) return 'Eco Lover';
    if (count >= 3) return 'Starter';
    return 'Beginner';
  }

  List<Map<String, dynamic>> get _activeProducts =>
      _myProducts.where((p) => p['status'] == 'Active').toList();

  List<Map<String, dynamic>> get _soldProducts =>
      _myProducts.where((p) => p['status'] == 'Sold').toList();

  int get _soldRevenue => _mySales
      .where((s) => s['status'] == 'Completed')
      .fold<int>(0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0));

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text(
                'Take a photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;
    final xfile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (xfile == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final file = File(xfile.path);
      final url = await SupabaseService.uploadAvatar(file);
      await SupabaseService.updateAvatarUrl(url);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo updated ✓'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign out?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'You will be redirected to the login screen.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
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
              'Sign out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final name =
        _profile?['display_name'] ??
        user?.userMetadata?['full_name'] ??
        user?.email?.split('@').first ??
        'User';
    final email = _profile?['email'] ?? user?.email ?? '';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 1.5,
                ),
              )
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ── Profile Header ──────────────────
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  GestureDetector(
                                    onTap: _uploadingAvatar
                                        ? null
                                        : _changeAvatar,
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey.shade100,
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: _uploadingAvatar
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.black,
                                                        strokeWidth: 1.5,
                                                      ),
                                                )
                                              : avatarUrl != null &&
                                                    avatarUrl.isNotEmpty
                                              ? Image.network(
                                                  avatarUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _initials(initial),
                                                )
                                              : _initials(initial),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9A9A9A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: Text(
                                            _ecoLevel(_buyCount),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ── Stats row ───────────────────
                              Row(
                                children: [
                                  _profileStat(
                                    '${_myProducts.length}',
                                    'Listings',
                                  ),
                                  _vDivider(),
                                  _profileStat(
                                    '${_soldProducts.length}',
                                    'Sold',
                                  ),
                                  _vDivider(),
                                  _profileStat('$_buyCount', 'Purchased'),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── Revenue summary ──────────────
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.payments_outlined,
                                      size: 18,
                                      color: Color(0xFF555555),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Revenue: $_soldRevenue THB',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'from ${_mySales.where((s) => s['status'] == 'Completed').length} sales',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9A9A9A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ── Quick action buttons ─────────
                              Row(
                                children: [
                                  _quickBtn(
                                    Icons.shopping_bag_outlined,
                                    'Purchases',
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MyPurchasesPage(),
                                      ),
                                    ).then((_) => _loadData()),
                                  ),
                                  const SizedBox(width: 10),
                                  _quickBtn(
                                    Icons.storefront_outlined,
                                    'My Shop',
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MyShopPage(),
                                      ),
                                    ).then((_) => _loadData()),
                                  ),
                                  const SizedBox(width: 10),
                                  _quickBtn(
                                    Icons.receipt_long_outlined,
                                    'My Sales',
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SellerSalesPage(),
                                      ),
                                    ).then((_) => _loadData()),
                                  ),
                                  const SizedBox(width: 10),
                                  _quickBtn(
                                    Icons.eco_outlined,
                                    'Eco',
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EcoPage(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // ── Sign out ─────────────────────
                              GestureDetector(
                                onTap: _logout,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEEEE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.logout,
                                        size: 16,
                                        color: Color(0xFFDC2626),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Sign Out',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Tab bar ─────────────────────────
                        Container(
                          color: Colors.white,
                          child: TabBar(
                            controller: _tabController,
                            labelColor: Colors.black,
                            unselectedLabelColor: const Color(0xFFAAAAAA),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            unselectedLabelStyle: const TextStyle(fontSize: 12),
                            indicatorColor: Colors.black,
                            indicatorWeight: 2,
                            dividerColor: const Color(0xFFF0F0F0),
                            tabs: [
                              Tab(text: 'Listings (${_myProducts.length})'),
                              Tab(text: 'Purchases (${_myPurchases.length})'),
                              Tab(text: 'Sales (${_mySales.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Tab 1: My Listings ──────────────────
                    _ListingsTab(
                      activeProducts: _activeProducts,
                      soldProducts: _soldProducts,
                    ),
                    // ── Tab 2: My Purchases ─────────────────
                    _PurchasesTab(purchases: _myPurchases),
                    // ── Tab 3: My Sales ─────────────────────
                    _SalesTab(sales: _mySales),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _initials(String letter) => Center(
    child: Text(
      letter,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
    ),
  );

  Widget _profileStat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9A9A9A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _vDivider() =>
      Container(height: 32, width: 1, color: const Color(0xFFF0F0F0));

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: Colors.black),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Listings (Active + Sold)
// ─────────────────────────────────────────────────────────────────────────────
class _ListingsTab extends StatefulWidget {
  final List<Map<String, dynamic>> activeProducts;
  final List<Map<String, dynamic>> soldProducts;
  const _ListingsTab({
    required this.activeProducts,
    required this.soldProducts,
  });
  @override
  State<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends State<_ListingsTab> {
  bool _showActive = true;

  @override
  Widget build(BuildContext context) {
    final products = _showActive ? widget.activeProducts : widget.soldProducts;

    return Column(
      children: [
        // Sub-filter
        Container(
          color: const Color(0xFFFAFAFA),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              _subChip('Active (${widget.activeProducts.length})', true),
              const SizedBox(width: 8),
              _subChip('Sold (${widget.soldProducts.length})', false),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? _empty(
                  _showActive ? Icons.storefront_outlined : Icons.sell_outlined,
                  _showActive ? 'No active listings' : 'No sold items yet',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(product: p),
                        ),
                      ),
                      child: _ProductCard(
                        product: p,
                        showSoldBadge: !_showActive,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _subChip(String label, bool isActive) {
    final sel = _showActive == isActive;
    return GestureDetector(
      onTap: () => setState(() => _showActive = isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.black : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sel ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String label) => Center(
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
          child: Icon(icon, size: 28, color: const Color(0xFFBBBBBB)),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Purchases
// ─────────────────────────────────────────────────────────────────────────────
class _PurchasesTab extends StatelessWidget {
  final List<Map<String, dynamic>> purchases;
  const _PurchasesTab({required this.purchases});

  Color _statusColor(String s) {
    switch (s) {
      case 'On Delivery':
        return const Color(0xFF2563EB);
      case 'Cancelled':
        return const Color(0xFFDC2626);
      case 'Completed':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF9A9A9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (purchases.isEmpty) {
      return Center(
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
                Icons.shopping_bag_outlined,
                size: 28,
                color: Color(0xFFBBBBBB),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No purchases yet',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPurchasesPage()),
              ),
              child: const Text(
                'View full purchase history →',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: purchases.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        // Last item = "View all" button
        if (i == purchases.length) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyPurchasesPage()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'View All Purchases →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
          );
        }
        final o = purchases[i];
        final status = o['status'] as String? ?? 'On Delivery';
        final statusColor = _statusColor(status);
        final imageUrl = o['product_image_url'] as String?;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumb(),
                        )
                      : _thumb(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o['product_name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${o['price']} THB  ·  Size: ${o['size'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                    Text(
                      o['seller_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _thumb() => Container(
    color: const Color(0xFFF0F0F0),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 22, color: Color(0xFFCCCCCC)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Sales
// ─────────────────────────────────────────────────────────────────────────────
class _SalesTab extends StatelessWidget {
  final List<Map<String, dynamic>> sales;
  const _SalesTab({required this.sales});

  Color _statusColor(String s) {
    switch (s) {
      case 'On Delivery':
        return const Color(0xFF2563EB);
      case 'Cancelled':
        return const Color(0xFFDC2626);
      case 'Completed':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF9A9A9A);
    }
  }

  int get _revenue => sales
      .where((s) => s['status'] == 'Completed')
      .fold<int>(0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Center(
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
                Icons.receipt_long_outlined,
                size: 28,
                color: Color(0xFFBBBBBB),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No sales yet',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerSalesPage()),
              ),
              child: const Text(
                'View full sales history →',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length + 2, // +1 revenue card, +1 view all
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        // Revenue summary card
        if (i == 0) {
          final completedCount = sales
              .where((s) => s['status'] == 'Completed')
              .length;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Revenue',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_revenue THB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$completedCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'items sold',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // View all button
        if (i == sales.length + 1) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellerSalesPage()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'View All Sales →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
          );
        }

        final o = sales[i - 1]; // offset by revenue card
        final status = o['status'] as String? ?? 'On Delivery';
        final statusColor = _statusColor(status);
        final isCompleted = status == 'Completed';
        final imageUrl = o['product_image_url'] as String?;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumb(),
                        )
                      : _thumb(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o['product_name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCompleted
                          ? '${o['price']} THB earned'
                          : '${o['price']} THB',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? const Color(0xFF16A34A)
                            : Colors.black,
                      ),
                    ),
                    Text(
                      'Buyer: ${o['buyer_name'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _thumb() => Container(
    color: const Color(0xFFF0F0F0),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 22, color: Color(0xFFCCCCCC)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card widget
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool showSoldBadge;
  const _ProductCard({required this.product, this.showSoldBadge = false});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['image_url'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => _ph(),
                      )
                    : _ph(),
              ),
              // Size badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    product['size'] ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Sold overlay
              if (showSoldBadge)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      child: const Center(
                        child: Text(
                          'SOLD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(
          product['name'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          '${product['price']} ฿',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: -0.3,
            color: showSoldBadge ? const Color(0xFF9A9A9A) : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _ph() => Container(
    color: const Color(0xFFF0F0F0),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 36, color: Color(0xFFCCCCCC)),
    ),
  );
}
