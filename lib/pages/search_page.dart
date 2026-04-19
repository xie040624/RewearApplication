import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'product_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All'},
    {'key': 'shirt', 'label': 'Shirts'},
    {'key': 'pants', 'label': 'Pants'},
    {'key': 'hat', 'label': 'Hats'},
    {'key': 'shoes', 'label': 'Shoes'},
    {'key': 'accessory', 'label': 'Accessories'},
  ];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String keyword) async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.searchProducts(
        keyword,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );
      if (mounted)
        setState(() {
          _results = data;
          _hasSearched = true;
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _search,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          decoration: InputDecoration(
            hintText: 'Search items...',
            hintStyle: const TextStyle(
              color: Color(0xFFBBBBBB),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 17,
                      color: Color(0xFFAAAAAA),
                    ),
                    onPressed: () {
                      _ctrl.clear();
                      _search('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Category filter ──────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat['key'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat['key']!);
                      _search(_ctrl.text);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.black
                              : const Color(0xFFE8E8E8),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF555555),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Count
          if (_hasSearched && !_loading)
            Container(
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${_results.length} items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A9A9A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ── Grid ─────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 1.5,
                    ),
                  )
                : _results.isEmpty && _hasSearched
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
                            Icons.search_off_rounded,
                            size: 28,
                            color: Color(0xFFBBBBBB),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nothing found',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.65,
                        ),
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      final imageUrl = p['image_url'] as String?;
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(product: p),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child:
                                        imageUrl != null && imageUrl.isNotEmpty
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
                                        p['size'] ?? '',
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
                            const SizedBox(height: 8),
                            Text(
                              p['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p['price']} ฿',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              p['seller_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFAAAAAA),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ph() => Container(
    color: const Color(0xFFF0F0F0),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 40, color: Color(0xFFCCCCCC)),
    ),
  );
}
