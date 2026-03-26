import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class QuickSplitScreen extends StatefulWidget {
  const QuickSplitScreen({super.key});

  @override
  State<QuickSplitScreen> createState() => _QuickSplitScreenState();
}

class _QuickSplitScreenState extends State<QuickSplitScreen> {
  int _step = 1;
  String _numStr = '';
  List<_Person> _people = [];
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _spendControllers = {};

  @override
  void dispose() {
    for (final c in _nameControllers.values) c.dispose();
    for (final c in _spendControllers.values) c.dispose();
    super.dispose();
  }

  void _numPress(String key) {
    setState(() {
      if (_numStr.length >= 2) return;
      if (key == '0' && _numStr.isEmpty) return;
      _numStr += key;
    });
  }

  void _numDelete() {
    setState(() {
      if (_numStr.isNotEmpty) _numStr = _numStr.substring(0, _numStr.length - 1);
    });
  }

  void _confirmPeople() {
    final n = int.tryParse(_numStr) ?? 0;
    if (n < 2) { _toast('Enter at least 2 people!'); return; }
    if (n > 20) { _toast('Max 20 people!'); return; }
    setState(() {
      _people = List.generate(n, (i) => _Person(name: 'Person ${i + 1}', spend: 0));
      _nameControllers.clear();
      _spendControllers.clear();
      _step = 2;
    });
  }

  void _calculate() {
    for (int i = 0; i < _people.length; i++) {
      final nameCtrl = _nameControllers[i];
      if (nameCtrl != null && nameCtrl.text.trim().isNotEmpty) {
        _people[i].name = nameCtrl.text.trim();
      }
      final spendCtrl = _spendControllers[i];
      _people[i].spend = double.tryParse(spendCtrl?.text ?? '') ?? 0;
    }
    setState(() => _step = 3);
  }

  void _reset() {
    setState(() {
      _step = 1;
      _numStr = '';
      _people = [];
      _nameControllers.clear();
      _spendControllers.clear();
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.orange,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text('⚡ Quick Split', style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 22,
                    fontWeight: FontWeight.w900, color: Colors.white,
                  )),
                  const Spacer(),
                  // Step indicator
                  Text('Step $_step/3', style: const TextStyle(
                    fontSize: 12, color: Colors.white60,
                  )),
                ],
              ),
            ),

            Expanded(
              child: _step == 1
                  ? _buildStep1(isDark, textColor)
                  : _step == 2
                      ? _buildStep2(isDark, textColor)
                      : _buildStep3(isDark, textColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 1: How many people ─────────────────────────────────────
  Widget _buildStep1(bool isDark, Color textColor) {
    final keyBg = isDark ? AppColors.darkSurface2 : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text('How many people?', style: TextStyle(
                fontFamily: 'Nunito', fontSize: 22,
                fontWeight: FontWeight.w900, color: textColor,
              )),
              const SizedBox(height: 8),
              Text('Max 20 people', style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              )),
              const SizedBox(height: 32),

              // Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.orange, width: 2),
                ),
                child: Text(
                  _numStr.isEmpty ? '_' : _numStr,
                  style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: _numStr.isEmpty ? AppColors.muted : AppColors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Numpad
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...['1','2','3','4','5','6','7','8','9'].map((k) =>
                    _numKey(k, keyBg, borderColor, textColor, () => _numPress(k))
                  ),
                  _numKey('', keyBg, borderColor, textColor, () {}),
                  _numKey('0', keyBg, borderColor, textColor, () => _numPress('0')),
                  _numKey('⌫', keyBg, borderColor, AppColors.error, _numDelete),
                ],
              ),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: _confirmPeople,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(child: Text('Next →', style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 17,
                    fontWeight: FontWeight.w800, color: Colors.white,
                  ))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numKey(String label, Color bg, Color border, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontFamily: 'Nunito', fontSize: 22,
          fontWeight: FontWeight.w800, color: color,
        ))),
      ),
    );
  }

  // ── STEP 2: Names & amounts ─────────────────────────────────────
  Widget _buildStep2(bool isDark, Color textColor) {
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE8C9A0);
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            itemCount: _people.length,
            itemBuilder: (context, i) {
              final nameCtrl = _nameControllers.putIfAbsent(
                i, () => TextEditingController(text: _people[i].name));
              final spendCtrl = _spendControllers.putIfAbsent(
                i, () => TextEditingController());

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppConstants.getAvatarColor(i),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text('${i + 1}', style: const TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                        color: Colors.white, fontSize: 14,
                      ))),
                    ),
                    const SizedBox(width: 10),

                    // Name input
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: nameCtrl,
                        style: TextStyle(
                          fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                          color: textColor, fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Name',
                          hintStyle: TextStyle(
                            color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4),
                          ),
                          filled: true, fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.orange),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Spend amount
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _openSpendNumpad(i, spendCtrl, nameCtrl.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              const Text('₹', style: TextStyle(
                                fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                                color: AppColors.orange, fontSize: 14,
                              )),
                              const SizedBox(width: 4),
                              Text(
                                spendCtrl.text.isEmpty ? '0' : spendCtrl.text,
                                style: TextStyle(
                                  fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: spendCtrl.text.isEmpty
                                      ? (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.5)
                                      : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _reset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    child: Center(child: Text('← Back', style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 15,
                      fontWeight: FontWeight.w800, color: textColor,
                    ))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _calculate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('Calculate →', style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 15,
                      fontWeight: FontWeight.w800, color: Colors.white,
                    ))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openSpendNumpad(int i, TextEditingController ctrl, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SpendNumpad(
        initial: ctrl.text,
        name: name.isEmpty ? 'Person ${i + 1}' : name,
        onConfirm: (val) => setState(() => ctrl.text = val),
      ),
    );
  }

  // ── STEP 3: Results ─────────────────────────────────────────────
  Widget _buildStep3(bool isDark, Color textColor) {
    final total = _people.fold(0.0, (sum, p) => sum + p.spend);
    final fairShare = _people.isEmpty ? 0.0 : total / _people.length;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    // Calculate transactions
    final balances = _people.map((p) => p.spend - fairShare).toList();
    final transactions = <Map<String, dynamic>>[];
    final debtors = <Map<String, dynamic>>[];
    final creditors = <Map<String, dynamic>>[];

    for (int i = 0; i < _people.length; i++) {
      if (balances[i] < -0.01) debtors.add({'name': _people[i].name, 'amt': -balances[i]});
      if (balances[i] > 0.01) creditors.add({'name': _people[i].name, 'amt': balances[i]});
    }

    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = (debtors[i]['amt'] as double) < (creditors[j]['amt'] as double)
          ? debtors[i]['amt'] as double
          : creditors[j]['amt'] as double;
      if (pay > 0.01) {
        transactions.add({
          'from': debtors[i]['name'],
          'to': creditors[j]['name'],
          'amount': pay.round(),
        });
      }
      debtors[i]['amt'] = (debtors[i]['amt'] as double) - pay;
      creditors[j]['amt'] = (creditors[j]['amt'] as double) - pay;
      if ((debtors[i]['amt'] as double) < 0.01) i++;
      if ((creditors[j]['amt'] as double) < 0.01) j++;
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('Total Spent', '₹${total.round()}'),
                    _summaryItem('People', '${_people.length}'),
                    _summaryItem('Fair Share', '₹${fairShare.round()}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (transactions.isEmpty) ...[
                Center(child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text('Everyone paid equally!', style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 16,
                      fontWeight: FontWeight.w800, color: textColor,
                    )),
                  ],
                )),
              ] else ...[
                Text('WHO PAYS WHOM', style: const TextStyle(
                  fontFamily: 'Nunito', fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange, letterSpacing: 1,
                )),
                const SizedBox(height: 12),
                ...transactions.map((t) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Text(t['from'], style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                        fontSize: 15, color: textColor,
                      )),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: AppColors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t['to'], style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                        fontSize: 15, color: textColor,
                      ))),
                      Text('₹${t['amount']}', style: const TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                        fontSize: 18, color: AppColors.orange,
                      )),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),

        // Split Again button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GestureDetector(
            onTap: _reset,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Text('Split Again 🔄', style: TextStyle(
                fontFamily: 'Nunito', fontSize: 16,
                fontWeight: FontWeight.w800, color: Colors.white,
              ))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(
          fontSize: 10, color: Colors.white60,
          letterSpacing: 0.5, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w900, color: Colors.white,
        )),
      ],
    );
  }
}

