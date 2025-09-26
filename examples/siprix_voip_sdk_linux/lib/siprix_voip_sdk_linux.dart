import 'package:siprix_voip_sdk_platform_interface/siprix_voip_sdk_platform_interface.dart';

//////////////////////////////////////////////////////////////////////////////////////////
//SiprixVoipSdkLinux implementation

class SiprixVoipSdkLinux extends SiprixVoipSdkPlatform {
  static void registerWith() {
    SiprixVoipSdkPlatform.instance = SiprixVoipSdkLinux();
  }
}
