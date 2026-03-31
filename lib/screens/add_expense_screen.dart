import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/group.dart';
import '../utils/constants.dart';
import '../services/db_service.dart';

class AddExpenseSheet extends StatefulWidget {
  final String groupId;
  final List<String> members; // <--- NEW: We require the members list now
  const AddExpenseSheet({super.key, required this.groupId, required this.members});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = '🍽️';
  String? _paidBy;
  List<String> _splitAmong = [];

  @override
  void initState() {
    super.initState();
    // Use the passed members list instead of asking AppProvider!
    _paidBy = widget.members.contains('You') ? 'You' : widget.members.first;
    _splitAmong = List.from(widget.members); 
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _toggleMember(String member) {
    setState(() {
      if (_splitAmong.contains(member)) {
        if (_splitAmong.length > 1) _splitAmong.remove(member);
      } else {
        _splitAmong.add(member);
      }
    });
  }

  String? _error;

  void _saveExpense() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (name.isEmpty) { setState(() => _error = 'Enter expense name!'); return; }
    if (amount <= 0) { setState(() => _error = 'Enter a valid amount!'); return; }
    if (_splitAmong.isEmpty) { setState(() => _error = 'Select at least one member!'); return; }

    setState(() => _error = null);

    // 1. Send it directly to Firebase!
    final db = DatabaseService();
    await db.addExpense(widget.groupId, name, amount, _paidBy!, _splitAmong, _selectedCategory);

    // 2. Safety check
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    _toast('Expense added! 💸');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.orange,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _openNumpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NumpadSheet(
        initial: _amountController.text,
        onConfirm: (val) => setState(() => _amountController.text = val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;
    //final group = provider.groups.firstWhere((g) => g.id == widget.groupId);
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);

    final share = _splitAmong.isEmpty ? 0.0
        : (double.tryParse(_amountController.text) ?? 0) / _splitAmong.length;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 16),

            // Title
            Text('Add Expense', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 22,
              fontWeight: FontWeight.w900, color: textColor,
            )),
            const SizedBox(height: 20),

            // Category icons
            _label('CATEGORY'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AppConstants.expenseCategories.map((cat) {
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                  },
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.orange : borderColor,
                        width: selected ? 2 : 1.5,
                      ),
                    ),
                    child: Center(child: Text(cat, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Description
            _label('DESCRIPTION'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g. Dinner, Hotel, Cab...',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkMuted.withOpacity(0.5)
                      : AppColors.muted.withOpacity(0.35),
                  fontWeight: FontWeight.w500,
                ),
                filled: true, fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            _label('AMOUNT'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openNumpad,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Text('₹', style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.orange,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _amountController.text.isEmpty ? 'Enter amount' : _amountController.text,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _amountController.text.isEmpty
                              ? (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.35)
                              : textColor,
                        ),
                      ),
                    ),
                    if (_splitAmong.isNotEmpty && (double.tryParse(_amountController.text) ?? 0) > 0)
                      Text('₹${share.round()}/person',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkMuted : AppColors.muted,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Paid by
            _label('PAID BY'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paidBy,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.darkSurface2 : Colors.white,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: 15,
                  ),
                  items: widget.members.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m),
                  )).toList(),
                  onChanged: (val) => setState(() => _paidBy = val),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Split among
            _label('SPLIT AMONG'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.members.map((m) {
                final selected = _splitAmong.contains(m);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _toggleMember(m);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.orange : borderColor,
                      ),
                    ),
                    child: Text(m, style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? AppColors.orange : textColor,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Inline error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Text(_error!, style: const TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 13, color: AppColors.error,
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Save button
            GestureDetector(
              onTap: _saveExpense,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text('Save Expense →',
                  style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 16,
                    fontWeight: FontWeight.w800, color: Colors.white,
                  ))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(
    fontFamily: 'Nunito', fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.orange, letterSpacing: 0.5,
  ));
}

// ── NUMPAD SHEET ───────────────────────────────────────────────────
class _NumpadSheet extends StatefulWidget {
  final String initial;
  final Function(String) onConfirm;
  const _NumpadSheet({required this.initial, required this.onConfirm});

  @override
  State<_NumpadSheet> createState() => _NumpadSheetState();
}

class _NumpadSheetState extends State<_NumpadSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.isEmpty ? '0' : widget.initial;
  }

  void _press(String key) {
    setState(() {
      if (key == '.' && _value.contains('.')) return;
      if (_value == '0' && key != '.') {
        _value = key;
      } else {
        if (_value.contains('.')) {
          final parts = _value.split('.');
          if (parts[1].length >= 2) return;
        }
        _value += key;
      }
    });
  }

  void _delete() {
    setState(() {
      if (_value.length > 1) {
        _value = _value.substring(0, _value.length - 1);
      } else {
        _value = '0';
      }
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
          // Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('₹', style: const TextStyle(
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

          // Keys
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
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

          // Done button
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
              child: const Center(child: Text('Done ✓',
                style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 17,
                  fontWeight: FontWeight.w800, color: Colors.white,
                ))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(String label, Color bg, Color border, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontFamily: 'Nunito', fontSize: 22,
          fontWeight: FontWeight.w800, color: textColor,
        ))),
      ),
    );
  }
}