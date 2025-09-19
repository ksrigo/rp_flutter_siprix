import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/contacts_service.dart';
import '../../../../core/services/sip_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/contact_model.dart';

const _alphabet = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
];

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final GlobalKey _tabsKey = GlobalKey();
  
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  StreamSubscription<List<ContactModel>>? _contactsSubscription;
  List<ContactModel> _currentContacts = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_onSearchChanged);
    _initializeContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _contactsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize contacts service if not already done
      if (!ContactsService.instance.isInitialized) {
        await ContactsService.instance.initialize();
      }
      
      // Subscribe to contacts stream
      _subscribeToContacts();
    } catch (e) {
      debugPrint('ContactsPage: Error initializing contacts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading contacts: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToContacts() {
    _contactsSubscription?.cancel();
    
    Stream<List<ContactModel>> stream;
    if (_selectedTabIndex == 1) {
      // Favorites tab
      stream = ContactsService.instance.getFavoriteContacts();
    } else {
      // All contacts tab
      stream = ContactsService.instance.getAllContacts();
    }

    // Apply search filter if needed
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      stream = ContactsService.instance.searchContacts(query);
    }

    _contactsSubscription = stream.listen(
      (contacts) {
        setState(() {
          _currentContacts = contacts;
        });
      },
      onError: (error) {
        debugPrint('ContactsPage: Error in contacts stream: $error');
      },
    );
  }

  void _onSearchChanged() {
    _subscribeToContacts();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await ContactsService.instance.refreshContacts();
    } catch (e) {
      debugPrint('ContactsPage: Error refreshing contacts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing contacts: $e')),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupContacts(_currentContacts);
    _refreshSectionKeys(grouped.keys);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildSearchField(),
                const SizedBox(height: 20),
                _buildTabs(),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: _buildContactList(grouped),
                        ),
                ),
              ],
            ),
            _buildAlphabetIndex(grouped.keys),
            if (_isRefreshing) _buildRefreshingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Text(
            'Contacts',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          _buildAddContactButton(),
        ],
      ),
    );
  }

  Widget _buildAddContactButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white),
        onPressed: _showAddContactDialog,
        tooltip: 'Add contact',
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
          hintText: 'Search contacts',
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      key: _tabsKey,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                text: 'All',
                isSelected: _selectedTabIndex == 0,
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 0;
                  });
                  _subscribeToContacts();
                },
              ),
            ),
            Expanded(
              child: _buildTabButton(
                text: 'Favorites',
                isSelected: _selectedTabIndex == 1,
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 1;
                  });
                  _subscribeToContacts();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({required String text, required bool isSelected, required VoidCallback onTap}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: -0.1,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildRefreshingIndicator() {
    return Positioned(
      top: 160,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Refreshing contacts...',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactList(Map<String, List<ContactModel>> grouped) {
    final children = <Widget>[];
    
    if (grouped.isEmpty) {
      // Add empty state as a child of ListView to enable pull-to-refresh
      children.add(
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6, // Ensure enough height for pull gesture
          child: _buildEmptyState(),
        ),
      );
    } else {
      for (final entry in grouped.entries) {
        final letter = entry.key;
        final contacts = entry.value;
        final key = _sectionKeys[letter]!;

        children
          ..add(KeyedSubtree(
            key: key,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ))
          ..addAll(contacts.map((contact) => _ContactRow(contact: contact)));
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      physics: const AlwaysScrollableScrollPhysics(), // Enable scrolling even with few items
      children: children,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.contacts,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedTabIndex == 1 ? 'No favorite contacts yet' : 'No contacts found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedTabIndex == 1 
                ? 'Mark contacts as favorites to see them here.'
                : 'Add contacts or enable device contacts in Settings.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlphabetIndex(Iterable<String> visibleLetters) {
    final visibleSet = visibleLetters.toSet();
    
    return Positioned(
      top: 160, // Align with the tabs level
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _alphabet.map((letter) {
          final isActive = visibleSet.contains(letter);
          return GestureDetector(
            onTap: isActive ? () => _scrollToLetter(letter) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _scrollToLetter(String letter) {
    final key = _sectionKeys[letter];
    final context = key?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        alignment: 0.0,
      );
    }
  }

  void _refreshSectionKeys(Iterable<String> sectionLetters) {
    _sectionKeys
      ..clear()
      ..addEntries(
        sectionLetters.map((letter) => MapEntry(letter, GlobalKey())),
      );
  }

  Map<String, List<ContactModel>> _groupContacts(List<ContactModel> contacts) {
    final map = <String, List<ContactModel>>{};
    for (final contact in contacts) {
      final firstLetter = contact.formattedName.isNotEmpty
          ? contact.formattedName[0].toUpperCase()
          : '#';
      map.putIfAbsent(firstLetter, () => []).add(contact);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {
      for (final letter in sortedKeys)
        letter: map[letter]!..sort((a, b) => a.formattedName.compareTo(b.formattedName)),
    };
  }

  void _showAddContactDialog() {
    NavigationService.goToAddContact();
  }
}

class _ContactRow extends StatelessWidget {
  final ContactModel contact;

  const _ContactRow({
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => NavigationService.goToEditContact(contact),
            child: Row(
              children: [
                _buildAvatar(context),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.formattedName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phones.isNotEmpty ? contact.phones.first.label : 'No phone',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(context),
              ],
            ),
          ),
          Divider(
            height: 20,
            thickness: 0.8,
            indent: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        contact.initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            contact.isFavorite ? Icons.star : Icons.star_border,
            color: contact.isFavorite
                ? AppTheme.warning
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => _toggleFavorite(context),
          tooltip: contact.isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
        IconButton(
          icon: Icon(Icons.call, color: Theme.of(context).colorScheme.primary),
          onPressed: contact.phones.isNotEmpty ? () => _makeCall(context) : null,
          tooltip: 'Call',
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      await ContactsService.instance.updateContactFavorite(
        contact.contactId,
        !contact.isFavorite,
      );
    } catch (e) {
      debugPrint('ContactRow: Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite: $e')),
      );
    }
  }

  Future<void> _makeCall(BuildContext context) async {
    if (contact.phones.isEmpty) return;

    String? selectedNumber;

    // If multiple numbers, show selection dialog
    if (contact.phones.length > 1) {
      selectedNumber = await _showNumberSelectionDialog(context);
      if (selectedNumber == null) return; // User cancelled
    } else {
      // Single number, use it directly
      selectedNumber = contact.phones.first.number;
    }

    try {
      final callId = await SipService.instance.makeCall(selectedNumber);
      
      if (callId != null) {
        debugPrint('ContactRow: Initiated call to ${contact.formattedName} ($selectedNumber)');
        
        // Navigate to in-call screen
        NavigationService.goToInCall(
          callId,
          phoneNumber: selectedNumber,
          contactName: contact.formattedName,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to initiate call')),
          );
        }
      }
    } catch (e) {
      debugPrint('ContactRow: Error making call: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }

  Future<String?> _showNumberSelectionDialog(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Call ${contact.formattedName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a number to call:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            // Phone numbers list
            ...contact.phones.map((phone) => _buildPhoneOption(context, phone)),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneOption(BuildContext context, ContactPhoneModel phone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getPhoneIcon(phone.label),
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          phone.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          phone.number,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.call,
          color: Theme.of(context).colorScheme.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: const Color(0xFFF8F9FA),
        onTap: () => Navigator.of(context).pop(phone.number),
      ),
    );
  }

  IconData _getPhoneIcon(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('mobile') || lowerLabel.contains('cell')) {
      return Icons.smartphone;
    } else if (lowerLabel.contains('work') || lowerLabel.contains('office')) {
      return Icons.business;
    } else if (lowerLabel.contains('home')) {
      return Icons.home;
    } else {
      return Icons.phone;
    }
  }
}