import 'add_friend_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../models/group.dart';

DateTime _parseDate(dynamic val) {
  if (val == null) return DateTime.now();
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
  return DateTime.now();
}

class FriendData {
  final String name;
  final List<String> sharedGroups;
  double netBalance; 
  DateTime lastActivity;

  FriendData({
    required this.name,
    required this.sharedGroups,
    required this.netBalance,
    required this.lastActivity,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// 1. FLOATING FRIENDS PANEL
// ════════════════════════════════════════════════════════════════════════════
class FriendsPanel extends StatefulWidget {
  const FriendsPanel({super.key});
  @override
  State<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<FriendsPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  List<Map<String, dynamic>> _calcBalances(Group group) {
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
      final pay = (debtors[i]['amt'] as double) < (creditors[j]['amt'] as double) ? debtors[i]['amt'] as double : creditors[j]['amt'] as double;
      if (pay > 0.01) transactions.add({'from': debtors[i]['name'], 'to': creditors[j]['name'], 'amount': pay});
      debtors[i]['amt'] = (debtors[i]['amt'] as double) - pay; creditors[j]['amt'] = (creditors[j]['amt'] as double) - pay;
      if ((debtors[i]['amt'] as double) < 0.01) i++; if ((creditors[j]['amt'] as double) < 0.01) j++;
    }
    return transactions;
  }

  Future<List<FriendData>> _fetchLiveFriends(List<QueryDocumentSnapshot> directDocs) async {
    Map<String, FriendData> friendMap = {};
    final myUid = AuthService().currentUser?.uid ?? '';

    // 1. FETCH FROM GROUPS
    final groupQuery = await FirebaseFirestore.instance.collection('groups').where('members', arrayContains: 'You').get();
    for (var gDoc in groupQuery.docs) {
      final gData = gDoc.data();
      final groupName = gData['name'] ?? 'Unnamed';
      final members = List<String>.from(gData['members'] ?? []);
      final createdAt = _parseDate(gData['createdAt']);

      for (var m in members) {
        if (m != 'You') {
          if (!friendMap.containsKey(m)) friendMap[m] = FriendData(name: m, sharedGroups: [], netBalance: 0, lastActivity: createdAt);
          if (!friendMap[m]!.sharedGroups.contains(groupName)) friendMap[m]!.sharedGroups.add(groupName);
        }
      }

      final expQuery = await FirebaseFirestore.instance.collection('groups').doc(gDoc.id).collection('expenses').get();
      final net = <String, double>{};
      for (final m in members) net[m] = 0;

      for (var expDoc in expQuery.docs) {
        final exp = expDoc.data();
        if (exp['deleted'] == true || exp['isGhost'] == true) continue;
        final amount = (exp['amount'] as num).toDouble();
        final splitAmong = List<String>.from(exp['splitAmong'] ?? []);
        final paidBy = exp['paidBy'] as String;
        final share = amount / splitAmong.length;
        net[paidBy] = (net[paidBy] ?? 0) + amount;
        for (final m in splitAmong) net[m] = (net[m] ?? 0) - share;
      }

      final debtors = net.entries.where((e) => e.value < -0.01).map((e) => {'name': e.key, 'amt': -e.value}).toList();
      final creditors = net.entries.where((e) => e.value > 0.01).map((e) => {'name': e.key, 'amt': e.value}).toList();
      int i = 0, j = 0;
      while (i < debtors.length && j < creditors.length) {
        final pay = (debtors[i]['amt'] as double) < (creditors[j]['amt'] as double) ? debtors[i]['amt'] as double : creditors[j]['amt'] as double;
        if (pay > 0.01) {
          final from = debtors[i]['name'] as String;
          final to = creditors[j]['name'] as String;
          if (from == 'You' && friendMap.containsKey(to)) friendMap[to]!.netBalance -= pay;
          else if (to == 'You' && friendMap.containsKey(from)) friendMap[from]!.netBalance += pay;
        }
        debtors[i]['amt'] = (debtors[i]['amt'] as double) - pay; creditors[j]['amt'] = (creditors[j]['amt'] as double) - pay;
        if ((debtors[i]['amt'] as double) < 0.01) i++; if ((creditors[j]['amt'] as double) < 0.01) j++;
      }
    }

    // 2. FETCH FROM DIRECT PAYMENTS
    for (var doc in directDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final fName = data['friendName'] as String;
      final date = _parseDate(data['date']);

      if (!friendMap.containsKey(fName)) friendMap[fName] = FriendData(name: fName, sharedGroups: [], netBalance: 0, lastActivity: date);
      if (date.isAfter(friendMap[fName]!.lastActivity)) friendMap[fName]!.lastActivity = date;

      double amt = (data['amount'] as num).toDouble();
      if (data['youPaid'] == true) friendMap[fName]!.netBalance += amt;
      else friendMap[fName]!.netBalance -= amt;
    }

    // 🌐 3. NEW: FETCH FROM YOUR GLOBAL NETWORK (CONNECTIONS)
    if (myUid.isNotEmpty) {
      final connectionsQuery = await FirebaseFirestore.instance.collection('users').doc(myUid).collection('connections').get();
      for (var doc in connectionsQuery.docs) {
        final cData = doc.data();
        final cName = cData['name'] as String;
        // If they aren't already in the list from groups or payments, add them now!
        if (!friendMap.containsKey(cName)) {
          friendMap[cName] = FriendData(
            name: cName, 
            sharedGroups: [], 
            netBalance: 0, 
            lastActivity: _parseDate(cData['addedAt']) // Sort them by when you added them
          );
        }
      }
    }

    return friendMap.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark; final currency = context.watch<AppProvider>().currency; final surface = isDark ? AppColors.darkSurface : Colors.white; final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C); final borderColor = isDark ? AppColors.darkBorder : AppColors.border; final myUid = AuthService().currentUser?.uid ?? '';

    return Container(
      width: 320, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 10))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('👥 Your Network', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: textColor)), GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: isDark ? AppColors.darkSurface2 : AppColors.peach, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, size: 16, color: AppColors.muted)))]),
                const SizedBox(height: 12),
                TextField(controller: _searchController, onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()), style: TextStyle(color: textColor, fontFamily: 'Nunito', fontSize: 14), decoration: InputDecoration(hintText: 'Search friends in your network...', hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted), filled: true, fillColor: isDark ? AppColors.darkSurface2 : Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)))),
              ],
            ),
          ),
          Flexible(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('direct_payments').where('userId', isEqualTo: myUid).snapshots(),
              builder: (context, directSnapshot) {
                return FutureBuilder<List<FriendData>>(
                  future: _fetchLiveFriends(directSnapshot.data?.docs ?? []),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.orange));
                    List<FriendData> allFriends = snapshot.data ?? [];
                    if (_searchQuery.isNotEmpty) allFriends = allFriends.where((f) => f.name.toLowerCase().contains(_searchQuery)).toList();
                    if (allFriends.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No friends found', style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted, fontSize: 13)));

                    allFriends.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
                    final unsettled = allFriends.where((f) => f.netBalance.abs() > 0.01).toList();
                    final settled = allFriends.where((f) => f.netBalance.abs() <= 0.01).toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), shrinkWrap: true,
                      children: [
                        if (unsettled.isNotEmpty) ...unsettled.map((f) => _buildFriendRow(f, currency, isDark, textColor)),
                        if (unsettled.isNotEmpty && settled.isNotEmpty) ...[Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: borderColor, height: 1)), Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text('SETTLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: isDark ? AppColors.darkMuted : AppColors.muted)))],
                        if (settled.isNotEmpty) ...settled.map((f) => _buildFriendRow(f, currency, isDark, textColor)),
                      ],
                    );
                  }
                );
              },
            ),
          ),

          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Ensures the column only takes up the space it needs
              children: [
                // --- NEW: Find Friends Button ---
                GestureDetector(
                  onTap: () { 
                    Navigator.pop(context); 
                    showModalBottomSheet(
                      context: context, 
                      isScrollControlled: true, 
                      backgroundColor: Colors.transparent, 
                      builder: (_) => const AddFriendSheet() // Make sure to import this at the top!
                    ); 
                  },
                  child: Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.symmetric(vertical: 14), 
                    decoration: BoxDecoration(
                      color: Colors.transparent, 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: AppColors.orange, width: 1.5) // A nice orange outline
                    ), 
                    child: const Center(
                      child: Text('👤 Add friend to your network', 
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.orange)
                      )
                    )
                  ),
                ),
                
                const SizedBox(height: 12), // Spacing between the two buttons
                
                // --- EXISTING: Your original Record Payment Button ---
                GestureDetector(
                  onTap: () { Navigator.pop(context); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _NewDirectPaymentSheet()); },
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('+ Record New Payment', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)))),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFriendRow(FriendData friend, String currency, bool isDark, Color textColor) {
    String balanceText = 'settled ✓'; Color balanceColor = isDark ? AppColors.darkMuted : AppColors.muted;
    if (friend.netBalance > 0.01) { balanceText = 'owes you $currency${friend.netBalance.round()}'; balanceColor = AppColors.success; } 
    else if (friend.netBalance < -0.01) { balanceText = 'you owe $currency${friend.netBalance.abs().round()}'; balanceColor = AppColors.error; }

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => FriendDetailScreen(friend: friend))); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: AppConstants.getAvatarColor(friend.name.length), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(friend.name[0].toUpperCase(), style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(friend.name, style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: textColor)), Text(friend.sharedGroups.isNotEmpty ? friend.sharedGroups.join(', ') : 'Direct', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkMuted : AppColors.muted))])),
            Text(balanceText, style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13, color: balanceColor)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. FRIEND DETAIL SCREEN (Matches the HTML Mockup Perfectly)
