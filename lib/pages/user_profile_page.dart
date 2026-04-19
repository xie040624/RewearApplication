import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'product_detail_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String? sellerName;
  const UserProfilePage({super.key, required this.userId, this.sellerName});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _products = [];
  int _buyCount = 0;
  int _sellCount = 0;
  bool _loading = true;

  String _ecoLevel(int count) {
    if (count >= 21) return 'Planet Saver';
    if (count >= 11) return 'Green Hero';
    if (count >= 6) return 'Eco Lover';
    if (count >= 3) return 'Starter';
    return 'Beginner';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getProfileById(widget.userId),
        SupabaseService.getProductsBySeller(widget.userId),
        SupabaseService.getBuyCountByUser(widget.userId),
        SupabaseService.getSellCountByUser(widget.userId),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _products = results[1] as List<Map<String, dynamic>>;
          _buyCount = results[2] as int;
          _sellCount = results[3] as int;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['display_name'] ?? widget.sellerName ?? 'User';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final bio = _profile?['bio'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final ecoLevel = _ecoLevel(_buyCount);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 1.5,
              ),
            )
          : CustomScrollView(
              slivers: [
                // ── App bar with avatar ──────────────────
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.4,
                      color: Colors.black,
                    ),
                  ),
                  expandedHeight: 260,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF0F0F0),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _initials(initial),
                                  )
                                : _initials(initial),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Eco level badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ecoLevel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (bio != null && bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                bio,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888888),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Stats ────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Divider(color: Color(0xFFF0F0F0), height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statCol('${_products.length}', 'Listings'),
                              _vDivider(),
                              _statCol('$_sellCount', 'Sold'),
                              _vDivider(),
                              _statCol('$_buyCount', 'Purchased'),
                            ],
                          ),
                        ),
                        const Divider(color: Color(0xFFF0F0F0), height: 1),
                      ],
                    ),
                  ),
                ),

                // ── Section header ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: [
                        const Text(
                          'Listings',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${_products.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Product grid ─────────────────────────
                _products.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 24,
                                    color: Color(0xFFBBBBBB),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No active listings',
                                  style: TextStyle(
                                    color: Color(0xFF999999),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final p = _products[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailPage(product: p),
                                ),
                              ),
                              child: _ProductCard(product: p),
                            );
                          }, childCount: _products.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.65,
                              ),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _initials(String letter) => Center(
    child: Text(
      letter,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    ),
  );

  Widget _statCol(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
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
  );

  Widget _vDivider() =>
      Container(height: 32, width: 1, color: const Color(0xFFF0F0F0));
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

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
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: -0.3,
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
