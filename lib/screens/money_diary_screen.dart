import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../providers/app_provider.dart';
import '../models/diary_entry.dart';
import '../utils/constants.dart';

class MoneyDiaryScreen extends StatefulWidget {
  const MoneyDiaryScreen({super.key});

  @override
  State<MoneyDiaryScreen> createState() => _MoneyDiaryScreenState();
}

class _MoneyDiaryScreenState extends State<MoneyDiaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _monthStr => DateFormat('yyyy-MM').format(_selectedMonth);
  bool get _isCurrentMonth =>
      DateFormat('yyyy-MM').format(_selectedMonth) ==
      DateFormat('yyyy-MM').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                          color: AppColors.orange, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700, fontSize: 14,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Text('Money Diary', style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 26,
                        fontWeight: FontWeight.w900, color: textColor,
                      )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Track your daily expenses', style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkMuted : AppColors.muted,
                  )),
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
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.orange,
                      unselectedLabelColor: isDark ? AppColors.darkMuted : AppColors.muted,
                      labelStyle: const TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14,
                      ),
                      tabs: const [Tab(text: 'Today'), Tab(text: 'This Month')],
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
                  _TodayTab(
                    provider: provider,
                    todayStr: _todayStr,
                    isDark: isDark,
                  ),
                  _MonthlyTab(
                    provider: provider,
                    monthStr: _monthStr,
                    selectedMonth: _selectedMonth,
                    isCurrentMonth: _isCurrentMonth,
                    isDark: isDark,
                    onMonthChanged: (dir) {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month + dir,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TODAY TAB ──────────────────────────────────────────────────────
class _TodayTab extends StatelessWidget {
  final AppProvider provider;
  final String todayStr;
  final bool isDark;
  const _TodayTab({required this.provider, required this.todayStr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final todayEntries = provider.diaryEntries.where((e) => e.dateStr == todayStr).toList();
    final total = todayEntries.fold(0.0, (s, e) => s + e.amount);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    // Pie data
    final pieData = <_PieSlice>[];
    for (int i = 0; i < provider.diaryCats.length; i++) {
      final cat = provider.diaryCats[i];
      final catTotal = todayEntries
          .where((e) => e.catId == cat.id)
          .fold(0.0, (s, e) => s + e.amount);
      if (catTotal > 0) {
        pieData.add(_PieSlice(
          label: cat.name,
          value: catTotal,
          color: AppConstants.getPieColor(i),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TODAY'S SPENDING", style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange, letterSpacing: 0.5,
                  )),
                  Text('Entries: ${todayEntries.length}', style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : AppColors.muted,
                  )),
                ],
              ),
              Divider(color: borderColor, height: 20),
              Row(
                children: [
                  // Pie chart
                  SizedBox(
                    width: 120, height: 120,
                    child: CustomPaint(
                      painter: _PiePainter(
                        slices: pieData,
                        total: total,
                        centerText: total > 0 ? '₹${total.round()}' : '',
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CATEGORIES', style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange, letterSpacing: 0.5,
                        )),
                        const SizedBox(height: 8),
                        if (pieData.isEmpty)
                          Text('No spending yet today', style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkMuted : AppColors.muted,
                          ))
                        else
                          ...pieData.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(s.label, style: TextStyle(
                                  fontSize: 12, color: textColor,
                                ))),
                                Text('₹${s.value.round()}', style: const TextStyle(
                                  fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                                  fontSize: 12, color: AppColors.orange,
                                )),
                              ],
                            ),
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Categories list
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('CATEGORIES', style: TextStyle(
              fontFamily: 'Nunito', fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.orange, letterSpacing: 0.5,
            )),
            GestureDetector(
              onTap: () => _showAddCatSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('+ Add', style: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                  fontSize: 13, color: Colors.white,
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...provider.diaryCats.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final catEntries = todayEntries.where((e) => e.catId == cat.id).toList();
          final catTotal = catEntries.fold(0.0, (s, e) => s + e.amount);
          final color = AppConstants.getPieColor(i);

          return GestureDetector(
            onTap: () => _openCatDetail(context, cat, isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name, style: TextStyle(
                          fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                          fontSize: 14, color: textColor,
                        )),
                        Text('${catEntries.length} entries', style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkMuted : AppColors.muted,
                        )),
                      ],
                    ),
                  ),
                  Text(
                    catTotal > 0 ? '₹${catTotal.round()}' : '₹0',
                    style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: catTotal > 0 ? color : (isDark ? AppColors.darkMuted : AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditCatSheet(context, cat),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Center(child: Text('✏️', style: TextStyle(fontSize: 12))),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _confirmDeleteCat(context, cat, provider, isDark),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Center(child: Text('🗑️', style: TextStyle(fontSize: 12))),
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

  void _openCatDetail(BuildContext context, DiaryCategory cat, bool isDark) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CatDetailScreen(cat: cat),
    ));
  }

  void _showAddCatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCatSheet(),
    );
  }

  void _showEditCatSheet(BuildContext context, DiaryCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCatSheet(cat: cat),
    );
  }

  void _confirmDeleteCat(BuildContext context, DiaryCategory cat,
      AppProvider provider, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${cat.name}"?', style: const TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w900,
        )),
        content: const Text('All expenses in this category will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteDiaryCategory(cat.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── MONTHLY TAB ────────────────────────────────────────────────────
class _MonthlyTab extends StatelessWidget {
  final AppProvider provider;
  final String monthStr;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final bool isDark;
  final Function(int) onMonthChanged;

  const _MonthlyTab({
    required this.provider,
    required this.monthStr,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.isDark,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final monthEntries = provider.diaryEntries
        .where((e) => e.monthStr == monthStr)
        .toList();
    final total = monthEntries.fold(0.0, (s, e) => s + e.amount);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final pieData = <_PieSlice>[];
    for (int i = 0; i < provider.diaryCats.length; i++) {
      final cat = provider.diaryCats[i];
      final catTotal = monthEntries
          .where((e) => e.catId == cat.id)
          .fold(0.0, (s, e) => s + e.amount);
      if (catTotal > 0) {
        pieData.add(_PieSlice(
          label: cat.name,
          value: catTotal,
          color: AppConstants.getPieColor(i),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        // Month navigator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => onMonthChanged(-1),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_left, color: AppColors.orange),
                ),
              ),
              Column(
                children: [
                  Text(
                    DateFormat('MMMM').format(selectedMonth),
                    style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 18,
                      fontWeight: FontWeight.w900, color: textColor,
                    ),
                  ),
                  Text(
                    selectedMonth.year.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: isCurrentMonth ? null : () => onMonthChanged(1),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : AppColors.peach,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: isCurrentMonth ? AppColors.muted.withOpacity(0.3) : AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pie chart card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 180, height: 180,
                child: CustomPaint(
                  painter: _PiePainter(
                    slices: pieData,
                    total: total,
                    centerText: total > 0 ? '₹${total.round()}' : '',
                    isDark: isDark,
                    size: 180,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (pieData.isEmpty)
                Text('No spending this month', style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                ))
              else
                ...pieData.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.label, style: TextStyle(
                        fontSize: 13, color: textColor,
                      ))),
                      Text('₹${s.value.round()}', style: const TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                        fontSize: 13, color: AppColors.orange,
                      )),
                    ],
                  ),
                )),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category rows
        const Text('CATEGORIES', style: TextStyle(
          fontFamily: 'Nunito', fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.orange, letterSpacing: 0.5,
        )),
        const SizedBox(height: 12),

        ...provider.diaryCats.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final catTotal = monthEntries
              .where((e) => e.catId == cat.id)
              .fold(0.0, (s, e) => s + e.amount);
          final color = AppConstants.getPieColor(i);
          final pct = total > 0 ? catTotal / total : 0.0;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(cat.name, style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                      fontSize: 14, color: textColor,
                    ))),
                    Text(
                      catTotal > 0 ? '₹${catTotal.round()}' : '₹0',
                      style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: catTotal > 0 ? color : (isDark ? AppColors.darkMuted : AppColors.muted),
                      ),
                    ),
                  ],
                ),
                if (catTotal > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.peach,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── CATEGORY DETAIL SCREEN ─────────────────────────────────────────
class _CatDetailScreen extends StatelessWidget {
  final DiaryCategory cat;
  const _CatDetailScreen({required this.cat});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final month = DateFormat('yyyy-MM').format(DateTime.now());

    final allEntries = provider.diaryEntries
        .where((e) => e.catId == cat.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final todayTotal = allEntries
        .where((e) => e.dateStr == today)
        .fold(0.0, (s, e) => s + e.amount);
    final monthTotal = allEntries
        .where((e) => e.monthStr == month)
        .fold(0.0, (s, e) => s + e.amount);

    final catIdx = provider.diaryCats.indexWhere((c) => c.id == cat.id);
    final color = AppConstants.getPieColor(catIdx >= 0 ? catIdx : 0);

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
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Center(child: Text(cat.icon, style: const TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name, style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 24,
                            fontWeight: FontWeight.w900, color: textColor,
                          )),
                          Text('${allEntries.length} total entries',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkMuted : AppColors.muted,
                            )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    children: [
                      Expanded(child: _statCard('Today', '₹${todayTotal.round()}',
                          isDark, borderColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('This Month', '₹${monthTotal.round()}',
                          isDark, borderColor)),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: allEntries.isEmpty
                  ? Center(child: Text('No entries yet', style: TextStyle(
                      fontSize: 15, color: isDark ? AppColors.darkMuted : AppColors.muted,
                    )))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      itemCount: allEntries.length,
                      itemBuilder: (context, i) {
                        final e = allEntries[i];
                        final date = DateFormat('d MMM yyyy').format(e.date);
                        final time = DateFormat('hh:mm a').format(e.date);
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: borderColor)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.note.isEmpty ? cat.name : e.note,
                                      style: TextStyle(
                                        fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                                        fontSize: 14, color: textColor,
                                      )),
                                    Text('$date · $time', style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkMuted : AppColors.muted,
                                    )),
                                  ],
                                ),
                              ),
                              Text('₹${e.amount.round()}', style: TextStyle(
                                fontFamily: 'Nunito', fontWeight: FontWeight.w900,
                                fontSize: 16, color: color,
                              )),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => provider.deleteDiaryEntry(e.id),
                                child: const Icon(Icons.close, size: 16, color: AppColors.error),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntrySheet(context, cat),
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _statCard(String label, String value, bool isDark, Color border) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.orange, letterSpacing: 0.5,
          )),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 22,
            fontWeight: FontWeight.w900, color: AppColors.orange,
          )),
        ],
      ),
    );
  }

  void _showAddEntrySheet(BuildContext context, DiaryCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(catId: cat.id, catName: cat.name),
    );
  }
}