// ════════════════════════════════════════════════════════════════════════════
class FriendDetailScreen extends StatefulWidget {
  final FriendData friend;
  const FriendDetailScreen({super.key, required this.friend});
  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {

  Future<List<Map<String, dynamic>>> _fetchHistory(List<QueryDocumentSnapshot> directDocs) async {
    List<Map<String, dynamic>> history = [];
    final groupQuery = await FirebaseFirestore.instance.collection('groups').where('members', arrayContains: 'You').get();
    
    for (var gDoc in groupQuery.docs) {
      final gData = gDoc.data();
      final members = List<String>.from(gData['members'] ?? []);
      if (!members.contains(widget.friend.name)) continue;

      final groupName = gData['name'] ?? 'Unnamed';
      final expQuery = await FirebaseFirestore.instance.collection('groups').doc(gDoc.id).collection('expenses').get();
      
      for (var expDoc in expQuery.docs) {
        final exp = expDoc.data();
        if (exp['deleted'] == true) continue;
        
        final amount = (exp['amount'] as num).toDouble();
        final splitAmong = List<String>.from(exp['splitAmong'] ?? []);
        final paidBy = exp['paidBy'] as String;
        final isGhost = exp['isGhost'] == true;
        final ghostText = exp['ghostText']?.toString();
        final date = _parseDate(exp['date']); 

        if (isGhost && ghostText != null && (ghostText.contains('You') || ghostText.contains(widget.friend.name))) {
          history.add({'date': date, 'icon': '🤝', 'title': ghostText, 'subtitle': groupName, 'amount': amount, 'isPositive': paidBy == 'You'});
          continue;
        }

        if (paidBy == widget.friend.name && splitAmong.contains('You')) {
          history.add({'date': date, 'icon': '🧾', 'title': '${widget.friend.name} paid for "${exp['name']}"', 'subtitle': groupName, 'amount': amount / splitAmong.length, 'isPositive': false});
        } else if (paidBy == 'You' && splitAmong.contains(widget.friend.name)) {
          history.add({'date': date, 'icon': '💸', 'title': 'You paid for "${exp['name']}"', 'subtitle': groupName, 'amount': amount / splitAmong.length, 'isPositive': true});
        }
      }
    }

    for (var doc in directDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['friendName'] == widget.friend.name) {
        bool youPaid = d['youPaid'] == true;
        history.add({'date': _parseDate(d['date']), 'icon': youPaid ? '💸' : '🤲', 'title': youPaid ? 'You paid ${widget.friend.name}' : '${widget.friend.name} paid you', 'subtitle': (d['note'] == null || d['note'].toString().isEmpty) ? 'Direct Payment' : d['note'], 'amount': (d['amount'] as num).toDouble(), 'isPositive': youPaid});
      }
    }

    history.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return history;
  }

