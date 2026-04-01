import '../services/db_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/group.dart';
import '../utils/constants.dart';
import 'add_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final int initialTab;
  const GroupDetailScreen({super.key, required this.groupId, this.initialTab = 0});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Group? _getGroup(AppProvider provider) {
    try {
      return provider.groups.firstWhere((g) => g.id == widget.groupId);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _calcBalances(Group group) {
    final net = <String, double>{};
    for (final m in group.members) net[m] = 0;
    for (final exp in group.activeExpenses) {
      final share = exp.amount / exp.splitAmong.length;
      net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;
      for (final m in exp.splitAmong) {
        net[m] = (net[m] ?? 0) - share;
      }
    }
    final transactions = <Map<String, dynamic>>[];
    final debtors = net.entries
        .where((e) => e.value < -0.01)
        .map((e) => {'name': e.key, 'amt': -e.value})
        .toList();
    final creditors = net.entries
        .where((e) => e.value > 0.01)
        .map((e) => {'name': e.key, 'amt': e.value})
        .toList();
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = (debtors[i]['amt'] as double) < (creditors[j]['amt'] as double)
          ? debtors[i]['amt'] as double
          : creditors[j]['amt'] as double;
      if (pay > 0.01) {
        transactions.add({
          'from': debtors[i]['name'],
          'to': creditors[j]['name'],
          'amount': pay,
        });
      }
      debtors[i]['amt'] = (debtors[i]['amt'] as double) - pay;
      creditors[j]['amt'] = (creditors[j]['amt'] as double) - pay;
      if ((debtors[i]['amt'] as double) < 0.01) i++;
      if ((creditors[j]['amt'] as double) < 0.01) j++;
    }
    return transactions;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;
    final currency = provider.currency; // <-- DYNAMIC CURRENCY

    // Helper to safely convert Firebase Timestamps to standard Dart DateTimes
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate(); // Handles Firebase dates!
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: isDark ? AppColors.darkBg : AppColors.cream, body: const Center(child: CircularProgressIndicator(color: AppColors.orange)));
        }
        if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Group not found')));
        }

        final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('expenses').snapshots(),
          builder: (context, expenseSnapshot) {
            
            if (expenseSnapshot.hasError) {
              return Scaffold(body: Center(child: Text('Database Error: ${expenseSnapshot.error}')));
            }

            final List<Expense> liveExpenses = (expenseSnapshot.data?.docs ?? []).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Expense(
                id: doc.id, 
                name: data['name'] ?? 'Unnamed',
                amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
                paidBy: data['paidBy'] ?? '',
                splitAmong: List<String>.from(data['splitAmong'] ?? []),
                category: data['category'] ?? '💸',
                date: parseDate(data['date']),
                deleted: data['deleted'] ?? false,
                deletedAt: data['deletedAt'] != null ? parseDate(data['deletedAt']) : null,
                isSettlement: data['isSettlement'] ?? false,
                isGhost: data['isGhost'] ?? false,
                ghostText: data['ghostText'],
              );
            }).toList();

            liveExpenses.sort((a, b) => a.date.compareTo(b.date));

            final group = Group(
              id: widget.groupId,
              name: groupData['name'] ?? 'Unnamed',
              emoji: groupData['emoji'] ?? '👥',
              members: List<String>.from(groupData['members'] ?? []),
              expenses: liveExpenses, 
              createdAt: parseDate(groupData['createdAt']),
            );

            final bg = isDark ? AppColors.darkBg : AppColors.cream;
            final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
            final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
            final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

            final balances = _calcBalances(group);
            double myOwe = 0, myReceive = 0;
            for (final t in balances) {
              if (t['from'] == 'You') myOwe += t['amount'] as double;
              if (t['to'] == 'You') myReceive += t['amount'] as double;
            }

      return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: AppColors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text('Back', style: TextStyle(
                          color: AppColors.orange,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Center(
                          child: Text(group.emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          )),
                          Text('${group.members.length} members',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkMuted : AppColors.muted,
                            )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // <-- UPDATED CURRENCY IN CARDS -->
                      Expanded(child: _balanceCard('YOU OWE', '$currency${myOwe.round()}',
                          AppColors.error, surfaceColor, borderColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _balanceCard('YOU GET BACK', '$currency${myReceive.round()}',
                          AppColors.success, surfaceColor, borderColor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.orange,
                      unselectedLabelColor: isDark ? AppColors.darkMuted : AppColors.muted,
                      labelStyle: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'Expenses'),
                        Tab(text: 'Balances'),
                        Tab(text: 'Settle Up'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ExpensesTab(group: group, isDark: isDark),
                  _BalancesTab(group: group, balances: balances, isDark: isDark),
                  _SettleUpTab(group: group, balances: balances, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddExpenseSheet(
              groupId: widget.groupId,
              members: group.members,
            ),
          );
        },
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
    },
    );
    },
    );
  }

  Widget _balanceCard(String label, String amount, Color amountColor,
      Color surface, Color border) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.orange,
            letterSpacing: 0.5,
          )),
          const SizedBox(height: 6),
          Text(amount, style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: amountColor,
          )),
        ],
      ),
    );
  }
}

