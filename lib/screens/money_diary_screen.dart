import 'dart:io'; // Needed for File operations
import 'package:path_provider/path_provider.dart'; // Needed for temporary directory
import 'package:share_plus/share_plus.dart'; // Needed to share the file
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/diary_entry.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';

class MoneyDiaryScreen extends StatefulWidget {
  const MoneyDiaryScreen({super.key});
  @override
  State<MoneyDiaryScreen> createState() => _MoneyDiaryScreenState();
}

class _MoneyDiaryScreenState extends State<MoneyDiaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String myUid = AuthService().currentUser?.uid ?? '';

  // STATE: Track the currently selected dates for dynamic Hero Card
  late DateTime _selectedDailyDate;
  late DateTime _selectedPastMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen to tab changes to rebuild the Hero Card dynamically
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

    _selectedDailyDate = DateTime.now();
    _selectedPastMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    
    DatabaseService().setupDefaultCategories(myUid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateDailyDate(int days) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDailyDate = _selectedDailyDate.add(Duration(days: days));
    });
  }

  void _updatePastMonth(int months) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPastMonth = DateTime(_selectedPastMonth.year, _selectedPastMonth.month + months, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;

    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseService().getPrivateCategoriesStream(myUid),
      builder: (context, catSnapshot) {
        final categories = (catSnapshot.data?.docs ?? []).map((doc) => 
          {'id': doc.id, 'name': doc['name'], 'icon': doc['icon']}).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: DatabaseService().getPrivateDiaryStream(myUid),
          builder: (context, entrySnapshot) {
            final allEntries = (entrySnapshot.data?.docs ?? []).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DiaryEntry(
                id: doc.id, 
                userId: data['userId'] ?? '',
                amount: (data['amount'] as num).toDouble(),
                note: data['name'] ?? '', catId: data['category'] ?? 'Other',
                date: (data['date'] as Timestamp).toDate(),
                deleted: data['deleted'] ?? false,
              );
            }).toList();

            final activeEntries = allEntries.where((e) => !e.deleted).toList();

            // --- DYNAMIC HERO CARD LOGIC ---
            List<DiaryEntry> heroEntries = [];
            double heroTotal = 0.0;
            String heroTitle = "TOTAL SPENT";

            if (_tabController.index == 0) {
              final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDailyDate);
              heroEntries = activeEntries.where((e) => DateFormat('yyyy-MM-dd').format(e.date) == dateStr).toList();
              final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;
              heroTitle = isToday ? "TOTAL SPENT (TODAY)" : "TOTAL SPENT (${DateFormat('d MMM').format(_selectedDailyDate).toUpperCase()})";
            } 
            else if (_tabController.index == 1) {
              final monthStr = DateFormat('yyyy-MM').format(DateTime.now());
              heroEntries = activeEntries.where((e) => DateFormat('yyyy-MM').format(e.date) == monthStr).toList();
              heroTitle = "TOTAL SPENT (THIS MONTH)";
            } 
            else if (_tabController.index == 2) {
              final monthStr = DateFormat('yyyy-MM').format(_selectedPastMonth);
              heroEntries = activeEntries.where((e) => DateFormat('yyyy-MM').format(e.date) == monthStr).toList();
              heroTitle = "TOTAL SPENT (${DateFormat('MMMM').format(_selectedPastMonth).toUpperCase()})";
            }
            
            heroTotal = heroEntries.fold(0.0, (sum, e) => sum + e.amount);

            return Scaffold(
              backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showCategorySelector(context, categories, isDark),
                backgroundColor: AppColors.orange,
                elevation: 4,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Log Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, isDark, heroTotal, heroEntries, categories, heroTitle),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _TodayTab(
                            categories: categories, entries: allEntries, isDark: isDark, myUid: myUid, 
                            selectedDate: _selectedDailyDate, onDateChanged: _updateDailyDate
                          ),
                          _HistoryTab(entries: allEntries, isDark: isDark),
                          _PastMonthsTab(
                            entries: allEntries, categories: categories, isDark: isDark, myUid: myUid,
                            selectedMonth: _selectedPastMonth, onMonthChanged: _updatePastMonth
                          ), 
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, double total, List<DiaryEntry> entries, List<Map<String, dynamic>> cats, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.orange, size: 20), onPressed: () => Navigator.pop(context)),
              const Text('Money Diary', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.orange)),
              IconButton(icon: const Icon(Icons.grid_view_rounded, color: AppColors.orange, size: 22), onPressed: () => _manageCategories(context)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity, height: 175, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.orange, Color(0xFFFB923C)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('₹${total.round()}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: SizedBox(
                      width: 110, height: 110, 
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('${_tabController.index}_$total'),
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return CustomPaint(painter: _MiniPiePainter(entries: entries, categories: cats, animationValue: value));
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.orange,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [Tab(text: 'Today'), Tab(text: 'Logs'), Tab(text: 'Past')], 
          ),
        ],
      ),
    );
  }

  void _manageCategories(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _ManageCategoriesSheet(myUid: myUid));
  }

  void _showCategorySelector(BuildContext context, List<Map<String, dynamic>> categories, bool isDark) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _CategorySelectorSheet(categories: categories, isDark: isDark),
    );
  }
}

