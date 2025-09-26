import 'package:siprix_voip_sdk_platform_interface/siprix_voip_sdk_platform_interface.dart';

//////////////////////////////////////////////////////////////////////////////////////////
//SiprixVoipSdkMacos implementation

class SiprixVoipSdkMacos extends SiprixVoipSdkPlatform {
  static void registerWith() {
    SiprixVoipSdkPlatform.instance = SiprixVoipSdkMacos();
  }
}