// ── EXPENSES TAB ───────────────────────────────────────────────────
class _ExpensesTab extends StatelessWidget {
  final Group group;
  final bool isDark;
  const _ExpensesTab({required this.group, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppProvider>().currency; // <-- GET CURRENCY
    final expenses = group.expenses.reversed.toList();

    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No expenses yet', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1C1C1C),
            )),
            const SizedBox(height: 8),
            Text('Tap + to add the first expense', style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final exp = expenses[index];
        final expDate = DateFormat('d MMM yyyy').format(
          exp.deleted ? (exp.deletedAt ?? exp.date) : exp.date
        );
        String? prevDate;
        if (index > 0) {
          final prev = expenses[index - 1];
          prevDate = DateFormat('d MMM yyyy').format(
            prev.deleted ? (prev.deletedAt ?? prev.date) : prev.date
          );
        }
        final showDateSep = index == 0 || expDate != prevDate;

        return Column(
          children: [
            if (showDateSep)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.border, thickness: 1)),
                    const SizedBox(width: 10),
                    Text(expDate, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.border, thickness: 1)),
                  ],
                ),
              ),

            if (exp.deleted || exp.isGhost)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(exp.isGhost ? (exp.category == '✅' ? '✅' : '🔄') : '🚫',
                      style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    // <-- UPDATED CURRENCY -->
                    Expanded(child: Text(
                      exp.isGhost ? (exp.ghostText ?? '') : 'You deleted · $currency${exp.amount.round()} · ${exp.name}',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13,
                        color: isDark ? AppColors.darkMuted : AppColors.muted),
                    )),
                    Text(DateFormat('hh:mm a').format(exp.deletedAt ?? exp.date),
                      style: TextStyle(fontSize: 10,
                        color: isDark ? AppColors.darkMuted : AppColors.muted)),
                  ],
                ),
              )
            else
              Dismissible(
                key: Key(exp.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context, exp),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error, size: 24),
                      SizedBox(height: 4),
                      Text('Delete', style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                        fontSize: 11, color: AppColors.error,
                      )),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onTap: () => _openEditSheet(context, exp),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      )),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text(exp.category, style: const TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.name, style: TextStyle(
                                fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                              )),
                              Text('Paid by ${exp.paidBy} · ${exp.splitAmong.length} people',
                                style: TextStyle(fontSize: 12,
                                  color: isDark ? AppColors.darkMuted : AppColors.muted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // <-- UPDATED CURRENCY -->
                            Text('$currency${exp.amount.round()}', style: const TextStyle(
                              fontFamily: 'Nunito', fontSize: 16,
                              fontWeight: FontWeight.w900, color: AppColors.orange,
                            )),
                            Text('$currency${(exp.amount / exp.splitAmong.length).round()}/person',
                              style: TextStyle(fontSize: 11,
                                color: isDark ? AppColors.darkMuted : AppColors.muted)),
                            Text(DateFormat('hh:mm a').format(exp.date),
                              style: TextStyle(fontSize: 10,
                                color: isDark ? AppColors.darkMuted : AppColors.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Expense exp) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${exp.name}"?', style: const TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w900,
        )),
        content: const Text("This can't be undone. A ghost record will remain."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final db = DatabaseService();
      await db.deleteExpense(group.id, exp.id); 
      HapticFeedback.mediumImpact();
    }
    
    return false; 
  }

  void _openEditSheet(BuildContext context, Expense exp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditExpenseSheet(groupId: group.id, expense: exp, members: group.members),
    );
  }
}

