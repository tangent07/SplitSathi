import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/group.dart';
import '../models/direct_payment.dart';
import '../utils/constants.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Get all friends from groups + direct payments
  List<_FriendSummary> _getAllFriends(AppProvider provider) {
    final map = <String, _FriendSummary>{};

    // From groups
    for (final g in provider.groups) {
      for (final m in g.members) {
        if (m == 'You') continue;
        if (!map.containsKey(m)) {
          map[m] = _FriendSummary(name: m, groupNames: [], net: 0, lastActivity: null);
        }
        map[m]!.groupNames.add(g.name);
        final lastExp = g.expenses.isNotEmpty ? g.expenses.last.date : null;
        if (lastExp != null) {
          if (map[m]!.lastActivity == null || lastExp.isAfter(map[m]!.lastActivity!)) {
            map[m]!.lastActivity = lastExp;
          }
        }
      }
    }

    // From direct payments
    for (final p in provider.directPayments) {
      if (!map.containsKey(p.friend)) {
        map[p.friend] = _FriendSummary(name: p.friend, groupNames: [], net: 0, lastActivity: null);
      }
      if (map[p.friend]!.lastActivity == null ||
          p.date.isAfter(map[p.friend]!.lastActivity!)) {
        map[p.friend]!.lastActivity = p.date;
      }
    }

    // Calculate net for each friend
    for (final name in map.keys) {
      map[name]!.net = _getFriendNet(name, provider);
    }

    // Sort: unsettled first, then by recent activity
    final list = map.values.toList();
    list.sort((a, b) {
      final aSettled = a.net == 0;
      final bSettled = b.net == 0;
      if (aSettled != bSettled) return aSettled ? 1 : -1;
      final aTime = a.lastActivity?.millisecondsSinceEpoch ?? 0;
      final bTime = b.lastActivity?.millisecondsSinceEpoch ?? 0;
      return bTime - aTime;
    });

    return list;
  }

  double _getFriendNet(String friendName, AppProvider provider) {
    double net = 0;

    // From groups
    for (final g in provider.groups) {
      if (!g.members.contains(friendName)) continue;
      final balances = _calcGroupBalances(g);
      for (final t in balances) {
        if (t['from'] == friendName && t['to'] == 'You') net += t['amount'] as double;
        if (t['from'] == 'You' && t['to'] == friendName) net -= t['amount'] as double;
      }
    }

    // From direct payments
    for (final p in provider.directPayments.where((p) => p.friend == friendName)) {
      if (p.youPaid) net += p.amount;
      else net -= p.amount;
    }

    return net;
  }

  List<Map<String, dynamic>> _calcGroupBalances(Group group) {
    final net = <String, double>{};
    for (final m in group.members) net[m] = 0;
    for (final exp in group.activeExpenses) {
      final share = exp.amount / exp.splitAmong.length;
      net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;
      for (final m in exp.splitAmong) net[m] = (net[m] ?? 0) - share;
    }
    final transactions = <Map<String, dynamic>>[];
    final debtors = net.entries.where((e) => e.value < -0.01).map((e) => {'name': e.key, 'amt': -e.value}).toList();
    final creditors = net.entries.where((e) => e.value > 0.01).map((e) => {'name': e.key, 'amt': e.value}).toList();
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = (debtors[i]['amt'] as double) < (creditors[j]['amt'] as double)
          ? debtors[i]['amt'] as double : creditors[j]['amt'] as double;
      if (pay > 0.01) transactions.add({'from': debtors[i]['name'], 'to': creditors[j]['name'], 'amount': pay});
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
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inputBg = isDark ? AppColors.darkSurface2 : Colors.white;

    var friends = _getAllFriends(provider);
    if (_search.isNotEmpty) {
      friends = friends.where((f) => f.name.toLowerCase().contains(_search.toLowerCase())).toList();
    }

    final unsettled = friends.where((f) => f.net != 0).toList();
    final settled = friends.where((f) => f.net == 0).toList();

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text('👥 Friends', style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 22,
                        fontWeight: FontWeight.w900, color: Colors.white,
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Nunito'),
                      decoration: const InputDecoration(
                        hintText: 'Search friends...',
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Friends list
            Expanded(
              child: friends.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('👥', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text('No friends yet', style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 18,
                            fontWeight: FontWeight.w800, color: textColor,
                          )),
                          const SizedBox(height: 8),
                          Text('Add members to a group\nor record a direct payment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkMuted : AppColors.muted,
                            )),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                      children: [
                        if (unsettled.isNotEmpty) ...[
                          ...unsettled.map((f) => _buildFriendRow(context, f, isDark, textColor, borderColor)),
                        ],
                        if (settled.isNotEmpty) ...[
                          if (unsettled.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: Divider(color: borderColor)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Settled Up', style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                                )),
                              ),
                              Expanded(child: Divider(color: borderColor)),
                            ]),
                            const SizedBox(height: 8),
                          ],
                          ...settled.map((f) => _buildFriendRow(context, f, isDark, textColor, borderColor)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),

      // FAB — Add new direct friend
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewDirectFriend(context, isDark),
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildFriendRow(BuildContext context, _FriendSummary friend,
      bool isDark, Color textColor, Color borderColor) {
    final net = friend.net;
    final color = net > 0 ? AppColors.success : net < 0 ? AppColors.error : AppColors.muted;
    final label = net > 0
        ? 'owes you ₹${net.round()}'
        : net < 0
            ? 'you owe ₹${net.abs().round()}'
            : 'settled ✓';
    final idx = friend.name.codeUnitAt(0) % AppConstants.avatarColors.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => FriendDetailScreen(friendName: friend.name),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppConstants.getAvatarColor(idx),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: Text(
                friend.name[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                  color: Colors.white, fontSize: 18,
                ),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                    fontSize: 15, color: textColor,
                  )),
                  if (friend.groupNames.isNotEmpty)
                    Text(friend.groupNames.join(', '), style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    )),
                ],
              ),
            ),
            Text(label, style: TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w900,
              fontSize: 13, color: color,
            )),
          ],
        ),
      ),
    );
  }

  void _showNewDirectFriend(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewDirectFriendSheet(),
    );
  }
}