  void _shareWhatsApp(String currency, BuildContext context) async {
    String msg = '';
    if (widget.friend.netBalance > 0.01) msg = 'Hey ${widget.friend.name}! Just a quick reminder about our SplitSathi balance. You owe me *$currency${widget.friend.netBalance.round()}*. 🤝';
    else if (widget.friend.netBalance < -0.01) msg = 'Hey ${widget.friend.name}! Just checking in on our SplitSathi balance. I owe you *$currency${widget.friend.netBalance.abs().round()}*, will send it over soon! 🤝';
    else msg = 'Hey ${widget.friend.name}! Looks like we are all settled up on SplitSathi! 🤝';

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    else if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final currency = context.watch<AppProvider>().currency;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final myUid = AuthService().currentUser?.uid ?? '';

    // Matches the delicate card styling in your HTML
    Color cardBg = surface; Color cardBorder = borderColor; Color cardText = isDark ? AppColors.darkMuted : AppColors.muted;
    String cardTitle = 'All settled up!'; String cardAmount = '$currency 0';

    if (widget.friend.netBalance > 0.01) { 
      cardBg = AppColors.success.withOpacity(0.06); // Lighter background
      cardBorder = AppColors.success.withOpacity(0.2); // Thinner border visual
      cardText = AppColors.success; 
      cardTitle = '${widget.friend.name} owes you'; 
      cardAmount = '$currency${widget.friend.netBalance.round()}'; 
    } 
    else if (widget.friend.netBalance < -0.01) { 
      cardBg = AppColors.error.withOpacity(0.06); 
      cardBorder = AppColors.error.withOpacity(0.2); 
      cardText = AppColors.error; 
      cardTitle = 'You owe ${widget.friend.name}'; 
      cardAmount = '$currency${widget.friend.netBalance.abs().round()}'; 
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg, foregroundColor: AppColors.orange, elevation: 0, leadingWidth: 100,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Row(children: [SizedBox(width: 16), Icon(Icons.arrow_back, size: 18), SizedBox(width: 4), Text('Back', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15))])),
        actions: [
          IconButton(icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 26), onPressed: () => _shareWhatsApp(currency, context)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(widget.friend.name[0].toUpperCase(), style: const TextStyle(fontFamily: 'Nunito', fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)))),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.friend.name, style: TextStyle(fontFamily: 'Nunito', fontSize: 28, fontWeight: FontWeight.w900, color: textColor)), Text(widget.friend.sharedGroups.isNotEmpty ? 'In: ${widget.friend.sharedGroups.join(', ')}' : 'Direct contact', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkMuted : AppColors.muted))])),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder, width: 1.5)),
                    child: Column(children: [Text(cardTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cardText)), const SizedBox(height: 8), Text(cardAmount, style: TextStyle(fontFamily: 'Nunito', fontSize: 44, fontWeight: FontWeight.w900, color: cardText, height: 1))]),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _DirectPaymentSheet(friendName: widget.friend.name)).then((_) => setState((){})); },
                    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('+ Record Payment', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)))),
                  ),
                  const SizedBox(height: 32),
                  Text('PAYMENT HISTORY', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('direct_payments').where('userId', isEqualTo: myUid).snapshots(),
                builder: (context, directSnapshot) {
                  return FutureBuilder<List<Map<String,dynamic>>>(
                    future: _fetchHistory(directSnapshot.data?.docs ?? []),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
                      final history = snapshot.data!;
                      if (history.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('💸', style: TextStyle(fontSize: 40)), const SizedBox(height: 12), Text('No history yet', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: textColor))]));

                      // --- THE TRUE PIXEL-PERFECT CHAT STYLE ---
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40), 
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final isPos = item['isPositive'] as bool;
                          final dateStr = DateFormat('d MMM yyyy').format(item['date'] as DateTime);
                          
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                child: Row(
                                  children: [
                                    // Notice: The container/circle background is GONE. Just the floating emoji!
                                    SizedBox(
                                      width: 36, 
                                      child: Center(child: Text(item['icon'], style: const TextStyle(fontSize: 22)))
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start, 
                                        children: [
                                          Text(item['title'], style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15, color: textColor)), 
                                          const SizedBox(height: 3), 
                                          // Notice: Beautiful dark orange text exactly like your mockup
                                          Text('${item['subtitle']} · $dateStr', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600))
                                        ]
                                      )
                                    ),
                                    Text('${isPos ? '+' : '-'} $currency${(item['amount'] as double).round()}', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 16, color: isPos ? AppColors.success : AppColors.error)),
                                  ],
                                ),
                              ),
                              if (index < history.length - 1) Divider(height: 1, thickness: 1, color: borderColor.withOpacity(0.5), indent: 70, endIndent: 20),
                            ],
                          );
                        },
                      );
                    }
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 3. EXISTING FRIEND DIRECT PAYMENT SHEET
// ════════════════════════════════════════════════════════════════════════════
class _DirectPaymentSheet extends StatefulWidget {
  final String friendName;
  const _DirectPaymentSheet({required this.friendName});
  @override
  State<_DirectPaymentSheet> createState() => _DirectPaymentSheetState();
}

