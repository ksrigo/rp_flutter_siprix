import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
const _alphabet = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
];

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final GlobalKey _tabsKey = GlobalKey();
  
  int _selectedTabIndex = 0;

  late final List<_ContactItem> _allContacts;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() => setState(() {}));
    _allContacts = _generatePlaceholderContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts();
    final grouped = _groupContacts(contacts);
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
                Expanded(child: _buildContactList(grouped)),
              ],
            ),
            _buildAlphabetIndex(grouped.keys),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Text(
            'Contacts',
            style: TextStyle(
              fontSize: 26,
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
        onPressed: () {
          // TODO: integrate add contact flow
          debugPrint('Add contact tapped');
        },
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
                onTap: () => setState(() => _selectedTabIndex = 0),
              ),
            ),
            Expanded(
              child: _buildTabButton(
                text: 'Favorites',
                isSelected: _selectedTabIndex == 1,
                onTap: () => setState(() => _selectedTabIndex = 1),
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

  Widget _buildContactList(Map<String, List<_ContactItem>> grouped) {
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No contacts found',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final children = <Widget>[];
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

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }

  Widget _buildAlphabetIndex(Iterable<String> visibleLetters) {
    final visibleSet = visibleLetters.toSet();
    
    return Positioned(
      top: 160, // Align with the tabs level (approximately header + search + tabs)
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

  Map<String, List<_ContactItem>> _groupContacts(List<_ContactItem> contacts) {
    final map = <String, List<_ContactItem>>{};
    for (final contact in contacts) {
      final firstLetter = contact.name.isNotEmpty
          ? contact.name[0].toUpperCase()
          : '#';
      map.putIfAbsent(firstLetter, () => []).add(contact);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {
      for (final letter in sortedKeys)
        letter: map[letter]!..sort((a, b) => a.name.compareTo(b.name)),
    };
  }

  List<_ContactItem> _filteredContacts() {
    final query = _searchController.text.trim().toLowerCase();
    final showFavorites = _selectedTabIndex == 1;

    return _allContacts.where((contact) {
      if (showFavorites && !contact.isFavorite) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return contact.name.toLowerCase().contains(query);
    }).toList();
  }

  List<_ContactItem> _generatePlaceholderContacts() {
    const names = [
      'Alice Johnson',
      'Amanda Lee',
      'Andrew Miller',
      'Brandon Cooper',
      'Beatrice Clark',
      'Catherine Diaz',
      'Charles Edwards',
      'Derek Foster',
      'Emily Garcia',
      'Ethan Harris',
      'Fabian Ives',
      'Gabriella Jones',
      'Hannah Kim',
      'Isabella Lopez',
      'Jacob Martinez',
      'Liam Nelson',
      'Mia Owens',
      'Nora Patel',
      'Oliver Quinn',
      'Penelope Ross',
      'Quentin Stone',
      'Ryan Thompson',
      'Sophia Underwood',
      'Thomas Vaughn',
      'Uma Walker',
      'Victor Xu',
      'Willow Young',
      'Zachary Zimmerman',
    ];

    final random = Random(42);
    final labels = ['Mobile', 'Work', 'Home'];

    return List<_ContactItem>.generate(names.length, (index) {
      final name = names[index];
      final label = labels[index % labels.length];
      final isFavorite = random.nextBool() && index % 3 == 0;
      return _ContactItem(
        name: name,
        label: label,
        isFavorite: isFavorite,
      );
    });
  }
}

class _ContactItem {
  final String name;
  final String label;
  final bool isFavorite;

  const _ContactItem({
    required this.name,
    required this.label,
    this.isFavorite = false,
  });
}

class _ContactRow extends StatelessWidget {
  final _ContactItem contact;

  const _ContactRow({
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatar(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.call, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  debugPrint('Call ${contact.name} tapped');
                },
                tooltip: 'Call',
              ),
            ],
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
    final initials = contact.name.isNotEmpty
        ? contact.name.trim().split(RegExp(r'\s+')).map((part) => part[0]).take(2).join().toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
