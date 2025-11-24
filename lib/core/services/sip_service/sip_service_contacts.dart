part of 'sip_service_base.dart';

mixin _SipServiceContacts on _SipServiceBase {
  @override
  String _resolveContactNameForCallKit(String extension) {
    try {
      debugPrint('🔥 SIP Service: CALLBACK TRIGGERED - Resolving contact name for CallKit display: "$extension"');

      // Get cached caller information (parsed using builtin SDK functions)
      final callerInfo = _getCachedCallerInfo(extension);
      final callerName = callerInfo['name']!;
      final callerNumber = callerInfo['number']!;

      debugPrint('🔥 SIP Service: Parsed for CallKit - name: "$callerName", number: "$callerNumber"');

      // Return the name if it's meaningful, otherwise return the number
      String result;
      if (callerName != 'Unknown' && callerName != callerNumber) {
        result = callerName;
        debugPrint('🔥 SIP Service: Returning caller name for CallKit: "$result"');
      } else {
        result = callerNumber;
        debugPrint('🔥 SIP Service: Returning caller number for CallKit: "$result"');
      }
      return result;
    } catch (e) {
      debugPrint('🔥 SIP Service: Error resolving contact name: $e');
      return extension; // Return original if there's an error
    }
  }
}