class _DirectPaymentSheetState extends State<_DirectPaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _youPaid = true;
  @override
  void dispose() { _amountController.dispose(); _noteController.dispose(); super.dispose(); }
  void _save() async {
    final amt = double.tryParse(_amountController.text) ?? 0;
    if (amt <= 0) return;
    final myUid = AuthService().currentUser?.uid;
    if (myUid == null) return;
    await FirebaseFirestore.instance.collection('direct_payments').add({'userId': myUid, 'friendName': widget.friendName, 'youPaid': _youPaid, 'amount': amt, 'note': _noteController.text.trim(), 'date': DateTime.now().toIso8601String()});
    if (mounted) { HapticFeedback.mediumImpact(); Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark; final currency = context.watch<AppProvider>().currency; final bg = isDark ? AppColors.darkSurface : Colors.white; final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C); final borderColor = isDark ? AppColors.darkBorder : AppColors.border; final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 16), Text('Record Payment', style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w900, color: textColor)), const SizedBox(height: 24), Text('WHO PAID?', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            Row(children: [Expanded(child: GestureDetector(onTap: () => setState(() => _youPaid = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: _youPaid ? AppColors.orange.withOpacity(0.15) : inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _youPaid ? AppColors.orange : borderColor, width: 1.5)), child: Center(child: Text('💸 I paid them', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: _youPaid ? AppColors.orange : (isDark ? AppColors.darkMuted : AppColors.muted))))))), const SizedBox(width: 12), Expanded(child: GestureDetector(onTap: () => setState(() => _youPaid = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: !_youPaid ? AppColors.orange.withOpacity(0.15) : inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: !_youPaid ? AppColors.orange : borderColor, width: 1.5)), child: Center(child: Text('🤲 They paid me', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: !_youPaid ? AppColors.orange : (isDark ? AppColors.darkMuted : AppColors.muted)))))))]),
            const SizedBox(height: 20), Text('AMOUNT', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 18), decoration: InputDecoration(prefixIcon: Padding(padding: const EdgeInsets.all(14), child: Text(currency, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.orange))), hintText: '0', hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted), filled: true, fillColor: inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)))), const SizedBox(height: 20), Text('NOTE (OPTIONAL)', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            TextField(controller: _noteController, style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: 'e.g. Borrowed for lunch...', hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted), filled: true, fillColor: inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)))), const SizedBox(height: 24),
            GestureDetector(onTap: _save, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('Save Payment →', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))))),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 4. NEW DIRECT FRIEND PAYMENT SHEET
