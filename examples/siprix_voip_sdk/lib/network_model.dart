import 'package:flutter/material.dart';

import 'siprix_voip_sdk.dart';


/// SipTransport enum. Using as argument of 'AccountModel.transport'
enum SipTransport {
  ///Send SIP over UDP transport
  udp(SiprixVoipSdk.kSipTransportUdp, "UDP"),
  ///Send SIP over TCP transport
  tcp(SiprixVoipSdk.kSipTransportTcp, "TCP"),
  ///Send SIP over TLS transport
  tls(SiprixVoipSdk.kSipTransportTls, "TLS");

  const SipTransport(this.id, this.name);
  /// Value
  final int id;
  /// User friendly name of the selected option
  final String name;

  ///Create enum item from int value
  static SipTransport from(int val) {
    switch(val) {
      case SiprixVoipSdk.kSipTransportTcp: return SipTransport.tcp;
      case SiprixVoipSdk.kSipTransportTls: return SipTransport.tls;
      default:  return SipTransport.udp;
    }
  }
}


/// Network state enum. Using as argument of event 'onNetworkStateChanged'
enum NetState {
  /// Network connection lost
  lost(SiprixVoipSdk.kNetStateLost, "Lost"),
  /// Network connection restored
  restored(SiprixVoipSdk.kNetStateRestored, "Restored"),
  /// Network connection switched (from Wifi to Wifi or from Wifi to LTE)
  switched(SiprixVoipSdk.kNetStateSwitched, "Switched");

  const NetState(this.id, this.name);
  /// Value
  final int id;
  /// User friendly name of the selected option
  final String name;

  ///Create enum item from int value
  static NetState from(int val) {
    switch(val) {
      case SiprixVoipSdk.kNetStateRestored:  return NetState.restored;
      case SiprixVoipSdk.kNetStateSwitched:  return NetState.switched;
      default: return  NetState.lost;
    }
  }
}


/// NetworkModel - contains network
class NetworkModel extends ChangeNotifier {
  bool _networkLost = false;
  final ILogsModel? _logs;

  ///Is network connection lost (using for displaying some indicator on UI)
  bool get networkLost => _networkLost;

  /// Constructor (set event handler)
  NetworkModel([this._logs]) {
    SiprixVoipSdk().netListener = NetStateListener(
      networkStateChanged : onNetworkStateChanged
    );
  }

  /// Handle notification raised by library when detected network changes
  void onNetworkStateChanged(String name, NetState state) {
    _logs?.print('onNetworkStateChanged name:$name $state');
    _networkLost = (state==NetState.lost);
    notifyListeners();
  }

}//NetworkModel