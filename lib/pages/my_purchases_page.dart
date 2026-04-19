import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class MyPurchasesPage extends StatefulWidget {
  const MyPurchasesPage({super.key});
  @override
  State<MyPurchasesPage> createState() => _MyPurchasesPageState();
}

class _MyPurchasesPageState extends State<MyPurchasesPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _processingId;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getMyPurchases();
      if (mounted) setState(() => _orders = data);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'active':
        return _orders.where((o) => o['status'] == 'On Delivery').toList();
      case 'completed':
        return _orders.where((o) => o['status'] == 'Completed').toList();
      case 'cancelled':
        return _orders.where((o) => o['status'] == 'Cancelled').toList();
      default:
        return _orders;
    }
  }

  // ── ยืนยันรับสินค้า ────────────────────────────────────────
  Future<void> _confirmReceived(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;

    final ok = await _dialog(
      title: 'Confirm Receipt?',
      message:
          'Please confirm that you have received this item.\nThis will complete the order.',
      confirmLabel: 'Confirm Received',
      confirmColor: Colors.black,
    );
    if (ok != true || !mounted) return;

    setState(() => _processingId = orderId);
    try {
      await SupabaseService.confirmReceived(orderId);
      await _loadOrders();
      if (mounted) _showSnack('✓ Order marked as received');
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── ยกเลิกออร์เดอร์ ────────────────────────────────────────
  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    final productId = order['product_id']?.toString();

    if (orderId == null || productId == null) {
      _showSnack('Cannot cancel: missing data', isError: true);
      return;
    }

    final ok = await _dialog(
      title: 'Cancel Order?',
      message:
          'Are you sure you want to cancel?\nThe item will be re-listed for sale.',
      confirmLabel: 'Yes, Cancel',
      confirmColor: Colors.red,
    );
    if (ok != true || !mounted) return;

    setState(() => _processingId = orderId);
    try {
      await SupabaseService.cancelOrder(orderId, productId);
      await _loadOrders();
      if (mounted) _showSnack('Order cancelled');
    } catch (e) {
      if (mounted) _showSnack('Failed to cancel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── แก้ไขที่อยู่จัดส่ง ─────────────────────────────────────
  Future<void> _editAddress(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;

    final addressCtrl = TextEditingController(
      text: order['buyer_address'] ?? '',
    );
    final phoneCtrl = TextEditingController(text: order['buyer_phone'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Shipping Info',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _inputDec('Phone', Icons.phone_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              maxLines: 3,
              decoration: _inputDec(
                'Shipping Address',
                Icons.location_on_outlined,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    try {
      await SupabaseService.updateShippingAddress(
        purchaseId: orderId,
        newAddress: addressCtrl.text.trim(),
        newPhone: phoneCtrl.text.trim(),
      );
      await _loadOrders();
      if (mounted) _showSnack('✓ Shipping info updated');
    } catch (e) {
      if (mounted) _showSnack('Failed to update: $e', isError: true);
    }
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 13),
    prefixIcon: Icon(icon, size: 17, color: const Color(0xFFAAAAAA)),
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.black, width: 1.2),
    ),
  );

  Future<bool?> _dialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: -0.3,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF888888),
          height: 1.55,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Not Now',
            style: TextStyle(
              color: Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: confirmColor, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

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

  @override
  Widget build(BuildContext context) {
    final active = _orders.where((o) => o['status'] == 'On Delivery').length;
    final completed = _orders.where((o) => o['status'] == 'Completed').length;

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
          'My Purchases',
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
            onPressed: _loadOrders,
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
                // ── Stats ──────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Row(
                    children: [
                      _statBox('${_orders.length}', 'Total', Colors.black),
                      const SizedBox(width: 10),
                      _statBox(
                        '$active',
                        'Delivering',
                        const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 10),
                      _statBox(
                        '$completed',
                        'Completed',
                        const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ),

                // ── Filter chips ───────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('all', 'All (${_orders.length})'),
                        const SizedBox(width: 8),
                        _chip('active', 'On Delivery ($active)'),
                        const SizedBox(width: 8),
                        _chip('completed', 'Completed ($completed)'),
                        const SizedBox(width: 8),
                        _chip(
                          'cancelled',
                          'Cancelled (${_orders.where((o) => o['status'] == 'Cancelled').length})',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 1),

                // ── List ───────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? _empty(Icons.shopping_bag_outlined, 'No orders here')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _orderCard(_filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['status'] as String? ?? 'On Delivery';
    final isDelivery = status == 'On Delivery';
    final isCompleted = status == 'Completed';
    final isCancelled = status == 'Cancelled';
    final orderId = o['id']?.toString() ?? '';
    final isProcessing = _processingId == orderId;
    final imageUrl = o['product_image_url'] as String?;
    final statusColor = _statusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: seller + status ─────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 13,
                    color: Color(0xFF9A9A9A),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    o['seller_name'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDelivery
                          ? Icons.local_shipping_outlined
                          : isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined,
                      size: 11,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
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

          // ── Product row ─────────────────────────────────
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 68,
                  height: 68,
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
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Size: ${o['size'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${o['price']} THB',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Shipping info ───────────────────────────────
          if (o['buyer_address'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Color(0xFF9A9A9A),
                      ),
                      const SizedBox(width: 4),
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
                  if ((o['buyer_phone'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: Color(0xFF9A9A9A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          o['buyer_phone'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // ปุ่มแก้ไขที่อยู่ (เฉพาะ On Delivery)
                  if (isDelivery) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _editAddress(o),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Edit shipping info',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Status banners ──────────────────────────────
          if (isCompleted) ...[
            const SizedBox(height: 10),
            _banner(
              Icons.check_circle_outline_rounded,
              const Color(0xFF16A34A),
              const Color(0xFFEAFAF0),
              'You confirmed receipt — order complete!',
            ),
          ],
          if (isCancelled) ...[
            const SizedBox(height: 10),
            _banner(
              Icons.cancel_outlined,
              const Color(0xFFDC2626),
              const Color(0xFFFFEEEE),
              'Order was cancelled — item re-listed',
            ),
          ],

          // ── Action buttons (On Delivery only) ──────────
          if (isDelivery) ...[
            const SizedBox(height: 14),
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmReceived(o),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'I Received My Item',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
              const SizedBox(height: 8),
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
                    'Cancel Order',
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
        ],
      ),
    );
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

  Widget _thumb() => Container(
    color: const Color(0xFFF0F0F0),
    child: const Center(
      child: Icon(Icons.checkroom_outlined, size: 28, color: Color(0xFFCCCCCC)),
    ),
  );
}
