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
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final group = _getGroup(provider);

    if (group == null) {
      return const Scaffold(body: Center(child: Text('Group not found')));
    }

    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    // Calculate balances
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
            // Back button + group info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back
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

                  // Group header
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

                  // Balance cards
                  Row(
                    children: [
                      Expanded(child: _balanceCard('YOU OWE', '₹${myOwe.round()}',
                          AppColors.error, surfaceColor, borderColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _balanceCard('YOU GET BACK', '₹${myReceive.round()}',
                          AppColors.success, surfaceColor, borderColor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tabs
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

            // Tab content
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

      // FAB - Add expense
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddExpenseSheet(groupId: widget.groupId),
          );
        },
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
    final expenses = group.expenses.reversed.toList();
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No expenses yet', style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1C1C1C),
            )),
            const SizedBox(height: 8),
            Text('Tap + to add the first expense',
              style: TextStyle(
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

        // Ghost row for deleted or settlement
        if (exp.deleted || exp.isGhost) {
          final icon = exp.isGhost
              ? (exp.category == '✅' ? '✅' : '🔄')
              : '🚫';
          final msg = exp.isGhost
              ? (exp.ghostText ?? '')
              : 'You deleted · ₹${exp.amount.round()} · ${exp.name}';
          final time = DateFormat('hh:mm a').format(exp.deleted
              ? (exp.deletedAt ?? exp.date)
              : exp.date);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(msg,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    )),
                ),
                Text(time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkMuted : AppColors.muted,
                  )),
              ],
            ),
          );
        }

        final share = exp.amount / exp.splitAmong.length;
        final date = DateFormat('d MMM yyyy').format(exp.date);
        final time = DateFormat('hh:mm a').format(exp.date);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(exp.category, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exp.name, style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                    )),
                    Text('Paid by ${exp.paidBy} · ${exp.splitAmong.length} people',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                      )),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${exp.amount.round()}',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.orange,
                    )),
                  Text('₹${share.round()}/person',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    )),
                  Text(date,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    )),
                ],
              ),
            ],
          ),
        );
      },
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
    // Calculate net per member
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
        final label = bal > 0
            ? 'gets back ₹$bal'
            : bal < 0
                ? 'owes ₹${bal.abs()}'
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
class _SettleUpTab extends StatelessWidget {
  final Group group;
  final List<Map<String, dynamic>> balances;
  final bool isDark;
  const _SettleUpTab({required this.group, required this.balances, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('All Settled!', style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1C1C1C),
            )),
            const SizedBox(height: 8),
            Text('No pending dues in this group',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              )),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: balances.length,
      itemBuilder: (context, i) {
        final t = balances[i];
        final fromIdx = group.members.indexOf(t['from'] as String);
        final toIdx = group.members.indexOf(t['to'] as String);
        final amount = (t['amount'] as double).round();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // From avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.getAvatarColor(fromIdx),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text((t['from'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    )),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: AppColors.orange, size: 18),
              const SizedBox(width: 8),

              // To avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.getAvatarColor(toIdx),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text((t['to'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    )),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t['from']} → ${t['to']}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                      )),
                    Text('₹$amount',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppColors.orange,
                      )),
                  ],
                ),
              ),

              // Settle buttons
              Column(
                children: [
                  _settleBtn('Full ✓', AppColors.success, () {
                    // TODO: Mark settled
                  }),
                  const SizedBox(height: 6),
                  _settleBtn('Partial', AppColors.orange, () {
                    // TODO: Partial settle
                  }),
                ],
              ),
            ],
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
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: color,
        )),
      ),
    );
  }
}