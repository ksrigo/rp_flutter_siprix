import 'package:siprix_voip_sdk_platform_interface/siprix_voip_sdk_platform_interface.dart';

//////////////////////////////////////////////////////////////////////////////////////////
//SiprixVoipSdkWindows implementation

class SiprixVoipSdkWindows extends SiprixVoipSdkPlatform {
  static void registerWith() {
    SiprixVoipSdkPlatform.instance = SiprixVoipSdkWindows();
  }
}