// ── BALANCES TAB ───────────────────────────────────────────────────
class _BalancesTab extends StatelessWidget {
  final Group group;
  final List<Map<String, dynamic>> balances;
  final bool isDark;
  const _BalancesTab({required this.group, required this.balances, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppProvider>().currency; // <-- GET CURRENCY

    final net = <String, double>{};
    for (final m in group.members) net[m] = 0;
    for (final exp in group.activeExpenses) {
      final share = exp.amount / exp.splitAmong.length;
      net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;
      for (final m in exp.splitAmong) {
        net[m] = (net[m] ?? 0) - share;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: group.members.length,
      itemBuilder: (context, i) {
        final m = group.members[i];
        final bal = (net[m] ?? 0).round();
        final color = bal > 0
            ? AppColors.success
            : bal < 0
                ? AppColors.error
                : isDark ? AppColors.darkMuted : AppColors.muted;
        
        // <-- UPDATED CURRENCY -->
        final label = bal > 0
            ? 'gets back $currency$bal'
            : bal < 0
                ? 'owes $currency${bal.abs()}'
                : 'settled up ✓';

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            )),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.getAvatarColor(i),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(m[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(m, style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF1C1C1C),
              ))),
              Text(label, style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: color,
              )),
            ],
          ),
        );
      },
    );
  }
}

// ── SETTLE UP TAB ──────────────────────────────────────────────────
class _SettleUpTab extends StatefulWidget {
  final Group group;
  final List<Map<String, dynamic>> balances;
  final bool isDark;
  const _SettleUpTab({required this.group, required this.balances, required this.isDark});

  @override
  State<_SettleUpTab> createState() => _SettleUpTabState();
}

class _SettleUpTabState extends State<_SettleUpTab> {
  final Map<int, TextEditingController> _partialControllers = {};
  final Map<int, bool> _showPartial = {};
  final Map<int, bool> _settling = {};

  @override
  void dispose() {
    for (final c in _partialControllers.values) c.dispose();
    super.dispose();
  }

