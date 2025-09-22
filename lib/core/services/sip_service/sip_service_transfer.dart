part of 'sip_service_base.dart';

mixin _SipServiceTransfer on _SipServiceBase {
  Future<void> transferCall(String callId, String target) async {
    try {
      debugPrint('Transfer call: $callId to $target');
      // TODO: Implement with correct Siprix API
    } catch (e) {
      debugPrint('Transfer call failed: $e');
    }
  }
}
