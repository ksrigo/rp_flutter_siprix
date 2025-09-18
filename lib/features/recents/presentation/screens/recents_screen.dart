import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';

import '../../../../core/services/call_history_service.dart';
import '../../../../core/services/navigation_service.dart';

class RecentsScreen extends ConsumerStatefulWidget {
  const RecentsScreen({super.key});

  @override
  ConsumerState<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends ConsumerState<RecentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeCallHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeCallHistory() async {
    try {
      if (!CallHistoryService.instance.isInitialized) {
        await CallHistoryService.instance.initialize();
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('RecentsScreen: Error initializing call history: $e');
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildTabBarView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: const Text(
        'Recents',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(2),
        labelColor: const Color(0xFF6B46C1),
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Missed'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return AnimatedBuilder(
      animation: CallHistoryService.instance,
      builder: (context, child) {
        return TabBarView(
          controller: _tabController,
          children: [
            _buildCallList(CallHistoryService.instance.getAllCalls()),
            _buildCallList(CallHistoryService.instance.getMissedCalls()),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)),
      ),
    );
  }

  Widget _buildCallList(List<CdrModel> calls) {
    if (calls.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: calls.length,
      itemBuilder: (context, index) {
        return _buildCallItem(calls[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No recent calls',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallItem(CdrModel call) {
    final callType = CallHistoryService.getCallType(call);
    final displayName = _getDisplayName(call);
    final phoneNumber = call.remoteExt;
    final timeText = CallHistoryService.formatCallTime(call.madeAt);
    final durationText = CallHistoryService.formatDuration(call.duration);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildCallTypeIcon(callType),
        title: Text(
          displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$timeText${call.connected && call.duration.isNotEmpty ? ' • $durationText' : ''}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.info_outline,
            color: Color(0xFF6B7280),
            size: 20,
          ),
          onPressed: () => _showCallDetails(call),
        ),
        onTap: () => _callNumber(phoneNumber),
      ),
    );
  }

  Widget _buildCallTypeIcon(CallType callType) {
    Color iconColor;
    Color backgroundColor;
    IconData iconData;

    switch (callType) {
      case CallType.incoming:
        iconColor = const Color(0xFF6B46C1);
        backgroundColor = const Color(0xFFE0E7FF);
        iconData = Icons.call_received;
        break;
      case CallType.outgoing:
        iconColor = const Color(0xFF6B46C1);
        backgroundColor = const Color(0xFFE0E7FF);
        iconData = Icons.call_made;
        break;
      case CallType.missed:
        iconColor = const Color(0xFFEF4444);
        backgroundColor = const Color(0xFFFEE2E2);
        iconData = Icons.call_received;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  String _getDisplayName(CdrModel call) {
    if (call.displName.isNotEmpty && 
        call.displName != call.remoteExt && 
        call.displName.toLowerCase() != 'unknown') {
      return call.displName;
    }
    
    if (call.remoteExt.isNotEmpty) {
      return call.remoteExt;
    }
    
    return 'Unknown';
  }

  void _callNumber(String phoneNumber) {
    if (phoneNumber.isNotEmpty) {
      NavigationService.goToKeypad();
      // TODO: Auto-fill the keypad with the phone number
      debugPrint('RecentsScreen: Calling $phoneNumber');
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
    final displayName = _getDisplayName(call);
    final timeText = CallHistoryService.formatCallTime(call.madeAt);
    final durationText = CallHistoryService.formatDuration(call.duration);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCallTypeIcon(callType),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            call.remoteExt,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Time', timeText),
                if (call.connected && call.duration.isNotEmpty)
                  _buildDetailRow('Duration', durationText),
                _buildDetailRow('Type', _getCallTypeText(callType)),
                _buildDetailRow('Status', call.connected ? 'Connected' : 'Not connected'),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _callNumber(call.remoteExt);
                        },
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B46C1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Add to contacts functionality
                      },
                      icon: const Icon(Icons.person_add),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCallTypeText(CallType callType) {
    switch (callType) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
    }
  }
}