// ── FRIEND DETAIL SCREEN ───────────────────────────────────────────
class FriendDetailScreen extends StatelessWidget {
  final String friendName;
  const FriendDetailScreen({super.key, required this.friendName});

  List<Map<String, dynamic>> _calcGroupBalances(Group group) {
    final net = <String, double>{};
    for (final m in group.members) net[m] = 0;
    for (final exp in group.activeExpenses) {
      final share = exp.amount / exp.splitAmong.length;
      net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;
      for (final m in exp.splitAmong) net[m] = (net[m] ?? 0) - share;
    }
    final transactions = <Map<String, dynamic>>[];
    final debtors = net.entries.where((e) => e.value < -0.01).map((e) => {'name': e.key, 'amt': -e.value}).toList();
    final creditors = net.entries.where((e) => e.value > 0.01).map((e) => {'name': e.key, 'amt': e.value}).toList();
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = (debtors[i]['amt'] as double) < (creditors[j]['amt'] as double)
          ? debtors[i]['amt'] as double : creditors[j]['amt'] as double;
      if (pay > 0.01) transactions.add({'from': debtors[i]['name'], 'to': creditors[j]['name'], 'amount': pay});
      debtors[i]['amt'] = (debtors[i]['amt'] as double) - pay;
      creditors[j]['amt'] = (creditors[j]['amt'] as double) - pay;
      if ((debtors[i]['amt'] as double) < 0.01) i++;
      if ((creditors[j]['amt'] as double) < 0.01) j++;
    }
    return transactions;
  }

  double _getNet(AppProvider provider) {
    double net = 0;
    for (final g in provider.groups) {
      if (!g.members.contains(friendName)) continue;
      final balances = _calcGroupBalances(g);
      for (final t in balances) {
        if (t['from'] == friendName && t['to'] == 'You') net += t['amount'] as double;
        if (t['from'] == 'You' && t['to'] == friendName) net -= t['amount'] as double;
      }
    }
    for (final p in provider.directPayments.where((p) => p.friend == friendName)) {
      if (p.youPaid) net += p.amount;
      else net -= p.amount;
    }
    return net;
  }

  List<Map<String, dynamic>> _getHistory(AppProvider provider) {
    final history = <Map<String, dynamic>>[];

    for (final g in provider.groups) {
      if (!g.members.contains(friendName)) continue;
      for (final exp in g.expenses) {
        if (exp.deleted) continue;
        if (exp.isGhost) {
          if (exp.ghostText != null) {
            history.add({
              'label': exp.ghostText!,
              'amount': exp.amount,
              'youPaid': exp.paidBy == 'You',
              'sub': g.name,
              'date': exp.date,
              'icon': exp.category == '✅' ? '✅' : '🔄',
              'isGhost': true,
            });
          }
          continue;
        }
        final splitAmong = exp.splitAmong;
        if (exp.paidBy == friendName && splitAmong.contains('You')) {
          history.add({
            'label': '$friendName paid for "${exp.name}"',
            'amount': exp.amount / splitAmong.length,
            'youPaid': false,
            'sub': g.name,
            'date': exp.date,
            'icon': '🧾',
            'isGhost': false,
          });
        }
        if (exp.paidBy == 'You' && splitAmong.contains(friendName)) {
          history.add({
            'label': 'You paid for "${exp.name}"',
            'amount': exp.amount / splitAmong.length,
            'youPaid': true,
            'sub': g.name,
            'date': exp.date,
            'icon': '💸',
            'isGhost': false,
          });
        }
      }
    }

    for (final p in provider.directPayments.where((p) => p.friend == friendName)) {
      history.add({
        'label': p.youPaid ? 'You paid $friendName' : '$friendName paid you',
        'amount': p.amount,
        'youPaid': p.youPaid,
        'sub': p.note.isNotEmpty ? p.note : 'Direct payment',
        'date': p.date,
        'icon': '💳',
        'isGhost': false,
      });
    }

    history.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return history;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final net = _getNet(provider);
    final history = _getHistory(provider);
    final idx = friendName.codeUnitAt(0) % AppConstants.avatarColors.length;

    final netColor = net > 0 ? AppColors.success : net < 0 ? AppColors.error : AppColors.muted;
    final netLabel = net > 0
        ? '$friendName owes you'
        : net < 0
            ? 'You owe $friendName'
            : 'All settled up!';
    final netBg = net > 0
        ? AppColors.success.withOpacity(0.08)
        : net < 0
            ? AppColors.error.withOpacity(0.08)
            : (isDark ? AppColors.darkSurface : Colors.white);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                          color: AppColors.orange, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700, fontSize: 14,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Friend header
                  Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: AppConstants.getAvatarColor(idx),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(child: Text(
                          friendName[0].toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                            color: Colors.white, fontSize: 26,
                          ),
                        )),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(friendName, style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 24,
                            fontWeight: FontWeight.w900, color: textColor,
                          )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Net balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: netBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: netColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(netLabel, style: TextStyle(
                          fontSize: 13, color: netColor,
                          fontWeight: FontWeight.w700,
                        )),
                        const SizedBox(height: 8),
                        Text(
                          net == 0 ? '₹0' : '₹${net.abs().round()}',
                          style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 40,
                            fontWeight: FontWeight.w900, color: netColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Record Payment button
                  GestureDetector(
                    onTap: () => _showRecordPayment(context, isDark),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(child: Text('+ Record Payment', style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 15,
                        fontWeight: FontWeight.w800, color: Colors.white,
                      ))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('PAYMENT HISTORY', style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange, letterSpacing: 0.5,
                  )),
                ],
              ),
            ),

            // History list
            Expanded(
              child: history.isEmpty
                  ? Center(child: Text('No payment history yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkMuted : AppColors.muted,
                      )))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: history.length,
                      itemBuilder: (context, i) {
                        final h = history[i];
                        final date = DateFormat('d MMM yyyy').format(h['date'] as DateTime);
                        final amountColor = (h['youPaid'] as bool)
                            ? AppColors.error : AppColors.success;
                        final amountStr = (h['youPaid'] as bool)
                            ? '-₹${(h['amount'] as double).round()}'
                            : '+₹${(h['amount'] as double).round()}';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: borderColor)),
                          ),
                          child: Row(
                            children: [
                              Text(h['icon'] as String, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h['label'] as String, style: TextStyle(
                                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                                      fontSize: 13, color: textColor,
                                    )),
                                    Text('${h['sub']} · $date', style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                                    )),
                                  ],
                                ),
                              ),
                              Text(amountStr, style: TextStyle(
                                fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                                fontSize: 15, color: amountColor,
                              )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPayment(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordPaymentSheet(friendName: friendName),
    );
  }
}