// ════════════════════════════════════════════════════════════════════════════
class _NewDirectPaymentSheet extends StatefulWidget {
  const _NewDirectPaymentSheet();
  @override
  State<_NewDirectPaymentSheet> createState() => _NewDirectPaymentSheetState();
}

class _NewDirectPaymentSheetState extends State<_NewDirectPaymentSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _youPaid = true;
  @override
  void dispose() { _nameController.dispose(); _amountController.dispose(); _noteController.dispose(); super.dispose(); }
  void _save() async {
    final name = _nameController.text.trim(); final amt = double.tryParse(_amountController.text) ?? 0;
    if (name.isEmpty || amt <= 0) return;
    final myUid = AuthService().currentUser?.uid; if (myUid == null) return;
    await FirebaseFirestore.instance.collection('direct_payments').add({'userId': myUid, 'friendName': name, 'youPaid': _youPaid, 'amount': amt, 'note': _noteController.text.trim(), 'date': DateTime.now().toIso8601String()});
    if (mounted) { HapticFeedback.mediumImpact(); Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark; final currency = context.watch<AppProvider>().currency; final bg = isDark ? AppColors.darkSurface : Colors.white; final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C); final borderColor = isDark ? AppColors.darkBorder : AppColors.border; final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 16), Text('New Payment', style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w900, color: textColor)), const SizedBox(height: 24), Text('FRIEND\'S NAME', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            TextField(controller: _nameController, style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: 'Enter name...', hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted), filled: true, fillColor: inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)))), const SizedBox(height: 20), Text('WHO PAID?', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            Row(children: [Expanded(child: GestureDetector(onTap: () => setState(() => _youPaid = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: _youPaid ? AppColors.orange.withOpacity(0.15) : inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _youPaid ? AppColors.orange : borderColor, width: 1.5)), child: Center(child: Text('💸 I paid them', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: _youPaid ? AppColors.orange : (isDark ? AppColors.darkMuted : AppColors.muted))))))), const SizedBox(width: 12), Expanded(child: GestureDetector(onTap: () => setState(() => _youPaid = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: !_youPaid ? AppColors.orange.withOpacity(0.15) : inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: !_youPaid ? AppColors.orange : borderColor, width: 1.5)), child: Center(child: Text('🤲 They paid me', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: !_youPaid ? AppColors.orange : (isDark ? AppColors.darkMuted : AppColors.muted)))))))]),
            const SizedBox(height: 20), Text('AMOUNT', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 18), decoration: InputDecoration(prefixIcon: Padding(padding: const EdgeInsets.all(14), child: Text(currency, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.orange))), hintText: '0', hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted), filled: true, fillColor: inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)))), const SizedBox(height: 20), Text('NOTE (OPTIONAL)', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)), const SizedBox(height: 8),
            TextField(controller: _noteController, style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: 'e.g. Borrowed for lunch...', hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted), filled: true, fillColor: inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)))), const SizedBox(height: 24),
            GestureDetector(onTap: _save, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('Save Payment →', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))))),
          ],
        ),
      ),
    );
  }
}