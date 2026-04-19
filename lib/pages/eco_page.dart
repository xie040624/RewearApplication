import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class EcoPage extends StatefulWidget {
  const EcoPage({super.key});
  @override
  State<EcoPage> createState() => _EcoPageState();
}

class _EcoPageState extends State<EcoPage> {
  int _buyCount = 0;
  bool _loading = true;

  static const List<Map<String, dynamic>> _levels = [
    {'name': 'Beginner',     'min': 0,  'max': 2},
    {'name': 'Starter',      'min': 3,  'max': 5},
    {'name': 'Eco Lover',    'min': 6,  'max': 10},
    {'name': 'Green Hero',   'min': 11, 'max': 20},
    {'name': 'Planet Saver', 'min': 21, 'max': 9999},
  ];

  Map<String, dynamic> get _currentLevel {
    for (final lv in _levels) {
      if (_buyCount <= lv['max']) return lv;
    }
    return _levels.last;
  }

  int get _levelIndex => _levels.indexOf(_currentLevel);

  double get _progress {
    final lv    = _currentLevel;
    final range = (lv['max'] as int) - (lv['min'] as int);
    final done  = _buyCount - (lv['min'] as int);
    if (range <= 0) return 1.0;
    return (done / range).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final count = await SupabaseService.getBuyCount();
      if (mounted) setState(() => _buyCount = count);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lv   = _currentLevel;
    final next = _levelIndex < _levels.length - 1 ? _levels[_levelIndex + 1] : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Eco Impact',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.4)),
        centerTitle: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.black,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Level card ────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level ${_levelIndex + 1}',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lv['name'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8),
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$_buyCount items purchased',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                              if (next != null)
                                Text('Next: ${next['name']}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Impact stats ───────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: const Text('Your Impact',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: -0.1)),
                          ),
                          _statRow('Items Reused', '$_buyCount items'),
                          _div(),
                          _statRow('Water Saved', '${_buyCount * 2700} liters'),
                          _div(),
                          _statRow('CO2 Reduced', '${(_buyCount * 2.1).toStringAsFixed(1)} kg'),
                          _div(),
                          _statRow('Textile Waste Prevented',
                              '${(_buyCount * 0.5).toStringAsFixed(1)} kg'),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Roadmap ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: const Text('Level Roadmap',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: -0.1)),
                    ),
                    ..._levels.asMap().entries.map((e) {
                      final i         = e.key;
                      final l         = e.value;
                      final isReached = _buyCount >= (l['min'] as int);
                      final isCurrent = l == _currentLevel;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Colors.white.withOpacity(0.15)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrent ? Colors.white : const Color(0xFF555555))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: -0.2,
                                      color: isCurrent
                                          ? Colors.white
                                          : isReached
                                              ? Colors.black
                                              : const Color(0xFFAAAAAA),
                                    ),
                                  ),
                                  Text(
                                    '${l['min']}${l['max'] == 9999 ? '+' : '–${l['max']}'} items',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isCurrent
                                            ? Colors.white54
                                            : const Color(0xFFAAAAAA)),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text('Current',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              )
                            else if (isReached)
                              const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.black),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1)),
          ],
        ),
      );

  Widget _div() => const Divider(color: Color(0xFFF5F5F5), height: 1, indent: 16, endIndent: 16);
}