class _TodayTab extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final List<DiaryEntry> entries;
  final bool isDark;
  final String myUid;
  final DateTime selectedDate;
  final Function(int) onDateChanged;

  const _TodayTab({
    required this.categories, required this.entries, required this.isDark, 
    required this.myUid, required this.selectedDate, required this.onDateChanged
  });

  static Color staticCategoryColor(int index) => _categoryColor(index);

  static Color _categoryColor(int index) {
    const int total = 24;
    final double rawHue = (index * (360 / total)) % 360;
    double hue = rawHue;
    if (hue >= 20 && hue <= 50) hue = (hue + 40) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.65, 0.50).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final activeOnDate = entries.where((e) => !e.deleted && DateFormat('yyyy-MM-dd').format(e.date) == dateStr).toList();

    final liveCatNames = categories.map((c) => c['name']).toSet();
    final displayCategories = List<Map<String, dynamic>>.from(categories);
    
    // Orphan categories are not shown — deleting a category removes all its data

    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

    // Calculate max spend across categories for relative progress bar
    final categorySpends = { for (var cat in displayCategories) cat['name']: activeOnDate.where((e) => e.catId == cat['name']).fold(0.0, (s, e) => s + e.amount) };
    final maxSpend = categorySpends.values.fold(0.0, (a, b) => a > b ? a : b);
    displayCategories.sort((a, b) => (categorySpends[b['name']] ?? 0.0).compareTo(categorySpends[a['name']] ?? 0.0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        // Date navigation row — unchanged
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('DAILY BREAKDOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onDateChanged(-1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_left, color: AppColors.orange, size: 20)),
                ),
                Text(
                  isToday ? 'Today' : DateFormat('dd MMM').format(selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.orange),
                ),
                GestureDetector(
                  onTap: () => onDateChanged(1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_right, color: AppColors.orange, size: 20)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2-column card grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: displayCategories.length + 1, // +1 for the Add card
          itemBuilder: (context, index) {
            // Last card = Add Category
            if (index == displayCategories.length) {
              return GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ManageCategoriesSheet(myUid: myUid),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: AppColors.orange, size: 18),
                      ),
                      const SizedBox(height: 8),
                      Text('Add category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black38)),
                    ],
                  ),
                ),
              );
            }

            final cat = displayCategories[index];
            final spent = categorySpends[cat['name']] ?? 0.0;
            final entryCount = activeOnDate.where((e) => e.catId == cat['name']).length;



            final color = _TodayTab._categoryColor(index);
            final progressValue = maxSpend > 0 ? (spent / maxSpend).clamp(0.0, 1.0) : 0.0;

            return GestureDetector(
              onTap: () => _showCategoryHistory(context, cat, entries, isDark, myUid),
              child: _buildCategoryCard(cat, spent, entryCount, color, progressValue, isDark),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat, double spent, int entryCount, Color color, double progress, bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final mutedColor = isDark ? Colors.white38 : Colors.black38;
    final trackColor = color.withOpacity(0.15);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        // Subtle shadow for depth
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          // Left color accent bar
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji icon
                Text(cat['icon'] ?? '📦', style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                // Category name
                Text(cat['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                // Entry count
                Text('$entryCount ${entryCount == 1 ? "entry" : "entries"}', style: TextStyle(fontSize: 11, color: mutedColor)),
                const Spacer(),
                // Amount
                TweenAnimationBuilder<double>(
                  key: ValueKey('${cat['name']}_$spent'),
                  tween: Tween<double>(begin: 0, end: spent),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '₹${value.round()}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: spent > 0 ? color : mutedColor),
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar (relative to highest category)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${cat['name']}_progress_$progress'),
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: trackColor,
                      color: color,
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryHistory(BuildContext context, Map<String, dynamic> cat, List<DiaryEntry> all, bool isDark, String uid) {
    final catHistory = all.where((e) => e.catId == cat['name'] && !e.deleted).toList();
    showModalBottomSheet(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _CategoryHistorySheet(catName: cat['name'], catIcon: cat['icon'], entries: catHistory, isDark: isDark, myUid: uid),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<DiaryEntry> entries;
  final bool isDark;
  const _HistoryTab({required this.entries, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final currentMonthEntries = entries.where((e) => DateFormat('yyyy-MM').format(e.date) == currentMonthStr).toList();
    
    if (currentMonthEntries.isEmpty) return const Center(child: Text("No history for this month."));
    final sorted = List<DiaryEntry>.from(currentMonthEntries)..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.black12),
      itemBuilder: (context, i) {
        final e = sorted[i];
        if (e.deleted) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.block, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text('${e.note} • ${e.catId}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                const Spacer(),
                Text('₹${e.amount.round()}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
              ],
            ),
          );
        }
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_long, color: AppColors.orange, size: 18),
          ),
          title: Text(e.note, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          subtitle: Text('${e.catId} • ${DateFormat('d MMM, hh:mm a').format(e.date)}', style: const TextStyle(fontSize: 11)),
          trailing: Text('₹${e.amount.round()}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.orange, fontSize: 15)),
        );
      },
    );
  }
}

class _PastMonthsTab extends StatelessWidget {
  final List<DiaryEntry> entries;
  final List<Map<String, dynamic>> categories; 
  final bool isDark;
  final String myUid;
  final DateTime selectedMonth;
  final Function(int) onMonthChanged;

  const _PastMonthsTab({
    required this.entries, required this.categories, required this.isDark, 
    required this.myUid, required this.selectedMonth, required this.onMonthChanged
  });

  // --- NEW: THE EXPORT TO EXCEL (CSV) LOGIC ---
  Future<void> _exportMonthToCSV(BuildContext context, String monthKey, List<DiaryEntry> monthEntries) async {
    HapticFeedback.mediumImpact();
    
    try {
      // 1. Build the Spreadsheet Data
      // We use commas to separate columns, and \n to create new rows
      String csvData = "Date,Category,Note,Amount (INR)\n";
      
      for (var entry in monthEntries) {
        final date = DateFormat('dd-MMM-yyyy').format(entry.date);
        final category = entry.catId;
        // Clean the note of any commas so it doesn't break the CSV columns
        final note = entry.note.replaceAll(',', ' '); 
        final amount = entry.amount.toStringAsFixed(2);
        
        csvData += "$date,$category,$note,$amount\n";
      }

      // Add a Total Row at the bottom
      final total = monthEntries.fold(0.0, (sum, e) => sum + e.amount);
      csvData += "\n,,TOTAL SPENT,${total.toStringAsFixed(2)}\n";

      // 2. Save it to a Temporary File on the Phone
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/Splitsathi_$monthKey.csv';
      final File file = File(filePath);
      await file.writeAsString(csvData);

      // 3. Open the Native iOS/Android Share Sheet
      final dateObj = DateTime.parse('$monthKey-01');
      final monthName = DateFormat('MMMM yyyy').format(dateObj);
      
      await Share.shareXFiles(
        [XFile(filePath)], 
        text: 'Here is my expense report for $monthName from Splitsathi! 📊',
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('yyyy-MM').format(selectedMonth);
    final activeOnMonth = entries.where((e) => !e.deleted && DateFormat('yyyy-MM').format(e.date) == monthStr).toList();
    final monthTotal = activeOnMonth.fold(0.0, (sum, e) => sum + e.amount);

    final liveCatNames = categories.map((c) => c['name']).toSet();
    final displayCategories = List<Map<String, dynamic>>.from(categories);
    
    for (var e in activeOnMonth) {
      if (!liveCatNames.contains(e.catId)) {
        displayCategories.add({'name': e.catId, 'icon': '📦'});
        liveCatNames.add(e.catId);
      }
    }

    final isCurrentMonth = DateFormat('yyyy-MM').format(DateTime.now()) == monthStr;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), 
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('MONTHLY BREAKDOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onMonthChanged(-1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_left, color: AppColors.orange, size: 20)),
                ),
                Text(
                  isCurrentMonth ? 'This Month' : DateFormat('MMMM yyyy').format(selectedMonth), 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.orange)
                ),
                GestureDetector(
                  onTap: () => onMonthChanged(1),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_right, color: AppColors.orange, size: 20)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (activeOnMonth.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _exportMonthToCSV(context, monthStr, activeOnMonth),
                icon: const Icon(Icons.download_rounded, color: AppColors.orange, size: 20),
                label: Text(
                  'Export ${DateFormat('MMMM').format(selectedMonth)} Report', 
                  style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.orange.withOpacity(0.3), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

        // --- NEW: THE EXPORT BUTTON ---

        if (activeOnMonth.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 40),
             child: Center(child: Text("No expenses logged in this month.", style: TextStyle(color: Colors.grey))),
           ),

        ...displayCategories.map((cat) {
          final catSpent = activeOnMonth.where((e) => e.catId == cat['name']).fold(0.0, (s, e) => s + e.amount);
          
          if (catSpent == 0 && !categories.any((c) => c['name'] == cat['name'])) {
            return const SizedBox.shrink(); 
          }

          final percentage = monthTotal > 0 ? (catSpent / monthTotal) : 0.0;
          final index = displayCategories.indexOf(cat);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final monthCatHistory = activeOnMonth.where((e) => e.catId == cat['name']).toList();
              showModalBottomSheet(
                context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                builder: (_) => _CategoryHistorySheet(catName: cat['name'], catIcon: cat['icon'], entries: monthCatHistory, isDark: isDark, myUid: myUid),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(cat['icon'], style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 12),
                      Text(cat['name'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                      const Spacer(),
                      Text('₹${catSpent.round()}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: percentage.clamp(0, 1)),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value, 
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), 
                        color: _TodayTab._categoryColor(index), 
                        minHeight: 8
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CategorySelectorSheet extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final bool isDark;

  const _CategorySelectorSheet({required this.categories, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select a Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 20, crossAxisSpacing: 10, childAspectRatio: 0.8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context); 
                  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _AddEntrySheet(catName: cat['name']));
                },
                child: Column(
                  children: [
                    Container(
                      height: 60, width: 60,
                      decoration: BoxDecoration(color: isDark ? AppColors.darkBg : AppColors.cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
                      child: Center(child: Text(cat['icon'], style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 8),
                    Text(cat['name'], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MiniPiePainter extends CustomPainter {
  final List<DiaryEntry> entries;
  final List<Map<String, dynamic>> categories;
  final double animationValue; 
  
  _MiniPiePainter({required this.entries, required this.categories, this.animationValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final total = entries.where((e) => !e.deleted).fold(0.0, (sum, e) => sum + e.amount);
    if (total == 0) return;
    
    double startAngle = -math.pi / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    for (int i = 0; i < categories.length; i++) {
      final catAmount = entries.where((e) => !e.deleted && e.catId == categories[i]['name']).fold(0.0, (sum, e) => sum + e.amount);
      if (catAmount > 0) {
        final sweepAngle = (catAmount / total) * 2 * math.pi * animationValue;
        // FIXED COLOR LOGIC: i + 1
        final color = _TodayTab._categoryColor(i);
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, Paint()..color = color);
        startAngle += sweepAngle;
      }
    }
    canvas.drawCircle(center, radius * 0.6, Paint()..color = Colors.white.withOpacity(0.2));
  }
  
  @override
  bool shouldRepaint(covariant _MiniPiePainter oldDelegate) => 
    oldDelegate.animationValue != animationValue || oldDelegate.entries.length != entries.length;
}

class _CategoryHistorySheet extends StatefulWidget {
  final String catName;
  final String catIcon;
  final List<DiaryEntry> entries;
  final bool isDark;
  final String myUid;

  const _CategoryHistorySheet({
    required this.catName, required this.catIcon, required this.entries, required this.isDark, required this.myUid
  });

  @override
  State<_CategoryHistorySheet> createState() => _CategoryHistorySheetState();
}

class _CategoryHistorySheetState extends State<_CategoryHistorySheet> {
  late List<DiaryEntry> _localEntries;

  @override
  void initState() {
    super.initState();
    _localEntries = List.from(widget.entries);
    
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.catIcon} ${widget.catName} History', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          if (_localEntries.isEmpty) 
            const Text("No logs for this category.")
          else Flexible(
            child: ListView.builder(
              shrinkWrap: true, 
              itemCount: _localEntries.length,
              itemBuilder: (context, i) {
                final entry = _localEntries[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.note),
                  subtitle: Text(DateFormat('d MMM, yyyy').format(entry.date)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${entry.amount.round()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () {
                          DatabaseService().deletePrivateDiaryEntry(widget.myUid, entry.id);
                          setState(() {
                            _localEntries.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageCategoriesSheet extends StatefulWidget {
  final String myUid;
  const _ManageCategoriesSheet({required this.myUid});
  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '📦';

  static const _emojis = ['📦', '🛒', '🎮', '✈️', '🏋️', '📚', '💊', '🐾', '🎨', '👗', '🔧', '🌿'];

  void _showDeleteConfirmation(BuildContext context, String docId, String catName, String catIcon, int entryCount, double totalSpent, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Icon(Icons.delete_forever, color: Colors.red, size: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete "$catName"?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text('$catIcon  $catName', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Text(
                'This will permanently delete $entryCount ${entryCount == 1 ? "entry" : "entries"} and remove ₹${totalSpent.round()} from your entire history. This cannot be undone.',
                style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      DatabaseService().deletePrivateCategory(widget.myUid, docId, catName);
                      Navigator.pop(context); // close confirmation
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('Yes, Delete Everything', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String id, String currentName, String currentIcon, bool isDark) {
    final editController = TextEditingController(text: currentName);
    String editEmoji = currentIcon;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Edit Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _emojis.map((emoji) {
                  final isSel = emoji == editEmoji;
                  return GestureDetector(
                    onTap: () => setModalState(() => editEmoji = emoji),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.orange.withOpacity(0.15) : Colors.transparent,
                        border: Border.all(color: isSel ? AppColors.orange : (isDark ? Colors.white24 : Colors.black12), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: editController,
                autofocus: true,
                style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Category name',
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (editController.text.isNotEmpty) {
                      DatabaseService().savePrivateCategory(widget.myUid, editController.text.trim(), editEmoji, docId: id);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Center(child: Text('Manage Sections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor))),
          const SizedBox(height: 20),

          // Emoji picker
          const Text('PICK EMOJI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _emojis.map((emoji) {
              final isSelected = emoji == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = emoji),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.orange.withOpacity(0.15) : Colors.transparent,
                    border: Border.all(color: isSelected ? AppColors.orange : (isDark ? Colors.white24 : Colors.black12), width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Name input + add button
          const Text('NEW CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'e.g. Health, Pets...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_nameController.text.isNotEmpty) {
                    DatabaseService().savePrivateCategory(widget.myUid, _nameController.text.trim(), _selectedEmoji);
                    _nameController.clear();
                    setState(() => _selectedEmoji = '📦');
                  }
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category list
          const Text('YOUR CATEGORIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: DatabaseService().getPrivateCategoriesStream(widget.myUid),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('No categories yet.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black26))),
                );
              }
              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final catName = doc['name'] as String;
                    final catIcon = doc['icon'] as String? ?? '📦';
                    final catColor = _TodayTab.staticCategoryColor(i);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          // Color accent dot
                          Container(width: 4, height: 36, decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 12),
                          // Emoji
                          Text(catIcon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          // Name
                          Expanded(child: Text(catName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textColor))),
                          // Edit
                          GestureDetector(
                            onTap: () => _showEditDialog(context, doc.id, catName, catIcon, isDark),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.orange),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete
                          FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users').doc(widget.myUid)
                                .collection('private_diary')
                                .where('category', isEqualTo: catName)
                                .where('deleted', isEqualTo: false)
                                .get(),
                            builder: (context, entrySnap) {
                              final entryCount = entrySnap.data?.docs.length ?? 0;
                              final totalSpent = entrySnap.data?.docs.fold(0.0, (sum, d) => sum + ((d['amount'] as num).toDouble())) ?? 0.0;
                              return GestureDetector(
                                onTap: () => _showDeleteConfirmation(context, doc.id, catName, catIcon, entryCount, totalSpent, isDark),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _AddEntrySheet extends StatefulWidget {
  final String catName;
  const _AddEntrySheet({required this.catName});
  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Log ${widget.catName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          TextField(controller: _amount, keyboardType: TextInputType.number, autofocus: true, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), decoration: const InputDecoration(prefixText: '₹ ', border: InputBorder.none, hintText: '0')),
          TextField(controller: _note, decoration: const InputDecoration(hintText: 'Add a note (optional)', border: InputBorder.none)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final uid = AuthService().currentUser?.uid;
                final val = double.tryParse(_amount.text) ?? 0;
                if (uid != null && val > 0) {
                  await DatabaseService().addPrivateDiaryEntry(uid, _note.text.isEmpty ? widget.catName : _note.text, val, widget.catName, DateTime.now());
                  HapticFeedback.mediumImpact();
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.all(18)),
              child: const Text('Save to Private Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}