// ── RECORD PAYMENT SHEET ───────────────────────────────────────────
class _RecordPaymentSheet extends StatefulWidget {
  final String friendName;
  const _RecordPaymentSheet({required this.friendName});

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _youPaid = true;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;
    context.read<AppProvider>().addDirectPayment(
      DirectPayment.create(
        friend: widget.friendName,
        amount: amount,
        youPaid: _youPaid,
        note: _noteController.text.trim(),
      ),
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _openNumpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FriendNumpad(
        initial: _amountController.text,
        onConfirm: (val) => setState(() => _amountController.text = val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text('Record Payment', style: TextStyle(
            fontFamily: 'Nunito', fontSize: 20,
            fontWeight: FontWeight.w900, color: textColor,
          )),
          const SizedBox(height: 20),

          // Who paid toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _youPaid = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _youPaid ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _youPaid ? AppColors.orange : borderColor,
                        width: _youPaid ? 2 : 1.5,
                      ),
                    ),
                    child: Center(child: Text('💸 I paid them', style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _youPaid ? AppColors.orange : textColor,
                    ))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _youPaid = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_youPaid ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_youPaid ? AppColors.orange : borderColor,
                        width: !_youPaid ? 2 : 1.5,
                      ),
                    ),
                    child: Center(child: Text('🤲 They paid me', style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: !_youPaid ? AppColors.orange : textColor,
                    ))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount
          GestureDetector(
            onTap: _openNumpad,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: inputBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Text('₹', style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                    fontSize: 20, color: AppColors.orange,
                  )),
                  const SizedBox(width: 8),
                  Text(
                    _amountController.text.isEmpty ? 'Enter amount' : _amountController.text,
                    style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16,
                      color: _amountController.text.isEmpty
                          ? (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4)
                          : textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Note
          TextField(
            controller: _noteController,
            style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              hintStyle: TextStyle(color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4)),
              filled: true, fillColor: inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Save Payment →', style: TextStyle(
                fontFamily: 'Nunito', fontSize: 16,
                fontWeight: FontWeight.w800, color: Colors.white,
              ))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NEW DIRECT FRIEND SHEET ────────────────────────────────────────