  void _markFullSettled(int i, String currency) async {
    final t = widget.balances[i];
    
    setState(() => _settling[i] = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final from = t['from'] as String;
    final to = t['to'] as String;
    final amount = t['amount'] as double;

    final db = DatabaseService();
    await db.addSettlement(
      widget.group.id,
      '$from paid $to',
      amount,
      from,
      to,
      '✅',
      '$from settled $currency${amount.round()} → $to' // <-- UPDATED CURRENCY
    );

    if (mounted) {
      setState(() => _settling.remove(i)); 
      HapticFeedback.mediumImpact();
      _showToast('Fully settled! ✅');
    }
  }

  void _markPartialSettled(int i, String currency) async {
    final t = widget.balances[i];
    final ctrl = _partialControllers[i];
    final partial = double.tryParse(ctrl?.text ?? '') ?? 0;
    final full = t['amount'] as double;

    if (partial <= 0) { _showToast('Enter an amount!'); return; }
    if (partial >= full) { _showToast('Use Full ✓ for full amount!'); return; }

    final from = t['from'] as String;
    final to = t['to'] as String;

    final db = DatabaseService();
    await db.addSettlement(
      widget.group.id,
      '$from partially paid $to',
      partial,
      from,
      to,
      '🔄',
      '$from partially paid $currency${partial.round()} → $to' // <-- UPDATED CURRENCY
    );

    if (mounted) {
      setState(() => _showPartial[i] = false);
      ctrl?.clear();
      HapticFeedback.mediumImpact();
      _showToast('$currency${partial.round()} recorded! 🔄'); // <-- UPDATED CURRENCY
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.orange,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _openNumpadForPartial(int i) {
    final ctrl = _partialControllers.putIfAbsent(i, () => TextEditingController());
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PartialNumpad(
        initial: ctrl.text,
        max: (widget.balances[i]['amount'] as double).round(),
        onConfirm: (val) => setState(() => ctrl.text = val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AppProvider>().currency; // <-- GET CURRENCY

    if (widget.balances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('All Settled!', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white : const Color(0xFF1C1C1C),
            )),
            const SizedBox(height: 8),
            Text('No pending dues in this group', style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? AppColors.darkMuted : AppColors.muted,
            )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: widget.balances.length,
      itemBuilder: (context, i) {
        final t = widget.balances[i];
        final fromIdx = widget.group.members.indexOf(t['from'] as String);
        final toIdx = widget.group.members.indexOf(t['to'] as String);
        final amount = (t['amount'] as double).round();
        final isSettling = _settling[i] ?? false;
        final showPartial = _showPartial[i] ?? false;
        final ctrl = _partialControllers.putIfAbsent(i, () => TextEditingController());
        final surfaceColor = widget.isDark ? AppColors.darkSurface : Colors.white;
        final borderColor = widget.isDark ? AppColors.darkBorder : AppColors.border;
        final textColor = widget.isDark ? Colors.white : const Color(0xFF1C1C1C);

        return AnimatedOpacity(
          opacity: isSettling ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppConstants.getAvatarColor(fromIdx),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(
                        (t['from'] as String)[0].toUpperCase(),
                        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white),
                      )),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: AppColors.orange, size: 18),
                    const SizedBox(width: 8),

                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppConstants.getAvatarColor(toIdx),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(
                        (t['to'] as String)[0].toUpperCase(),
                        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white),
                      )),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${t['from']} → ${t['to']}', style: TextStyle(
                            fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                            fontSize: 14, color: textColor,
                          )),
                          Text('$currency$amount', style: const TextStyle( // <-- UPDATED CURRENCY
                            fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                            fontSize: 18, color: AppColors.orange,
                          )),
                        ],
                      ),
                    ),

                    Column(
                      children: [
                        _settleBtn('Full ✓', AppColors.success, () => _markFullSettled(i, currency)),
                        const SizedBox(height: 6),
                        _settleBtn('Partial', AppColors.orange, () {
                          setState(() => _showPartial[i] = !showPartial);
                          if (!showPartial) _openNumpadForPartial(i);
                        }),
                      ],
                    ),
                  ],
                ),

                if (showPartial) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('How much is ${t['from']} paying now?',
                    style: TextStyle(fontSize: 12, color: widget.isDark ? AppColors.darkMuted : AppColors.muted)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openNumpadForPartial(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: widget.isDark ? AppColors.darkSurface2 : AppColors.peach,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.orange),
                            ),
                            child: Row(
                              children: [
                                Text(currency, style: const TextStyle( // <-- UPDATED CURRENCY
                                  fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                                  color: AppColors.orange, fontSize: 16,
                                )),
                                const SizedBox(width: 6),
                                Text(
                                  ctrl.text.isEmpty ? 'Enter amount' : ctrl.text,
                                  style: TextStyle(
                                    fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                                    color: ctrl.text.isEmpty
                                        ? (widget.isDark ? AppColors.darkMuted : AppColors.muted)
                                        : textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _markPartialSettled(i, currency),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Confirm', style: TextStyle(
                            fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                            color: Colors.white, fontSize: 13,
                          )),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showPartial[i] = false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark ? AppColors.darkSurface2 : AppColors.peach,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settleBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w800,
          fontSize: 12, color: color,
        )),
      ),
    );
  }
}

