import '../screens/contact_picker_screen.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitsathi/screens/receipt_scanner_screen.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

// --- MODELS ---
class SplitPerson {
  String id;
  String name;
  double amountPaid;

  SplitPerson({required this.id, required this.name, this.amountPaid = 0.0});
}

class Settlement {
  final String from;
  final String to;
  final double amount;

  Settlement(this.from, this.to, this.amount);
}

// --- SCREEN ---
class QuickSplitScreen extends StatefulWidget {
  final double? initialTotal; // <-- NEW: Accepts data from the scanner

  const QuickSplitScreen({super.key, this.initialTotal});

  @override
  State<QuickSplitScreen> createState() => _QuickSplitScreenState();
}

class _QuickSplitScreenState extends State<QuickSplitScreen> with SingleTickerProviderStateMixin {
  int _currentStep = 0; 
  
  final TextEditingController _countController = TextEditingController();
  List<SplitPerson> _people = [];

  double _displayTotal = 0.0;
  double _displayFairShare = 0.0;
  List<Settlement> _finalSettlements = [];
  
  double? _targetTotal; // <-- NEW: Stores the scanned amount to show the user

  @override
  void initState() {
    super.initState();
    // If we came from the home page scanner, save the total!
    if (widget.initialTotal != null) {
      _targetTotal = widget.initialTotal;
    }
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _currentStep = 0);
    });
  }
  
  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  // --- ALGORITHM ---
  void _calculateSplit() {
    FocusScope.of(context).unfocus(); 
    
    final total = _people.fold(0.0, (sum, p) => sum + p.amountPaid);
    final fairShare = _people.isEmpty ? 0.0 : total / _people.length;
    
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amounts greater than ₹0.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    List<Map<String, dynamic>> balances = _people.map((p) => {
      'name': p.name.isEmpty ? 'Unknown' : p.name,
      'balance': p.amountPaid - fairShare
    }).toList();

    List<Map<String, dynamic>> debtors = balances.where((b) => (b['balance'] as double) < -0.01).toList();
    List<Map<String, dynamic>> creditors = balances.where((b) => (b['balance'] as double) > 0.01).toList();

    debtors.sort((a, b) => (a['balance'] as double).compareTo(b['balance'] as double));
    creditors.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

    List<Settlement> settlements = [];
    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      double debt = -(debtors[i]['balance'] as double);
      double credit = creditors[j]['balance'] as double;
      double amount = math.min(debt, credit);
      
      settlements.add(Settlement(debtors[i]['name'], creditors[j]['name'], amount));

      debtors[i]['balance'] = (debtors[i]['balance'] as double) + amount;
      creditors[j]['balance'] = (creditors[j]['balance'] as double) - amount;

      if ((debtors[i]['balance'] as double).abs() < 0.01) i++;
      if ((creditors[j]['balance'] as double).abs() < 0.01) j++;
    }

    setState(() {
      _displayTotal = total;
      _displayFairShare = fairShare;
      _finalSettlements = settlements;
      _currentStep = 2; // Trigger Results Overlay
    });
  }

  void _generatePeopleList(String value) {
    int count = int.tryParse(value) ?? 0;
    if (count >= 2) {
      HapticFeedback.lightImpact();
      FocusScope.of(context).unfocus();
      setState(() {
        _people = List.generate(count, (i) => SplitPerson(id: i.toString(), name: 'Person ${i + 1}'));
        _currentStep = 1; // Trigger sliding in Parts 2 & 3
      });
    }
  }

  void _resetFlow() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStep = 0;
      _people.clear();
      _countController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Stack(
            children: [
              // BASE LAYER: The Input Flow (Parts 1, 2, 3)
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // PART 1: The Question Box
                          _buildPart1Question(isDark),
                          
                          const SizedBox(height: 24),
                          
                          // PART 2: The Sliding List of Avatars
                          Expanded(
                            child: AnimatedOpacity(
                              opacity: _currentStep >= 1 ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 500),
                              child: AnimatedSlide(
                                offset: _currentStep >= 1 ? Offset.zero : const Offset(0, 0.5),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                child: _currentStep >= 1 
                                  ? ListView.builder(
                                      itemCount: _people.length,
                                      padding: const EdgeInsets.only(bottom: 20),
                                      itemBuilder: (context, index) => _buildPersonCard(_people[index], isDark, index),
                                    )
                                  : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          
                          // PART 3: The Sliding Calculate Button
                          AnimatedOpacity(
                            opacity: _currentStep >= 1 ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 600),
                            child: AnimatedSlide(
                              offset: _currentStep >= 1 ? Offset.zero : const Offset(0, 1.0),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutBack,
                              child: _currentStep >= 1
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 20, top: 10),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 60,
                                        child: ElevatedButton.icon(
                                          onPressed: _calculateSplit,
                                          icon: const Icon(Icons.calculate_rounded, color: Colors.white),
                                          label: const Text('Calculate Split', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.orange,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            elevation: 8,
                                            shadowColor: AppColors.orange.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // OVERLAY LAYER: The Beautiful Read-Only Results
              if (_currentStep == 2)
                _buildResultsOverlay(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.orange, size: 20), onPressed: () => Navigator.pop(context)),
          const Text('Advanced Split', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.orange)),
          Row(
            children: [
              // --- NEW: INTERNAL SCANNER BUTTON ---
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined, color: AppColors.orange, size: 22), 
                onPressed: () async {
                  final scannedTotal = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReceiptScannerScreen()),
                  );
                  if (scannedTotal != null && scannedTotal is double) {
                    setState(() {
                      _targetTotal = scannedTotal; // Update the UI with the new total
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.orange, size: 22), 
                onPressed: _resetFlow,
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- PART 1 ---
  Widget _buildPart1Question(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.orange, Color(0xFFFB923C)]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentStep == 0 ? 'START SPLITTING' : 'SPLITTING AMONG', 
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _currentStep == 0 
                  ? TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      cursorColor: Colors.white,
                      cursorHeight: 40, 
                      cursorWidth: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        hintText: 'How many people?',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _generatePeopleList,
                      onChanged: (val) {
                         if ((int.tryParse(val) ?? 0) >= 2 && val.length > 1) {
                           _generatePeopleList(val); // Auto-advance if logic suits
                         }
                      },
                    )
                  : Text('${_people.length} People', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              ),
              if (_currentStep == 0)
                IconButton(
                  onPressed: () => _generatePeopleList(_countController.text),
                  icon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  // --- PART 2 ---
  Widget _buildPersonCard(SplitPerson person, bool isDark, int index) {
    final avatarColors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.pink];
    final avatarColor = avatarColors[index % avatarColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: avatarColor.withOpacity(0.15),
              child: Icon(Icons.person, color: avatarColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      // IMPORTANT: We need this ValueKey! It forces Flutter to update the 
                      // text field automatically when the AI/Contact Picker changes the name.
                      key: ValueKey(person.name), 
                      initialValue: person.name,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'Enter name...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal)
                      ),
                      onChanged: (val) => person.name = val,
                    ),
                  ),
                  
                  // --- THE TRIGGER BUTTON ---
                  IconButton(
                    icon: const Icon(Icons.contacts_rounded, color: AppColors.orange, size: 20),
                    onPressed: () async {
                      // 1. Open the Contact Picker
                      final selectedContact = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ContactPickerScreen()),
                      );
                      
                      // 2. If they picked someone, update the name!
                      if (selectedContact != null) {
                        setState(() {
                          person.name = selectedContact.displayName;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextFormField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.orange),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                  hintText: '0',
                  hintStyle: TextStyle(color: AppColors.orange.withOpacity(0.4))
                ),
                onChanged: (val) => person.amountPaid = double.tryParse(val.replaceAll('₹', '').trim()) ?? 0.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- THE RESULTS OVERLAY ---
  Widget _buildResultsOverlay(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, opacity, child) {
        return Stack(
          children: [
            // Glassmorphism Blur Background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * opacity, sigmaY: 10 * opacity),
              child: Container(color: Colors.black.withOpacity(0.4 * opacity)),
            ),
            
            // Sliding Up Results Card
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: _currentStep == 2 ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.cream,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, -10))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overlay Header with Close Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Split Breakdown', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          IconButton(
                            onPressed: () => setState(() => _currentStep = 1), // Close overlay, go back to edit
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 20),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Result Hero Stats
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(24)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('TOTAL SPENT', style: TextStyle(color: AppColors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹${_displayTotal.round()}', style: const TextStyle(color: AppColors.orange, fontSize: 24, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(24)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('FAIR SHARE', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹${_displayFairShare.round()}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      Text('HOW TO SETTLE UP', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 16),

                      // Scrollable list of settlements inside the bottom sheet
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _finalSettlements.map((s) => Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(s.from, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Icon(Icons.arrow_forward_rounded, color: AppColors.orange, size: 20),
                                  ),
                                  Expanded(flex: 3, child: Text(s.to, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                    child: Text('₹${s.amount.round()}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.orange)),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => _shareSplit(_finalSettlements),
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text('Share Breakdown', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: AppColors.orange.withOpacity(0.5),
                          ),
                        ),
                      )
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

  void _shareSplit(List<Settlement> settlements) {
    HapticFeedback.mediumImpact();
    String shareText = '🧾 *Splitsathi Advanced Split*\nTotal Spent: ₹${_displayTotal.round()}\nFair Share: ₹${_displayFairShare.round()} / person\n\n*How to Settle Up:*\n';
    for (var s in settlements) {
      shareText += '💸 ${s.from} owes ${s.to} ₹${s.amount.round()}\n';
    }
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Settlement plan copied!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}