class _NewDirectFriendSheet extends StatefulWidget {
  const _NewDirectFriendSheet();

  @override
  State<_NewDirectFriendSheet> createState() => _NewDirectFriendSheetState();
}

class _NewDirectFriendSheetState extends State<_NewDirectFriendSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _youPaid = true;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    context.read<AppProvider>().addDirectPayment(
      DirectPayment.create(
        friend: name,
        amount: amount,
        youPaid: _youPaid,
        note: _noteController.text.trim(),
      ),
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _openNumpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FriendNumpad(
        initial: _amountController.text,
        onConfirm: (val) => setState(() => _amountController.text = val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Text('Add Friend & Record Payment', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 18,
              fontWeight: FontWeight.w900, color: textColor,
            )),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: "Friend's Name",
                labelStyle: const TextStyle(color: AppColors.orange),
                filled: true, fillColor: inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _youPaid = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _youPaid ? AppColors.orange.withOpacity(0.15) : inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _youPaid ? AppColors.orange : borderColor, width: _youPaid ? 2 : 1.5),
                      ),
                      child: Center(child: Text('💸 I paid them', style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13,
                        color: _youPaid ? AppColors.orange : textColor,
                      ))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _youPaid = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_youPaid ? AppColors.orange.withOpacity(0.15) : inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: !_youPaid ? AppColors.orange : borderColor, width: !_youPaid ? 2 : 1.5),
                      ),
                      child: Center(child: Text('🤲 They paid me', style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13,
                        color: !_youPaid ? AppColors.orange : textColor,
                      ))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openNumpad,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Row(
                  children: [
                    const Text('₹', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.orange)),
                    const SizedBox(width: 8),
                    Text(
                      _amountController.text.isEmpty ? 'Enter amount' : _amountController.text,
                      style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16,
                        color: _amountController.text.isEmpty
                            ? (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4)
                            : textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                hintStyle: TextStyle(color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4)),
                filled: true, fillColor: inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Save →', style: TextStyle(
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
}

// ── FRIEND NUMPAD ──────────────────────────────────────────────────
class _FriendNumpad extends StatefulWidget {
  final String initial;
  final Function(String) onConfirm;
  const _FriendNumpad({required this.initial, required this.onConfirm});

  @override
  State<_FriendNumpad> createState() => _FriendNumpadState();
}

class _FriendNumpadState extends State<_FriendNumpad> {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('₹', style: TextStyle(fontFamily: 'Nunito', fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.orange)),
              const SizedBox(width: 4),
              Text(_value, style: TextStyle(fontFamily: 'Nunito', fontSize: 48, fontWeight: FontWeight.w900, color: textColor)),
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
              decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Done ✓', style: TextStyle(
                fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
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
          color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: color,
        ))),
      ),
    );
  }
}

class _FriendSummary {
  final String name;
  final List<String> groupNames;
  double net;
  DateTime? lastActivity;
  _FriendSummary({required this.name, required this.groupNames, required this.net, required this.lastActivity});
}