class _Person {
  String name;
  double spend;
  _Person({required this.name, required this.spend});
}

// ── SPEND NUMPAD ───────────────────────────────────────────────────
class _SpendNumpad extends StatefulWidget {
  final String initial;
  final String name;
  final Function(String) onConfirm;
  const _SpendNumpad({required this.initial, required this.name, required this.onConfirm});

  @override
  State<_SpendNumpad> createState() => _SpendNumpadState();
}

class _SpendNumpadState extends State<_SpendNumpad> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.isEmpty ? '0' : widget.initial;
  }

  void _press(String key) {
    setState(() {
      if (key == '.' && _value.contains('.')) return;
      if (_value == '0' && key != '.') _value = key;
      else _value += key;
    });
  }

  void _delete() {
    setState(() {
      _value = _value.length > 1 ? _value.substring(0, _value.length - 1) : '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final keyBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.orange, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${widget.name}'s spend", style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkMuted : AppColors.muted,
          )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('₹', style: TextStyle(
                fontFamily: 'Nunito', fontSize: 36,
                fontWeight: FontWeight.w900, color: AppColors.orange,
              )),
              const SizedBox(width: 4),
              Text(_value, style: TextStyle(
                fontFamily: 'Nunito', fontSize: 48,
                fontWeight: FontWeight.w900, color: textColor,
              )),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 10, crossAxisSpacing: 10,
            childAspectRatio: 2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...['1','2','3','4','5','6','7','8','9','.','0'].map((k) =>
                _key(k, keyBg, borderColor, textColor, () => _press(k))
              ),
              _key('⌫', keyBg, borderColor, AppColors.error, _delete),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              widget.onConfirm(_value == '0' ? '' : _value);
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Text('Done ✓', style: TextStyle(
                fontFamily: 'Nunito', fontSize: 17,
                fontWeight: FontWeight.w800, color: Colors.white,
              ))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(String label, Color bg, Color border, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontFamily: 'Nunito', fontSize: 22,
          fontWeight: FontWeight.w800, color: color,
        ))),
      ),
    );
  }
}