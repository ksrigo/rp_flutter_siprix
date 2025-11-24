// In your network_providers.dart file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../sip_service/sip_service_base.dart';

// Provider for SipService instance
final sipServiceProvider = Provider<SipService>((ref) {
  return SipService.instance;
});

// StateNotifier to track connection status
class ConnectionStatusNotifier extends StateNotifier<String> {
  final SipService sipService;

  ConnectionStatusNotifier(this.sipService) : super('unknown') {
    // Listen to SipService changes
    sipService.addListener(_updateStatus);
    _updateStatus();
  }

  void _updateStatus() {
    final hasNetwork = sipService.hasNetworkConnectivity;
    final isRegistered = sipService.isRegistered;

    if (!hasNetwork) {
      state = 'no_network';
    } else if (!isRegistered) {
      state = 'not_registered';
    } else {
      state = 'online';
    }
  }

  @override
  void dispose() {
    sipService.removeListener(_updateStatus);
    super.dispose();
  }
}

final connectionStatusProvider = StateNotifierProvider<ConnectionStatusNotifier, String>((ref) {
  final sipService = ref.watch(sipServiceProvider);
  return ConnectionStatusNotifier(sipService);
});