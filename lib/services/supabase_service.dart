import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SupabaseService {
  // ─── AUTH ────────────────────────────────────────────────
  static User? get currentUser => supabase.auth.currentUser;
  static String? get currentUserId => supabase.auth.currentUser?.id;
  static bool get isLoggedIn => supabase.auth.currentUser != null;

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // ─── PROFILES ────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile() async {
    if (currentUserId == null) return null;
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', currentUserId!)
        .maybeSingle();
    return res;
  }

  static Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return res;
  }

  static Future<void> upsertProfile({
    required String userId,
    required String displayName,
    required String email,
    String? avatarUrl,
    String? bio,
  }) async {
    await supabase
        .from('profiles')
        .upsert(
          {
            'id': userId,
            'display_name': displayName,
            'email': email,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            if (bio != null) 'bio': bio,
          },
          onConflict: 'id',
          ignoreDuplicates: false,
        );
  }

  // ─── IMAGE UPLOAD ─────────────────────────────────────────
  static Future<String> uploadAvatar(File file) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final fileName = 'avatars/$userId.jpg';
    try {
      await supabase.storage
          .from('images')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
    } on StorageException catch (e) {
      throw Exception('Storage upload failed: ${e.message} (${e.statusCode})');
    }
    final url = supabase.storage.from('images').getPublicUrl(fileName);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<String> uploadProductImage(File file) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not logged in');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'products/$userId/$ts.jpg';
    try {
      await supabase.storage
          .from('images')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );
    } on StorageException catch (e) {
      throw Exception('Storage upload failed: ${e.message} (${e.statusCode})');
    }
    return supabase.storage.from('images').getPublicUrl(fileName);
  }

  static Future<void> updateAvatarUrl(String url) async {
    final userId = currentUserId;
    if (userId == null) return;
    await supabase
        .from('profiles')
        .upsert(
          {'id': userId, 'avatar_url': url},
          onConflict: 'id',
          ignoreDuplicates: false,
        );
  }

  // ─── PRODUCTS ─────────────────────────────────────────────

  /// ดึงสินค้าชิ้นเดียวพร้อมสถานะล่าสุด
  static Future<Map<String, dynamic>?> getProductById(String productId) async {
    final res = await supabase
        .from('products')
        .select()
        .eq('id', productId)
        .maybeSingle();
    return res;
  }

  /// ดึงเฉพาะสินค้า Active สำหรับหน้า Home
  static Future<List<Map<String, dynamic>>> getProducts({
    String? category,
  }) async {
    if (category != null && category != 'all') {
      final res = await supabase
          .from('products')
          .select()
          .eq('status', 'Active')
          .eq('category', category)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    }
    final res = await supabase
        .from('products')
        .select()
        .eq('status', 'Active')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// ค้นหาเฉพาะสินค้า Active
  static Future<List<Map<String, dynamic>>> searchProducts(
    String keyword, {
    String? category,
  }) async {
    if (category != null && category != 'all') {
      final res = await supabase
          .from('products')
          .select()
          .eq('status', 'Active')
          .eq('category', category)
          .ilike('name', '%$keyword%')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    }
    final res = await supabase
        .from('products')
        .select()
        .eq('status', 'Active')
        .ilike('name', '%$keyword%')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getMyProducts() async {
    if (currentUserId == null) return [];
    final res = await supabase
        .from('products')
        .select()
        .eq('seller_id', currentUserId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getProductsBySeller(
    String sellerId,
  ) async {
    final res = await supabase
        .from('products')
        .select()
        .eq('seller_id', sellerId)
        .eq('status', 'Active')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> addProduct(Map<String, dynamic> data) async {
    final profile = await getProfile();
    await supabase.from('products').insert({
      'seller_id': currentUserId!,
      'seller_name':
          profile?['display_name'] ??
          currentUser?.email?.split('@').first ??
          'Unknown Shop',
      ...data,
    });
  }

  static Future<void> deleteProduct(String productId) async {
    await supabase.from('products').delete().eq('id', productId);
  }

  static Future<void> markProductSold(String productId) async {
    await supabase
        .from('products')
        .update({'status': 'Sold'})
        .eq('id', productId);
  }

  static Future<void> markProductActive(String productId) async {
    await supabase
        .from('products')
        .update({'status': 'Active'})
        .eq('id', productId);
  }

  // ─── PURCHASES ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMyPurchases() async {
    if (currentUserId == null) return [];
    final res = await supabase
        .from('purchases')
        .select()
        .eq('buyer_id', currentUserId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getMySales() async {
    if (currentUserId == null) return [];
    final res = await supabase
        .from('purchases')
        .select()
        .eq('seller_id', currentUserId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> buyProduct({
    required Map<String, dynamic> product,
    required String buyerName,
    required String buyerAddress,
    required String buyerPhone,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    final productId = product['id'].toString();

    // ── Step 1: ตรวจสอบสถานะล่าสุดจาก DB ก่อนซื้อเสมอ ──
    final latest = await getProductById(productId);
    if (latest == null) throw Exception('Product not found');
    if (latest['status'] != 'Active') {
      throw Exception('This item has already been sold');
    }

    // ── Step 2: Mark Sold ก่อน เพื่อป้องกัน race condition ──
    // (ถ้า 2 คนกดซื้อพร้อมกัน คนที่ 2 จะ error ตรงนี้ผ่าน RLS/constraint)
    await markProductSold(productId);

    // ── Step 3: บันทึก purchase record ──
    try {
      await supabase.from('purchases').insert({
        'buyer_id': uid,
        'seller_id': product['seller_id'],
        'buyer_name': buyerName,
        'buyer_address': buyerAddress,
        'buyer_phone': buyerPhone,
        'product_id': productId,
        'product_name': product['name'],
        'product_image_url': product['image_url'] ?? '',
        'seller_name': product['seller_name'] ?? '',
        'size': product['size'] ?? '',
        'price': product['price'],
        'status': 'On Delivery',
        'buyer_received': false,
      });
    } catch (e) {
      // ถ้า insert purchase ล้มเหลว ให้ rollback สถานะสินค้ากลับ
      await markProductActive(productId);
      throw Exception('Purchase failed: $e');
    }

    // ── Step 4: Eco XP (optional, ไม่ throw ถ้า fail) ──
    try {
      await supabase.rpc('increment_eco_xp', params: {'user_id': uid});
    } catch (_) {}
  }

  static Future<void> confirmReceived(String purchaseId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');
    await supabase
        .from('purchases')
        .update({'status': 'Completed', 'buyer_received': true})
        .eq('id', purchaseId)
        .eq('buyer_id', uid);
  }

  static Future<void> cancelOrder(String purchaseId, String productId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    final check = await supabase
        .from('purchases')
        .select('id, status')
        .eq('id', purchaseId)
        .eq('buyer_id', uid)
        .maybeSingle();

    if (check == null) throw Exception('Order not found');
    if (check['status'] != 'On Delivery') {
      throw Exception('Cannot cancel: already ${check['status']}');
    }

    await supabase
        .from('purchases')
        .update({'status': 'Cancelled'})
        .eq('id', purchaseId)
        .eq('buyer_id', uid);

    await markProductActive(productId);
  }

  static Future<void> cancelOrderAsSeller(
    String purchaseId,
    String productId,
  ) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');

    await supabase
        .from('purchases')
        .update({'status': 'Cancelled'})
        .eq('id', purchaseId)
        .eq('seller_id', uid);

    await markProductActive(productId);
  }

  static Future<void> updateShippingAddress({
    required String purchaseId,
    required String newAddress,
    required String newPhone,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not logged in');
    await supabase
        .from('purchases')
        .update({'buyer_address': newAddress, 'buyer_phone': newPhone})
        .eq('id', purchaseId)
        .eq('buyer_id', uid)
        .eq('status', 'On Delivery');
  }

  // ─── ECO ──────────────────────────────────────────────────
  static Future<int> getBuyCount() async {
    if (currentUserId == null) return 0;
    // นับทั้ง On Delivery และ Completed (ไม่นับ Cancelled)
    final res = await supabase
        .from('purchases')
        .select()
        .eq('buyer_id', currentUserId!)
        .neq('status', 'Cancelled');
    return (res as List).length;
  }

  static Future<int> getBuyCountByUser(String userId) async {
    final res = await supabase
        .from('purchases')
        .select()
        .eq('buyer_id', userId)
        .neq('status', 'Cancelled');
    return (res as List).length;
  }

  static Future<int> getSellCountByUser(String userId) async {
    final res = await supabase
        .from('purchases')
        .select()
        .eq('seller_id', userId)
        .eq('status', 'Completed');
    return (res as List).length;
  }
}
