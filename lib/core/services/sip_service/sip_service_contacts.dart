part of 'sip_service_base.dart';

mixin _SipServiceContacts on _SipServiceBase {
  String _resolveContactNameForCallKit(String extension) {
    try {
      debugPrint(
          '🔥 SIP Service: CALLBACK TRIGGERED - Resolving contact name for CallKit display: "$extension"');

      // Use our existing parsing logic to handle full SIP headers
      final callerInfo = _parseCallerInfo(extension);
      final callerName = callerInfo['name'] ?? 'Unknown';
      final callerNumber = callerInfo['number'] ?? 'Unknown';

      debugPrint(
          '🔥 SIP Service: Parsed for CallKit - name: "$callerName", number: "$callerNumber"');

      // Return the name if it's meaningful, otherwise return the number
      String result;
      if (callerName != 'Unknown' && callerName != callerNumber) {
        result = callerName;
        debugPrint(
            '🔥 SIP Service: Returning caller name for CallKit: "$result"');
      } else {
        result = callerNumber;
        debugPrint(
            '🔥 SIP Service: Returning caller number for CallKit: "$result"');
      }

      return result;

      // Future enhancement: integrate with ContactService
      // final contactInfo = await ContactService.instance.findContactByPhoneNumber(callerNumber);
      // if (contactInfo != null && contactInfo.displayName != callerNumber) {
      //   return contactInfo.displayName;
      // }
    } catch (e) {
      debugPrint('🔥 SIP Service: Error resolving contact name: $e');
      return extension; // Return original if there's an error
    }
  }

  // Update built-in Siprix CallKit display with clean caller information
  Future<void> _updateSiprixCallKitDisplay(
      int callId, String callerName, String callerNumber) async {
    if (_siprixSdk == null) return;

    try {
      // Determine the display name: use caller name if available, otherwise number
      final displayName = callerName.isNotEmpty && callerName != 'Unknown'
          ? callerName
          : callerNumber;

      debugPrint(
          'SIP Service: Updating Siprix CallKit display - Name: $displayName, Handle: $callerNumber');

      // Note: For incoming calls, we may need to get the CallKit UUID from Siprix
      // For now, let's try with an empty string as the UUID and let Siprix manage it
      await _siprixSdk!.updateCallKitCallDetails(
        "", // CallKit UUID - let Siprix manage this internally
        callId, // SIP call ID
        displayName, // Caller name to display
        callerNumber, // Phone number handle
        false, // Not a video call
      );

      debugPrint('SIP Service: Siprix CallKit display updated successfully');
    } catch (e) {
      debugPrint('SIP Service: Failed to update Siprix CallKit display: $e');
    }
  }
}
