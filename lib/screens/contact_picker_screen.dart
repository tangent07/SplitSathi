import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact>? _contacts;
  List<Contact>? _filteredContacts;
  bool _permissionDenied = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    // 1. Request permission using the new V2 syntax
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    
    if (status != PermissionStatus.granted) {
      setState(() => _permissionDenied = true);
      return;
    }

    // 2. Fetch all contacts using the new V2 syntax
    final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
    
    // Sort alphabetically (Safely handling null names)
    contacts.sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));
    
    setState(() {
      _contacts = contacts;
      _filteredContacts = contacts;
    });
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    if (_contacts == null) return;

    setState(() {
      _filteredContacts = _contacts!.where((c) {
        // Safely check if the name contains the search query
        return (c.displayName ?? '').toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.orange), onPressed: () => Navigator.pop(context)),
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          cursorColor: AppColors.orange,
          decoration: InputDecoration(
            hintText: 'Search Contacts...',
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.perm_contact_calendar_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Permission Denied', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('We need access to your contacts\nto help you split bills with friends.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              child: const Text('Go Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    if (_filteredContacts == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orange));
    }

    if (_filteredContacts!.isEmpty) {
      return const Center(child: Text('No contacts found', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }

    return ListView.builder(
      itemCount: _filteredContacts!.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts![index];
        
        // --- NEW: Safe fallbacks for missing data ---
        final String displayName = contact.displayName ?? 'Unknown';
        final String phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone number';
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.orange.withOpacity(0.2),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          subtitle: Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          onTap: () {
            HapticFeedback.lightImpact();
            // Return the selected contact back to the previous screen!
            Navigator.pop(context, contact); 
          },
        );
      },
    );
  }
}