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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final activeOnDate = entries.where((e) => !e.deleted && DateFormat('yyyy-MM-dd').format(e.date) == dateStr).toList();

    final liveCatNames = categories.map((c) => c['name']).toSet();
    final displayCategories = List<Map<String, dynamic>>.from(categories);
    
    for (var e in activeOnDate) {
      if (!liveCatNames.contains(e.catId)) {
        displayCategories.add({'name': e.catId, 'icon': '📦'});
        liveCatNames.add(e.catId);
      }
    }

    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), 
      children: [
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.orange)
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

        if (activeOnDate.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 40),
             child: Center(child: Text("No expenses logged on this date.", style: TextStyle(color: Colors.grey))),
           ),

        ...displayCategories.asMap().entries.map((entry) {
          final cat = entry.value;
          final index = entry.key;
          final spent = activeOnDate.where((e) => e.catId == cat['name']).fold(0.0, (s, e) => s + e.amount);
          
          if (spent == 0 && !categories.any((c) => c['name'] == cat['name'])) {
            return const SizedBox.shrink(); 
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showCategoryHistory(context, cat, entries, isDark, myUid),
            child: _buildProgress(cat, spent, index, isDark),
          );
        }),
      ],
    );
  }

  Widget _buildProgress(Map<String, dynamic> cat, double spent, int index, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24), 
      child: Column(
        children: [
          Row(children: [Text(cat['icon'], style: const TextStyle(fontSize: 16)), const SizedBox(width: 10), Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const Spacer(), Text('₹${spent.round()}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.orange, fontSize: 14))]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: (spent / 2000).clamp(0, 1)),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value, 
                backgroundColor: isDark ? Colors.white10 : Colors.black12, 
                // FIXED COLOR LOGIC: index + 1 ensures all categories get distinct colors
                color: AppConstants.getPieColor(index + 1), 
                minHeight: 8
              ),
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
                        color: AppConstants.getPieColor(index + 1), 
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
        final color = AppConstants.getPieColor(i + 1);
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
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Manage Sections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Section Name'))),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.orange), onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  DatabaseService().savePrivateCategory(widget.myUid, _nameController.text.trim(), '📦');
                  _nameController.clear();
                }
              }),
            ],
          ),
          const Divider(height: 40),
          StreamBuilder<QuerySnapshot>(
            stream: DatabaseService().getPrivateCategoriesStream(widget.myUid),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(docs[i]['name']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showEditDialog(docs[i].id, docs[i]['name'])),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => DatabaseService().deletePrivateCategory(widget.myUid, docs[i].id)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String id, String currentName) {
    final editController = TextEditingController(text: currentName);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Rename Section'),
      content: TextField(controller: editController),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () {
          DatabaseService().savePrivateCategory(widget.myUid, editController.text.trim(), '📦', docId: id);
          Navigator.pop(context);
        }, child: const Text('Save')),
      ],
    ));
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