// ── ADD ENTRY SHEET ────────────────────────────────────────────────
class _AddEntrySheet extends StatefulWidget {
  final String catId;
  final String catName;
  const _AddEntrySheet({required this.catId, required this.catName});

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      setState(() {});
      return;
    }
    context.read<AppProvider>().addDiaryEntry(DiaryEntry.create(
      catId: widget.catId,
      amount: amount,
      note: _noteController.text.trim(),
    ));
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _openNumpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DiaryNumpad(
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
            decoration: BoxDecoration(
              color: borderColor, borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          Text('Add Expense', style: TextStyle(
            fontFamily: 'Nunito', fontSize: 20,
            fontWeight: FontWeight.w900, color: textColor,
          )),
          const SizedBox(height: 20),

          // Amount
          Text('AMOUNT', style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.orange, letterSpacing: 0.5,
          )),
          const SizedBox(height: 8),
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
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: _amountController.text.isEmpty
                          ? (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4)
                          : textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Note
          Text('NOTE (OPTIONAL)', style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.orange, letterSpacing: 0.5,
          )),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'e.g. Lunch, Auto ride...',
              hintStyle: TextStyle(
                color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4),
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
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Text('Save →', style: TextStyle(
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

// ── ADD CATEGORY SHEET ─────────────────────────────────────────────
class _AddCatSheet extends StatefulWidget {
  @override
  State<_AddCatSheet> createState() => _AddCatSheetState();
}

class _AddCatSheetState extends State<_AddCatSheet> {
  final _nameController = TextEditingController();
  String _selectedIcon = '📦';

  final List<String> _icons = ['📦','🏠','🍽️','🚗','🎬','💰','💊','📚',
    '🛒','✈️','🎉','💡','🏋️','🐾','👗','🎮'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    context.read<AppProvider>().addDiaryCategory(
      DiaryCategory.create(name: name, icon: _selectedIcon),
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text('Add Category', style: TextStyle(
            fontFamily: 'Nunito', fontSize: 20,
            fontWeight: FontWeight.w900, color: textColor,
          )),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Category Name',
              labelStyle: const TextStyle(color: AppColors.orange),
              filled: true, fillColor: inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          Text('PICK AN ICON', style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.orange.withOpacity(0.15) : inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.orange : borderColor,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Add Category →', style: TextStyle(
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

// ── EDIT CATEGORY SHEET ────────────────────────────────────────────
class _EditCatSheet extends StatefulWidget {
  final DiaryCategory cat;
  const _EditCatSheet({required this.cat});

  @override
  State<_EditCatSheet> createState() => _EditCatSheetState();
}

class _EditCatSheetState extends State<_EditCatSheet> {
  late TextEditingController _nameController;
  late String _selectedIcon;

  final List<String> _icons = ['📦','🏠','🍽️','🚗','🎬','💰','💊','📚',
    '🛒','✈️','🎉','💡','🏋️','🐾','👗','🎮'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cat.name);
    _selectedIcon = widget.cat.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.cat.name = name;
    widget.cat.icon = _selectedIcon;
    context.read<AppProvider>().updateDiaryCategory(widget.cat);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text('Edit Category', style: TextStyle(
            fontFamily: 'Nunito', fontSize: 20,
            fontWeight: FontWeight.w900, color: textColor,
          )),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Category Name',
              labelStyle: const TextStyle(color: AppColors.orange),
              filled: true, fillColor: inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          Text('PICK AN ICON', style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.orange.withOpacity(0.15) : inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.orange : borderColor,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                ),
              );
            }).toList(),
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
    );
  }
}

// ── DIARY NUMPAD ───────────────────────────────────────────────────
class _DiaryNumpad extends StatefulWidget {
  final String initial;
  final Function(String) onConfirm;
  const _DiaryNumpad({required this.initial, required this.onConfirm});

  @override
  State<_DiaryNumpad> createState() => _DiaryNumpadState();
}

class _DiaryNumpadState extends State<_DiaryNumpad> {
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

// ── PIE CHART PAINTER ──────────────────────────────────────────────
class _PieSlice {
  final String label;
  final double value;
  final Color color;
  _PieSlice({required this.label, required this.value, required this.color});
}

class _PiePainter extends CustomPainter {
  final List<_PieSlice> slices;
  final double total;
  final String centerText;
  final bool isDark;
  final double size;

  _PiePainter({
    required this.slices,
    required this.total,
    required this.centerText,
    required this.isDark,
    this.size = 120,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = math.min(cx, cy) - 4;

    if (slices.isEmpty || total == 0) {
      final paint = Paint()
        ..color = isDark ? AppColors.darkSurface2 : const Color(0xFFFDE8CC)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, paint);
      final holePaint = Paint()
        ..color = isDark ? AppColors.darkSurface : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r * 0.52, holePaint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweep, true, paint,
      );
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweep, true, strokePaint,
      );
      startAngle += sweep;
    }

    // Hole
    final holePaint = Paint()
      ..color = isDark ? AppColors.darkSurface : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.52, holePaint);

    // Center text
    if (centerText.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: centerText,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: size < 130 ? 13 : 16,
            fontWeight: FontWeight.w900,
            color: AppColors.orange,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => true;
}