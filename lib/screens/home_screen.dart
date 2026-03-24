import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/group.dart';
import '../utils/constants.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1 — Orange Header
              _buildHeader(context, provider, isDark),

              // SECTION 2 — Buttons
              _buildButtons(context, isDark),

              // Divider
              Container(
                height: 2,
                color: AppColors.orange.withOpacity(0.25),
              ),

              // SECTION 3 — Your Groups
              _buildGroupsList(context, provider, isDark),
            ],
          ),
        ),
      ),

      // Friends FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open friends panel
        },
        backgroundColor: AppColors.orange,
        child: const Text('👥', style: TextStyle(fontSize: 22)),
      ),
    );
  }

  // ── SECTION 1: HEADER ──────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AppProvider provider, bool isDark) {
    // Calculate balances
    double totalOwe = 0;
    double totalReceive = 0;

    for (final g in provider.groups) {
      final balances = _calcBalances(g);
      for (final t in balances) {
        if (t['from'] == 'You') totalOwe += t['amount'] as double;
        if (t['to'] == 'You') totalReceive += t['amount'] as double;
      }
    }
    final net = totalReceive - totalOwe;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
      ),
      child: Stack(
        children: [
          // ₹ watermark
          Positioned(
            right: -10,
            top: -20,
            child: Text(
              '₹',
              style: TextStyle(
                fontSize: 130,
                color: Colors.white.withOpacity(0.07),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo + Dark mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Split',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'Sathi',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFCD34D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dark mode toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      provider.toggleDarkMode();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          isDark ? '☀️' : '🌙',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),
              const Text(
                'Split bills. Not friendships. 🤝',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),

              const SizedBox(height: 14),

              // Balance card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _balanceItem('YOU OWE', '₹${totalOwe.round()}', const Color(0xFFFECACA)),
                    _balanceItem('YOU GET', '₹${totalReceive.round()}', const Color(0xFFBBF7D0)),
                    _balanceItem(
                      'NET',
                      '${net >= 0 ? '+' : ''}₹${net.round()}',
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── SECTION 2: BUTTONS ─────────────────────────────────────────
  Widget _buildButtons(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.peach,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  '+ New Group',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CreateGroupSheet(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  '⚡ Quick Split',
                  onTap: () {
                    // TODO: Open quick split
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _actionButton(
            '📊 Money Diary',
            onTap: () {
              // TODO: Open money diary
            },
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ── SECTION 3: GROUPS LIST ─────────────────────────────────────
  Widget _buildGroupsList(BuildContext context, AppProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR GROUPS',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.orange,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          if (provider.groups.isEmpty)
            _buildEmptyState(isDark)
          else
            ...provider.groups.map((g) => _buildGroupRow(context, g, isDark)),
        ],
      ),
    );
  }

  Widget _buildGroupRow(BuildContext context, Group group, bool isDark) {
    // Calculate my balance in this group
    final balances = _calcBalances(group);
    double myBalance = 0;
    for (final t in balances) {
      if (t['to'] == 'You') myBalance += t['amount'] as double;
      if (t['from'] == 'You') myBalance -= t['amount'] as double;
    }

    final balanceColor = myBalance > 0
        ? AppColors.success
        : myBalance < 0
            ? AppColors.error
            : AppColors.muted;

    final balanceText = myBalance > 0
        ? '+₹${myBalance.round()}'
        : myBalance < 0
            ? '-₹${myBalance.abs().round()}'
            : '✓';

    final date = DateFormat('d MMM').format(group.lastActivity);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: group.id),
        ));
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        // TODO: Show context menu
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Emoji avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(group.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),

            const SizedBox(width: 14),

            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.members.length} members · ${group.activeExpenses.length} expenses',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // Date + balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balanceText,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: balanceColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Text('🧾', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1C1C1C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group for your trip,\ndinner, or any shared expense',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BALANCE CALCULATION ────────────────────────────────────────
  List<Map<String, dynamic>> _calcBalances(Group group) {
    final net = <String, double>{};
    for (final m in group.members) {
      net[m] = 0;
    }
    for (final exp in group.activeExpenses) {
      final share = exp.amount / exp.splitAmong.length;
      net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;
      for (final m in exp.splitAmong) {
        net[m] = (net[m] ?? 0) - share;
      }
    }

    final transactions = <Map<String, dynamic>>[];
    final debtors = net.entries.where((e) => e.value < -0.01).map((e) => {'name': e.key, 'amt': -e.value}).toList();
    final creditors = net.entries.where((e) => e.value > 0.01).map((e) => {'name': e.key, 'amt': e.value}).toList();

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
}