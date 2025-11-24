import 'package:flutter/material.dart';

import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/voicemail_service.dart';
import '../../data/models/voicemail_model.dart';

class VoicemailScreen extends StatefulWidget {
  const VoicemailScreen({super.key});

  @override
  State<VoicemailScreen> createState() => _VoicemailScreenState();
}

class _VoicemailScreenState extends State<VoicemailScreen> {
  final VoicemailService _voicemailService = VoicemailService.instance;
  int _selectedTabIndex = 0;
  bool _selectionMode = false;
  final Set<String> _selectedVoicemails = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeVoicemails();
    _voicemailService.addListener(_onVoicemailsChanged);
  }

  @override
  void dispose() {
    _voicemailService.removeListener(_onVoicemailsChanged);
    super.dispose();
  }

  void _onVoicemailsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeVoicemails() async {
    await _voicemailService.initialize();
    await _voicemailService.fetchVoicemails();
  }

  Future<void> _refreshVoicemails() async {
    setState(() => _isRefreshing = true);
    await _voicemailService.refreshVoicemails();
    setState(() => _isRefreshing = false);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedVoicemails.contains(id)) {
        _selectedVoicemails.remove(id);
        if (_selectedVoicemails.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedVoicemails.add(id);
      }
    });
  }

  void _startSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedVoicemails.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedVoicemails.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final selectedIds = _selectedVoicemails.toList();
    setState(() {
      _selectionMode = false;
      _selectedVoicemails.clear();
    });

    try {
      await _voicemailService.deleteVoicemails(selectedIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Deleted ${selectedIds.length} voicemail(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting voicemails: $e')),
        );
      }
    }
  }

  List<VoicemailModel> get _filteredVoicemails {
    if (_selectedTabIndex == 0) {
      return _voicemailService.voicemails; // All
    } else {
      return _voicemailService.savedVoicemails; // Saved (read)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: _voicemailService.isLoading && _voicemailService.voicemails.isEmpty
                  ? _buildLoadingState()
                  : _filteredVoicemails.isEmpty
                      ? _buildEmptyState()
                      : _buildVoicemailList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading voicemails...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          if (_selectionMode)
            IconButton(
              icon: Icon(Icons.close,
                  color: Theme.of(context).colorScheme.onSurface),
              onPressed: _cancelSelection,
            )
          else
            Text(
              'Voicemail',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          const Spacer(),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelected,
              tooltip: 'Delete selected',
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
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
              child: _buildTab(
                text: 'All',
                isSelected: _selectedTabIndex == 0,
                onTap: () => setState(() => _selectedTabIndex = 0),
              ),
            ),
            Expanded(
              child: _buildTab(
                text: 'Saved',
                isSelected: _selectedTabIndex == 1,
                onTap: () => setState(() => _selectedTabIndex = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: -0.1,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildVoicemailList() {
    return RefreshIndicator(
      onRefresh: _refreshVoicemails,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _filteredVoicemails.length,
        itemBuilder: (context, index) {
          final voicemail = _filteredVoicemails[index];
          return _buildVoicemailCard(voicemail);
        },
      ),
    );
  }

  Widget _buildVoicemailCard(VoicemailModel voicemail) {
    final isSelected = _selectedVoicemails.contains(voicemail.uuid);
    final isNew = voicemail.isUnread;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(voicemail.uuid);
              } else {
                NavigationService.goToVoicemailDetails(voicemail.uuid);
              }
            },
            onLongPress: () {
              if (!_selectionMode) {
                _startSelectionMode(voicemail.uuid);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Play icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isNew
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: isNew
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                voicemail.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isNew ? FontWeight.w600 : FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimestamp(voicemail.created),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              voicemail.fromUser,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(voicemail.duration),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Checkbox in selection mode
                  if (_selectionMode) ...[
                    const SizedBox(width: 8),
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(voicemail.uuid),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(
            height: 0,
            thickness: 0.8,
            indent: 52,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.voicemail_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No voicemails',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your voicemail messages will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}