// ── PARTIAL NUMPAD ─────────────────────────────────────────────────
class _PartialNumpad extends StatefulWidget {
  final String initial;
  final int max;
  final Function(String) onConfirm;
  const _PartialNumpad({required this.initial, required this.max, required this.onConfirm});

  @override
  State<_PartialNumpad> createState() => _PartialNumpadState();
}

class _PartialNumpadState extends State<_PartialNumpad> {
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
    final provider = context.read<AppProvider>();
    final isDark = provider.isDark;
    final currency = provider.currency; // <-- GET CURRENCY
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
          Text('Max: $currency${widget.max}', style: TextStyle( // <-- UPDATED CURRENCY
            fontSize: 12, color: isDark ? AppColors.darkMuted : AppColors.muted,
          )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(currency, style: const TextStyle( // <-- UPDATED CURRENCY
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

// ── EDIT EXPENSE SHEET ─────────────────────────────────────────────
class _EditExpenseSheet extends StatefulWidget {
  final String groupId;
  final Expense expense;
  final List<String> members;
  const _EditExpenseSheet({required this.groupId, required this.expense, required this.members,});

  @override
  State<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<_EditExpenseSheet> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late String _selectedCategory;
  late String _paidBy;
  late List<String> _splitAmong;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense.name);
    _amountController = TextEditingController(text: widget.expense.amount.toString());
    _selectedCategory = widget.expense.category;
    _paidBy = widget.expense.paidBy;
    _splitAmong = List.from(widget.expense.splitAmong);
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

  void _saveExpense() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;
    
    if (name.isEmpty) { setState(() => _error = 'Enter expense name!'); return; }
    if (amount <= 0) { setState(() => _error = 'Enter a valid amount!'); return; }
    if (_splitAmong.isEmpty) { setState(() => _error = 'Select at least one member!'); return; }

    setState(() => _error = null);

    final db = DatabaseService();
    await db.updateExpense(
      widget.groupId, 
      widget.expense.id, 
      name, 
      amount, 
      _paidBy, 
      _splitAmong, 
      _selectedCategory
    );

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _openNumpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PartialNumpad(
        initial: _amountController.text,
        max: 9999999,
        onConfirm: (val) => setState(() => _amountController.text = val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;
    final currency = provider.currency; // <-- GET CURRENCY
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
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Text('Edit Expense', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 22,
              fontWeight: FontWeight.w900, color: textColor,
            )),
            const SizedBox(height: 20),

            _label('CATEGORY'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: AppConstants.expenseCategories.map((cat) {
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.orange : borderColor, width: selected ? 2 : 1.5),
                    ),
                    child: Center(child: Text(cat, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _label('DESCRIPTION'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                filled: true, fillColor: inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            _label('AMOUNT'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openNumpad,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Row(
                  children: [
                    Text(currency, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.orange)), // <-- UPDATED CURRENCY
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _amountController.text.isEmpty ? 'Enter amount' : _amountController.text,
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
                    )),
                    if (_splitAmong.isNotEmpty && (double.tryParse(_amountController.text) ?? 0) > 0)
                      Text('$currency${share.round()}/person', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkMuted : AppColors.muted)), // <-- UPDATED CURRENCY
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _label('PAID BY'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paidBy,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.darkSurface2 : Colors.white,
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: textColor, fontSize: 15),
                  items: widget.members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _paidBy = val!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _label('SPLIT AMONG'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: widget.members.map((m) {
                final selected = _splitAmong.contains(m);
                return GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); _toggleMember(m); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.orange : borderColor),
                    ),
                    child: Text(m, style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13,
                      color: selected ? AppColors.orange : textColor,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

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
                    Text(_error!, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.error)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            GestureDetector(
              onTap: _saveExpense,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Save Changes →', style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                ))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(
    fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800,
    color: AppColors.orange, letterSpacing: 0.5,
  ));
}