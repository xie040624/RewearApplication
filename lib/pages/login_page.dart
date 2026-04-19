import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In fields
  final _loginEmailCtrl    = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // Sign Up fields
  final _regUsernameCtrl = TextEditingController();
  final _regEmailCtrl    = TextEditingController();
  final _regPasswordCtrl = TextEditingController();

  bool _loading      = false;
  bool _obscureLogin = true;
  bool _obscureReg   = true;

  // ── demo email generator ─────────────────────────────
  static const _adj  = ['cool','vintage','eco','green','style','urban','retro','fresh','clean','pure'];
  static const _noun = ['wear','fit','look','thread','drip','outfit','style','cloth'];

  void _generateDemoEmail() {
    final adj  = (_adj..shuffle()).first;
    final noun = (_noun..shuffle()).first;
    final num  = DateTime.now().millisecondsSinceEpoch % 9999;
    _regEmailCtrl.text = '$adj$noun$num@demo.rewear';
    setState(() {});
  }

  // ─────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ถ้า login อยู่แล้ว ข้ามไปหน้า home เลย
    if (SupabaseService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
    }

    // ฟัง auth state change → redirect ทันทีที่ sign-in สำเร็จ
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        // บันทึก/อัปเดต profile หลัง sign-in
        _upsertProfileSilently();
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    super.dispose();
  }

  // บันทึก profile โดยไม่รบกวน UX
  Future<void> _upsertProfileSilently() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final displayName = user.userMetadata?['full_name'] as String? ??
          user.email?.split('@').first ??
          'User';
      await SupabaseService.upsertProfile(
        userId: user.id,
        displayName: displayName,
        email: user.email ?? '',
      );
    } catch (_) {
      // ไม่ block ถ้า profile table ยังไม่พร้อม
    }
  }

  // ── Sign In ──────────────────────────────────────────
  Future<void> _signIn() async {
    final email    = _loginEmailCtrl.text.trim();
    final password = _loginPasswordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showErr('Please enter email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) _showErr(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Sign Up ──────────────────────────────────────────
  // Strategy:
  //   1. signUp() → Supabase สร้าง user
  //   2. ถ้า session กลับมา (email confirm ปิด) → เข้าระบบได้เลย
  //   3. ถ้าไม่มี session (email confirm เปิด) → signInWithPassword ทันที
  //      เพื่อ bypass confirm (ใช้ได้กับ Supabase ที่ตั้ง "Confirm email" = off
  //      หรือกรณี demo ที่ email จะไม่ถูก deliver)
  Future<void> _signUp() async {
    final email    = _regEmailCtrl.text.trim();
    final password = _regPasswordCtrl.text.trim();
    final username = _regUsernameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErr('Please enter email and password');
      return;
    }
    if (password.length < 6) {
      _showErr('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);
    try {
      final displayName = username.isNotEmpty ? username : email.split('@').first;

      // ── ลอง signUp ──────────────────────────
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': displayName},
      );

      // กรณี 1: email confirm ปิด → session กลับมาทันที
      if (res.session != null) {
        // onAuthStateChange จะ redirect ให้เอง
        return;
      }

      // กรณี 2: email confirm เปิด → sign in ทันที (demo bypass)
      // Supabase สร้าง user แล้ว แต่ยัง unconfirmed
      // เราสามารถ signIn ได้เลยถ้าปิด "Confirm email" ใน dashboard
      try {
        await supabase.auth.signInWithPassword(email: email, password: password);
        // onAuthStateChange จะ redirect ให้เอง
      } on AuthException catch (_) {
        // ถ้า signIn ยังไม่ได้ → แจ้งให้ปิด email confirm ใน Supabase
        if (mounted) {
          _showErr(
            'Please disable "Confirm email" in Supabase Dashboard\n'
            '(Authentication → Providers → Email → turn OFF Confirm email)',
          );
        }
      }
    } on AuthException catch (e) {
      // user สมัครซ้ำ → sign in แทน
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already been registered')) {
        try {
          await supabase.auth.signInWithPassword(
            email: _regEmailCtrl.text.trim(),
            password: _regPasswordCtrl.text.trim(),
          );
        } on AuthException catch (e2) {
          if (mounted) _showErr(e2.message);
        }
      } else {
        if (mounted) _showErr(e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  // ── Decoration helper ────────────────────────────────
  InputDecoration _dec(
    String label,
    IconData icon, {
    bool obscure = false,
    VoidCallback? toggle,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF8A8A8A),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, size: 17, color: const Color(0xFFAAAAAA)),
        suffixIcon: toggle != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 17,
                  color: const Color(0xFFAAAAAA),
                ),
                onPressed: toggle,
              )
            : suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  // ── Primary button ───────────────────────────────────
  Widget _btn(String label, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      );

  // ── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),

              // Logo
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.checkroom, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ReWear',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Secondhand fashion, first choice.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
              ),

              const SizedBox(height: 48),

              // Tab bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF8A8A8A),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 360,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // ── Sign In tab ──────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _loginEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: _dec('Email', Icons.mail_outline_rounded),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _loginPasswordCtrl,
                          obscureText: _obscureLogin,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: _dec(
                            'Password',
                            Icons.lock_outline_rounded,
                            obscure: _obscureLogin,
                            toggle: () => setState(() => _obscureLogin = !_obscureLogin),
                          ),
                          onSubmitted: (_) => _signIn(),
                        ),
                        const SizedBox(height: 28),
                        _btn('Sign In', _loading ? null : _signIn),
                      ],
                    ),

                    // ── Sign Up tab ──────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email + auto-generate button
                        TextField(
                          controller: _regEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: _dec(
                            'Email (or tap ✨ to generate demo)',
                            Icons.mail_outline_rounded,
                            suffix: IconButton(
                              icon: const Icon(Icons.auto_awesome,
                                  size: 17, color: Color(0xFFAAAAAA)),
                              tooltip: 'Generate demo email',
                              onPressed: _generateDemoEmail,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // hint text
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Display name (optional)
                        TextField(
                          controller: _regUsernameCtrl,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: _dec(
                            'Display Name (optional)',
                            Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Password
                        TextField(
                          controller: _regPasswordCtrl,
                          obscureText: _obscureReg,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: _dec(
                            'Password (min 6 chars)',
                            Icons.lock_outline_rounded,
                            obscure: _obscureReg,
                            toggle: () => setState(() => _obscureReg = !_obscureReg),
                          ),
                          onSubmitted: (_) => _signUp(),
                        ),
                        const SizedBox(height: 28),
                        _btn('Create Account', _loading ? null : _signUp),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Demo note
              Center(
                child: Text(
                  'Demo app — any email format accepted',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}