import 'package:siprix_voip_sdk_platform_interface/siprix_voip_sdk_platform_interface.dart';

//////////////////////////////////////////////////////////////////////////////////////////
//SiprixVoipSdkIos implementation

class SiprixVoipSdkIos extends SiprixVoipSdkPlatform {
  static void registerWith() {
    SiprixVoipSdkPlatform.instance = SiprixVoipSdkIos();
  }
}
