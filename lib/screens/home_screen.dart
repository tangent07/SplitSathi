import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/group.dart';
import '../utils/constants.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'quick_split_screen.dart';
import 'money_diary_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      drawer: const AppDrawer(),
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
          HapticFeedback.mediumImpact();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const FriendsScreen(),
          ));
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
              // Navigation Menu + Logo + Dark mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // ==========================================
                      // THE FIX IS HERE: The Builder gives us the 
                      // correct context to open the Drawer!
                      // ==========================================
                      Builder(
                        builder: (BuildContext innerContext) {
                          return GestureDetector(
                            onTap: () {
                              // Now it uses innerContext instead of context!
                              Scaffold.of(innerContext).openDrawer();
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12.0),
                              child: Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          );
                        },
                      ),
                      // ==========================================

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
                    ],
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

              const Padding(
                padding: EdgeInsets.only(left: 40.0, top: 4),
                child: Text(
                  'Split bills. Not friendships. 🤝',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
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
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const QuickSplitScreen(),
                    ));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _actionButton(
            '📊 Money Diary',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const MoneyDiaryScreen(),
              ));
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

          // Live Database Listener
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groups').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              // 1. Show a loading spinner while waiting for the internet
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20), 
                    child: CircularProgressIndicator(color: AppColors.orange)
                  )
                );
              }

              // 2. Grab the actual list of documents from the cloud
              final docs = snapshot.data?.docs ?? [];

              // 3. If the database is empty, use YOUR beautiful empty state!
              if (docs.isEmpty) {
                return _buildEmptyState(isDark);
              }

              // 4. If we have groups, build the list safely using a Column
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String name = data['name'] ?? 'Unnamed Group';
                  final String emoji = data['emoji'] ?? '👥';
                  final List members = data['members'] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48, 
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1C),
                        ),
                      ),
                      subtitle: Text(
                        '${members.length} members',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkMuted : AppColors.muted,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right, 
                        color: isDark ? AppColors.darkMuted : AppColors.muted
                      ),
                      onTap: () {
                        // We will wire this up to open the specific group next!
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
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
        _showContextMenu(context, group, isDark);
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

  void _showContextMenu(BuildContext context, Group group, bool isDark) {
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: const Border(top: BorderSide(color: AppColors.orange, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Handle
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 12),

            // Group name header
            Row(
              children: [
                Text(group.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(group.name, style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 16,
                  fontWeight: FontWeight.w900, color: AppColors.orange,
                )),
              ],
            ),
            Divider(color: borderColor, height: 20),

            // Menu items
            _ctxItem('💸', 'Add Expense', textColor, () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(groupId: group.id),
                ));
              });
            }),
            _ctxItem('⚖️', 'Balances', textColor, () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(groupId: group.id, initialTab: 1),
                ));
              });
            }),
            _ctxItem('🤝', 'Settle Up', textColor, () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(groupId: group.id, initialTab: 2),
                ));
              });
            }),
            _ctxItem('✏️', 'Edit Group', textColor, () {
              Navigator.pop(context);
              _showEditGroupSheet(context, group, isDark);
            }),

            const SizedBox(height: 8),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 8),

            _ctxItem('🗑️', 'Delete Group', AppColors.error, () {
              Navigator.pop(context);
              _confirmDeleteGroup(context, group, isDark);
            }),
          ],
        ),
        ),
      ),
    );
  }

  Widget _ctxItem(String emoji, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w700,
              fontSize: 16, color: color,
            )),
          ],
        ),
      ),
    );
  }

  void _showEditGroupSheet(BuildContext context, Group group, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGroupSheet(group: group),
    );
  }

  void _confirmDeleteGroup(BuildContext context, Group group, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${group.name}"?', style: const TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w900,
        )),
        content: const Text('This will permanently delete the group and all its expenses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteGroup(group.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
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

// ── EDIT GROUP SHEET ───────────────────────────────────────────────
class _EditGroupSheet extends StatefulWidget {
  final Group group;
  const _EditGroupSheet({required this.group});

  @override
  State<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<_EditGroupSheet> {
  late TextEditingController _nameController;
  late String _selectedEmoji;
  late List<String> _members;
  final _memberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _selectedEmoji = widget.group.emoji;
    _members = List.from(widget.group.members);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty || _members.contains(name)) return;
    setState(() => _members.add(name));
    _memberController.clear();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.group.name = name;
    widget.group.emoji = _selectedEmoji;
    widget.group.members = _members;
    context.read<AppProvider>().updateGroup(widget.group);
    Navigator.pop(context);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Text('Edit Group', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 22,
              fontWeight: FontWeight.w900, color: textColor,
            )),
            const SizedBox(height: 20),

            // Name
            _label('GROUP NAME'),
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
            const SizedBox(height: 20),

            // Emoji
            _label('PICK AN EMOJI'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: AppConstants.groupEmojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.orange.withOpacity(0.15) : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.orange : borderColor,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Members
            _label('MEMBERS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _members.map((m) {
                final isYou = m == 'You';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isYou ? AppColors.orange.withOpacity(0.15) : inputBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isYou ? AppColors.orange : borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m, style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isYou ? AppColors.orange : textColor,
                      )),
                      if (!isYou) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _members.remove(m)),
                          child: const Icon(Icons.close, size: 14, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    onSubmitted: (_) => _addMember(),
                    style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Add member...',
                      hintStyle: TextStyle(color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4)),
                      filled: true, fillColor: inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addMember,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Save Changes →', style: TextStyle(
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
    fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5,
  ));
}