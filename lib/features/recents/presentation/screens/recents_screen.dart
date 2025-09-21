import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';

import '../../../../core/services/call_history_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/sip_service.dart';
import '../../../../core/theme/app_theme.dart';

class RecentsScreen extends ConsumerStatefulWidget {
  const RecentsScreen({super.key});

  @override
  ConsumerState<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends ConsumerState<RecentsScreen> {
  // Theme colors are accessed via Theme.of(context) in build methods

  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _selectionMode = false;
  final Set<String> _selectedCallKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeCallHistory();
  }

  Future<void> _initializeCallHistory() async {
    try {
      if (!CallHistoryService.instance.isInitialized) {
        await CallHistoryService.instance.initialize();
      }
    } catch (e) {
      debugPrint('RecentsScreen: Error initializing call history: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _selectionMode ? _buildSelectionHeader() : _buildHeader(),
            const SizedBox(height: 16),
            _buildTabBar(),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildTabBarView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Text(
        'Recents',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSelectionHeader() {
    final selectedCount = _selectedCallKeys.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close,
                  color: Theme.of(context).colorScheme.onSurface),
              tooltip: 'Cancel selection',
              onPressed: _exitSelectionMode,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$selectedCount selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete selected',
              onPressed: selectedCount == 0 ? null : _confirmBulkDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
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
              child: _buildTabButton(
                text: 'All',
                isSelected: _selectedTabIndex == 0,
                onTap: () => _onTabSelected(0),
              ),
            ),
            Expanded(
              child: _buildTabButton(
                text: 'Missed',
                isSelected: _selectedTabIndex == 1,
                onTap: () => _onTabSelected(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
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
                    color: Colors.black.withValues(alpha: 0.08),
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

  void _onTabSelected(int index) {
    if (index != _selectedTabIndex) {
      setState(() {
        _selectedTabIndex = index;
        _exitSelectionMode();
      });
    }
  }

  Widget _buildTabBarView() {
    return AnimatedBuilder(
      animation: CallHistoryService.instance,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          child: _selectedTabIndex == 0
              ? _buildGroupedCallList(
                  CallHistoryService.instance.getCallsGroupedByDate(),
                  key: const ValueKey('all'),
                )
              : _buildGroupedCallList(
                  CallHistoryService.instance.getMissedCallsGroupedByDate(),
                  key: const ValueKey('missed'),
                ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildGroupedCallList(Map<String, List<CdrModel>> groupedCalls,
      {Key? key}) {
    if (groupedCalls.isEmpty) {
      return Container(
        key: key,
        child: _buildEmptyState(),
      );
    }

    // Get all calls for selection validation
    final allCalls = groupedCalls.values.expand((calls) => calls).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_selectionMode) return;
      final validKeys = allCalls.map(_callKey).toSet();
      bool removed = false;
      for (final key in _selectedCallKeys.toList()) {
        if (!validKeys.contains(key)) {
          _selectedCallKeys.remove(key);
          removed = true;
        }
      }
      if (removed && mounted) {
        setState(() {
          if (_selectedCallKeys.isEmpty) {
            _selectionMode = false;
          }
        });
      }
    });

    // Get sorted date keys (Today first, then Yesterday, then chronological)
    final sortedDateKeys = groupedCalls.keys.toList();
    sortedDateKeys.sort((a, b) {
      if (a == 'Today') return -1;
      if (b == 'Today') return 1;
      if (a == 'Yesterday') return -1;
      if (b == 'Yesterday') return 1;
      // For other dates, maintain chronological order
      return a.compareTo(b);
    });

    return Container(
      key: key,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        itemCount: sortedDateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDateKeys[index];
          final calls = groupedCalls[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 16),
              _buildDateHeader(dateKey),
              const SizedBox(height: 8),
              ...calls.map((call) {
                final isSelected = _selectedCallKeys.contains(_callKey(call));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildDismissibleCall(call, isSelected),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String dateKey) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        CallHistoryService.getDisplayDate(dateKey),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            'No recent calls yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New calls will appear here automatically.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleCall(CdrModel call, bool isSelected) {
    final callKey = _callKey(call);
    return Dismissible(
      key: ValueKey(callKey),
      direction:
          _selectionMode ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmSingleDelete(call),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error, size: 28),
      ),
      child: _buildCallTile(call, isSelected),
    );
  }

  Widget _buildCallTile(CdrModel call, bool isSelected) {
    final callType = CallHistoryService.getCallType(call);
    final style = _CallVisualStyle.fromCall(call, callType);
    final displayName = _getDisplayName(call, callType);

    final subtitleSegments = <String>[
      CallHistoryService.formatCallTime(call.madeAt),
    ];

    if (_isAnswered(call)) {
      final durationText = _resolveDuration(call);
      if (durationText != null) {
        subtitleSegments.add(durationText);
      }
    } else {
      final statusLabel = _getStatusLabel(call, callType);
      if (statusLabel != null && callType != CallType.missed) {
        subtitleSegments.add(statusLabel);
      }
    }

    final subtitle = subtitleSegments.join(' · ');

    final highlightColor = isSelected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Material(
      color: highlightColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onCallTap(call, isSelected),
        onLongPress: () => _enterSelectionMode(call),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCallAvatar(style, isSelected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: callType == CallType.missed
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildInfoButton(call),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallAvatar(_CallVisualStyle style, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : style.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isSelected ? Icons.check : style.icon,
        color: isSelected ? Colors.white : style.iconColor,
        size: 22,
      ),
    );
  }

  Widget _buildInfoButton(CdrModel call) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _selectionMode ? null : () => _showCallDetails(call),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }

  void _onCallTap(CdrModel call, bool isSelected) {
    if (_selectionMode) {
      _toggleSelection(call);
      return;
    }

    // No action when not in selection mode - row tap disabled
  }

  void _enterSelectionMode(CdrModel call) {
    final key = _callKey(call);
    setState(() {
      if (_selectionMode) {
        _toggleSelection(call);
      } else {
        _selectionMode = true;
        _selectedCallKeys.add(key);
      }
    });
  }

  void _toggleSelection(CdrModel call) {
    final key = _callKey(call);
    setState(() {
      if (_selectedCallKeys.contains(key)) {
        _selectedCallKeys.remove(key);
        if (_selectedCallKeys.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedCallKeys.add(key);
      }
    });
  }

  void _exitSelectionMode() {
    if (_selectionMode) {
      setState(() {
        _selectionMode = false;
        _selectedCallKeys.clear();
      });
    }
  }

  Future<bool?> _confirmSingleDelete(CdrModel call) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete call?'),
          content: const Text('This call will be removed from Recents.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      CallHistoryService.instance.removeCall(call);
      setState(() {
        _selectedCallKeys.remove(_callKey(call));
        if (_selectedCallKeys.isEmpty) {
          _selectionMode = false;
        }
      });
      return true;
    }
    return false;
  }

  Future<void> _confirmBulkDelete() async {
    final count = _selectedCallKeys.length;
    if (count == 0) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete selected calls?'),
          content: Text(
              'Remove $count selected call${count > 1 ? 's' : ''} from Recents?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      final allCalls = CallHistoryService.instance.getAllCalls();
      final callsToRemove = allCalls
          .where((call) => _selectedCallKeys.contains(_callKey(call)))
          .toList();
      CallHistoryService.instance.removeCalls(callsToRemove);
      setState(() {
        _selectedCallKeys.clear();
        _selectionMode = false;
      });
    }
  }

  Future<void> _callNumber(String phoneNumber) async {
    try {
      Navigator.of(context).pop(); // Close the modal first
      final callId = await SipService.instance.makeCall(phoneNumber);
      if (callId != null) {
        // Navigate to call screen with the phone number
        NavigationService.goToInCall(callId, phoneNumber: phoneNumber);
        debugPrint(
            'RecentsScreen: Initiated call to $phoneNumber with callId: $callId');
      } else {
        debugPrint(
            'RecentsScreen: Failed to initiate call to $phoneNumber - callId is null');
      }
    } catch (e) {
      debugPrint('RecentsScreen: Error making call to $phoneNumber: $e');
    }
  }

  void _showCallDetails(CdrModel call) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCallDetailsSheet(call),
    );
  }

  Widget _buildCallDetailsSheet(CdrModel call) {
    final callType = CallHistoryService.getCallType(call);
    final style = _CallVisualStyle.fromCall(call, callType);
    final displayName = _getDisplayName(call, callType);
    final phoneNumber =
        call.remoteExt.isNotEmpty ? call.remoteExt : 'Unknown number';
    final isAnswered = _isAnswered(call);
    final status = isAnswered
        ? (_resolveDuration(call) ?? 'Connected')
        : _describeStatus(call, callType);
    final statusLabel = isAnswered ? 'Duration' : 'Status';
    final direction = call.incoming ? 'Incoming call' : 'Outgoing call';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: style.iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phoneNumber,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Date & time', _formatFullDateTime(call.madeAt)),
            _buildDetailRow('Direction', direction),
            _buildDetailRow(statusLabel, status),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (call.remoteExt.isNotEmpty) {
                        await _callNumber(call.remoteExt);
                      }
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      debugPrint(
                          'RecentsScreen: Add to contacts tapped for ${call.remoteExt}');
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add to contacts'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _callKey(CdrModel call) {
    return '${call.myCallId}_${call.madeAt.millisecondsSinceEpoch}_${call.incoming}_${call.remoteExt}_${call.duration}_${call.statusCode}';
  }

  String _getDisplayName(CdrModel call, CallType callType) {
    if (call.displName.isNotEmpty &&
        call.displName != call.remoteExt &&
        call.displName.toLowerCase() != 'unknown') {
      return call.displName;
    }

    if (call.remoteExt.isNotEmpty) {
      return call.remoteExt;
    }

    return 'Unknown caller';
  }

  String? _getStatusLabel(CdrModel call, CallType callType) {
    final answered = _isAnswered(call);
    if (call.incoming) {
      return answered ? null : 'Missed';
    }
    if (!answered) {
      return 'Not answered';
    }
    return null;
  }

  String _describeStatus(CdrModel call, CallType callType) {
    if (_isAnswered(call)) {
      return _resolveDuration(call) ?? 'Connected';
    }
    if (call.incoming) {
      return 'Missed call';
    }
    return 'Not answered';
  }

  bool _isAnswered(CdrModel call) {
    // A call is answered if it's connected OR has positive duration
    return call.connected || _hasPositiveDuration(call);
  }

  bool _hasPositiveDuration(CdrModel call) {
    final duration = call.duration.trim();
    if (duration.isEmpty) {
      return false;
    }

    final numeric = int.tryParse(duration);
    if (numeric != null) {
      return numeric > 0;
    }

    final segments = duration.split(':');
    if (segments.isEmpty) {
      return false;
    }

    int totalSeconds = 0;
    for (final segment in segments) {
      final part = int.tryParse(segment);
      if (part == null) {
        return false;
      }
      totalSeconds = totalSeconds * 60 + part;
    }
    return totalSeconds > 0;
  }

  String? _resolveDuration(CdrModel call) {
    final duration = call.duration.trim();
    if (duration.isEmpty) {
      return null;
    }

    final numeric = int.tryParse(duration);
    if (numeric != null) {
      if (numeric <= 0) {
        return null;
      }
      return _formatDurationAsHMS(duration);
    }

    return _hasPositiveDuration(call) ? duration : null;
  }

  String _formatDurationAsHMS(String duration) {
    try {
      // Duration comes as seconds, format as HH:MM:SS
      final seconds = int.tryParse(duration) ?? 0;
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final remainingSeconds = seconds % 60;

      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
      } else {
        return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '00:00';
    }
  }

  String _formatFullDateTime(DateTime dateTime) {
    final formatter = DateFormat('EEE, MMM d · h:mm a');
    return formatter.format(dateTime);
  }
}

class _CallVisualStyle {
  final Color iconColor;
  final Color backgroundColor;
  final IconData icon;

  const _CallVisualStyle({
    required this.iconColor,
    required this.backgroundColor,
    required this.icon,
  });

  static _CallVisualStyle fromCall(CdrModel call, CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return _CallVisualStyle(
          iconColor: AppTheme.primary,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          icon: Icons.call_received,
        );
      case CallType.outgoing:
        return _CallVisualStyle(
          iconColor: AppTheme.info,
          backgroundColor: AppTheme.info.withValues(alpha: 0.1),
          icon: Icons.call_made,
        );
      case CallType.missed:
        return _CallVisualStyle(
          iconColor: AppTheme.error,
          backgroundColor: AppTheme.error.withValues(alpha: 0.1),
          icon: Icons.call_missed_outgoing,
        );
    }
  }
}
