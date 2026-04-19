import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SellerSalesPage extends StatefulWidget {
  const SellerSalesPage({super.key});
  @override
  State<SellerSalesPage> createState() => _SellerSalesPageState();
}

class _SellerSalesPageState extends State<SellerSalesPage> {
  List<Map<String, dynamic>> _sales = [];
  bool _loading = true;
  String? _processingId;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMySales();
      if (mounted) setState(() => _sales = data);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'pending':
        return _sales.where((s) => s['status'] == 'On Delivery').toList();
      case 'completed':
        return _sales.where((s) => s['status'] == 'Completed').toList();
      case 'cancelled':
        return _sales.where((s) => s['status'] == 'Cancelled').toList();
      default:
        return _sales;
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    final productId = order['product_id']?.toString();

    if (orderId == null || productId == null) {
      _showSnack('Cannot cancel: missing data', isError: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Order?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'The item will be re-listed as active.\nThis cannot be undone.',
          style: TextStyle(fontSize: 13, color: Color(0xFF888888), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Order',
              style: TextStyle(
                color: Color(0xFF666666),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel Order',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _processingId = orderId);
    try {
      await SupabaseService.cancelOrder(orderId, productId);
      await _loadSales();
      if (mounted) _showSnack('Order cancelled — item re-listed');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.black,
      ),
    );
  }

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

  IconData _statusIcon(String s) {
    switch (s) {
      case 'On Delivery':
        return Icons.local_shipping_outlined;
      case 'Cancelled':
        return Icons.cancel_outlined;
      case 'Completed':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _sales.where((s) => s['status'] == 'On Delivery').length;
    final completed = _sales.where((s) => s['status'] == 'Completed').length;
    final cancelled = _sales.where((s) => s['status'] == 'Cancelled').length;

    // รายได้จาก Completed orders เท่านั้น
    final revenue = _sales
        .where((s) => s['status'] == 'Completed')
        .fold<int>(0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Sales',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 1.5,
              ),
            )
          : Column(
              children: [
                // ── Revenue card ─────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                              const SizedBox(height: 2),
                              Text(
                                '$revenue THB',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$completed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'items sold',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Stats ────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Row(
                    children: [
                      _statBox('${_sales.length}', 'Total', Colors.black),
                      const SizedBox(width: 10),
                      _statBox('$pending', 'Pending', const Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      _statBox('$completed', 'Done', const Color(0xFF16A34A)),
                    ],
                  ),
                ),

                // ── Filter chips ─────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('all', 'All (${_sales.length})'),
                        const SizedBox(width: 8),
                        _chip('pending', 'Pending ($pending)'),
                        const SizedBox(width: 8),
                        _chip('completed', 'Completed ($completed)'),
                        const SizedBox(width: 8),
                        _chip('cancelled', 'Cancelled ($cancelled)'),
                      ],
                    ),
                  ),
                ),

                const Divider(color: Color(0xFFF0F0F0), height: 1),

                Expanded(
                  child: _filtered.isEmpty
                      ? _empty(Icons.receipt_long_outlined, 'No sales here')
                      : RefreshIndicator(
                          onRefresh: _loadSales,
                          color: Colors.black,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _card(_filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final orderId = o['id']?.toString() ?? '';
    final status = o['status'] as String? ?? 'On Delivery';
    final sc = _statusColor(status);
    final isDelivery = status == 'On Delivery';
    final isCompleted = status == 'Completed';
    final isCancelled = status == 'Cancelled';
    final isReceived = o['buyer_received'] == true;
    final isProcessing = _processingId == orderId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order header: status badge ────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // วันที่สั่งซื้อ
              Text(
                _formatDate(o['created_at']),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(status), size: 11, color: sc),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: sc,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Product info ─────────────────────────────
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.hardEdge,
                child: (o['product_image_url'] as String?)?.isNotEmpty == true
                    ? Image.network(
                        o['product_image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.checkroom_outlined,
                          size: 24,
                          color: Color(0xFFCCCCCC),
                        ),
                      )
                    : const Icon(
                        Icons.checkroom_outlined,
                        size: 24,
                        color: Color(0xFFCCCCCC),
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
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Size: ${o['size'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${o['price']} THB',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Buyer info card ──────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อผู้ซื้อ
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: Color(0xFF9A9A9A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      o['buyer_name'] ?? 'Unknown Buyer',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // เบอร์โทร
                if ((o['buyer_phone'] as String?)?.isNotEmpty == true)
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Color(0xFF9A9A9A),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        o['buyer_phone'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                if ((o['buyer_phone'] as String?)?.isNotEmpty == true)
                  const SizedBox(height: 4),
                // ที่อยู่จัดส่ง
                if ((o['buyer_address'] as String?)?.isNotEmpty == true)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Color(0xFF9A9A9A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          o['buyer_address'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Status banners ───────────────────────────
          if (isCompleted) ...[
            const SizedBox(height: 10),
            _banner(
              Icons.check_circle_outline_rounded,
              const Color(0xFF16A34A),
              const Color(0xFFEAFAF0),
              isReceived
                  ? 'Buyer confirmed receipt — sale complete!'
                  : 'Sale completed',
            ),
          ],
          if (isCancelled) ...[
            const SizedBox(height: 10),
            _banner(
              Icons.cancel_outlined,
              const Color(0xFFDC2626),
              const Color(0xFFFFEEEE),
              'Order cancelled — item re-listed',
            ),
          ],

          // ── Cancel button (Pending only) ─────────────
          if (isDelivery) ...[
            const SizedBox(height: 12),
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOrder(o),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 15,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Cancel This Order',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _banner(IconData icon, Color color, Color bg, String text) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _chip(String key, String label) {
    final sel = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.black : const Color(0xFFF5F5F5),
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

  Widget _statBox(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

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
