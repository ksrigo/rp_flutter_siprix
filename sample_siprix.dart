import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:siprix_voip_sdk/siprix_voip_sdk.dart';
import 'package:siprix_voip_sdk/accounts_model.dart';
import 'package:siprix_voip_sdk/calls_model.dart';

enum SipRegistrationStatus {
  notRegistered,
  registering,
  registered,
  registrationFailed,
}

enum CallState { idle, calling, proceeding, connected, ended }

class ActiveCall {
  final int callId;
  final String contactName;
  final String contactNumber;
  final CallState state;
  final DateTime startTime;

  const ActiveCall({
    required this.callId,
    required this.contactName,
    required this.contactNumber,
    required this.state,
    required this.startTime,
  });

  ActiveCall copyWith({
    int? callId,
    String? contactName,
    String? contactNumber,
    CallState? state,
    DateTime? startTime,
  }) {
    return ActiveCall(
      callId: callId ?? this.callId,
      contactName: contactName ?? this.contactName,
      contactNumber: contactNumber ?? this.contactNumber,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
    );
  }
}

class SipCredentials {
  final String name;
  final String extension;
  final String password;
  final String realm;
  final String outboundProxy;

  const SipCredentials({
    required this.name,
    required this.extension,
    required this.password,
    required this.realm,
    required this.outboundProxy,
  });

  // Hardcoded dummy credentials for now
  static const SipCredentials dummy = SipCredentials(
    name: 'Ravi',
    extension: '1002',
    password: '1Z(OeDvN9dt0(f',
    realm: '408708399.ringplus.co.uk',
    outboundProxy: 'proxy.ringplus.co.uk:5060',
  );
}

class SipService with ChangeNotifier {
  static final SipService _instance = SipService._internal();
  factory SipService() => _instance;
  SipService._internal() {
    // Don't initialize models here - let initialize() handle it
    // This allows proper reinitializing after disposal

    // Set up listeners for registration state changes
    _setupListeners();
  }

  AccountsModel? _accountsModel;
  CallsModel? _callsModel;
  final SiprixVoipSdk _sdk = SiprixVoipSdk();

  SipRegistrationStatus _registrationStatus =
      SipRegistrationStatus.notRegistered;
  String? _errorMessage;
  SipCredentials? _currentCredentials;
  int? _accountId; // Changed from accountIndex to accountId for SDK ID
  int? _accountIndex; // Keep track of array index separately
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Call state management
  ActiveCall? _activeCall;
  final StreamController<ActiveCall?> _callStateController =
      StreamController<ActiveCall?>.broadcast();

  // Getters
  SipRegistrationStatus get registrationStatus => _registrationStatus;
  String? get errorMessage => _errorMessage;
  SipCredentials? get currentCredentials => _currentCredentials;
  bool get isRegistered =>
      _registrationStatus == SipRegistrationStatus.registered;
  AccountsModel? get accountsModel => _accountsModel;
  CallsModel? get callsModel => _callsModel;
  ActiveCall? get activeCall => _activeCall;
  Stream<ActiveCall?> get callStateStream => _callStateController.stream;

  /// Set up listeners for registration state changes
  void _setupListeners() {
    // Try different listener approach - use the AccountsModel listener instead
    debugPrint('Setting up account state listeners...');
  }

  /// Set up AccountsModel listeners after models are created
  void _setupAccountModelListeners() {
    if (_accountsModel != null) {
      debugPrint('Setting up AccountsModel listener...');
      _accountsModel!.addListener(() {
        debugPrint('AccountsModel listener triggered');
        _checkAccountRegistrationStatus();
      });
    }

    // Set up CallsModel listener for call state changes
    if (_callsModel != null) {
      debugPrint('Setting up CallsModel listener...');
      _callsModel!.addListener(() {
        debugPrint('CallsModel listener triggered');
        _checkCallStates();
      });
    }
  }

  /// Check current call states from CallsModel
  void _checkCallStates() {
    if (_callsModel == null) return;

    try {
      // Check if there are any active calls
      if (_callsModel!.length > 0) {
        final call = _callsModel![0]; // Get first call
        debugPrint('Call state check for call ${call.myCallId}');

        // Check call properties for state - using available properties from Siprix SDK
        if (_activeCall == null || _activeCall!.callId != call.myCallId) {
          _activeCall = ActiveCall(
            callId: call.myCallId,
            contactName: call.nameAndExt,
            contactNumber: call.nameAndExt,
            state: CallState.proceeding, // Start with proceeding state
            startTime: DateTime.now(),
          );
          _callStateController.add(_activeCall);
          notifyListeners();
          debugPrint('Active call created for call ${call.myCallId}');
        }
      } else if (_activeCall != null) {
        // No calls in the model, clear active call
        debugPrint('No active calls, clearing call state');
        _activeCall = null;
        _callStateController.add(null);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking call states: $e');
    }
  }

  /// Check current registration status from AccountsModel
  void _checkAccountRegistrationStatus() {
    if (_accountsModel == null || _accountIndex == null) return;

    try {
      final account = _accountsModel![_accountIndex!];
      debugPrint(
        'Checking account status: ${account.regState} for ${account.uri}',
      );

      switch (account.regState) {
        case RegState.success:
          if (_registrationStatus != SipRegistrationStatus.registered) {
            debugPrint('Account registered successfully!');
            _updateRegistrationStatus(SipRegistrationStatus.registered);
            _errorMessage = null;
          }
          break;
        case RegState.failed:
          if (_registrationStatus != SipRegistrationStatus.registrationFailed) {
            debugPrint('Account registration failed!');
            _updateRegistrationStatus(SipRegistrationStatus.registrationFailed);
            _errorMessage = 'Registration failed: ${account.regText}';
          }
          break;
        case RegState.inProgress:
          if (_registrationStatus != SipRegistrationStatus.registering) {
            debugPrint('Account registration in progress...');
            _updateRegistrationStatus(SipRegistrationStatus.registering);
          }
          break;
        case RegState.removed:
          if (_registrationStatus != SipRegistrationStatus.notRegistered) {
            debugPrint('Account registration removed');
            _updateRegistrationStatus(SipRegistrationStatus.notRegistered);
          }
          break;
      }
    } catch (e) {
      debugPrint('Error checking account status: $e');
    }
  }

  /// Initialize the SIP SDK and recreate models if needed
  Future<bool> initialize() async {
    try {
      // Fix Issue 1: Reinitialize AccountsModel if disposed
      if (_isDisposed || _accountsModel == null) {
        debugPrint(
          'Reinitializing AccountsModel and CallsModel after disposal',
        );
        _accountsModel = AccountsModel();
        _callsModel = CallsModel(_accountsModel!);
        _isDisposed = false;
      }

      if (_isInitialized) return true;

      // Create initialization data
      final initData = InitData();
      initData.license = ""; // Empty license for trial mode

      // Initialize the SDK
      await _sdk.initialize(initData);
      _isInitialized = true;

      debugPrint('Siprix VoIP SDK initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize Siprix VoIP SDK: $e');
      _errorMessage = 'Failed to initialize SIP: $e';
      notifyListeners();
      return false;
    }
  }

  /// Register with SIP server using provided credentials
  Future<bool> register(SipCredentials credentials) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      _currentCredentials = credentials;
      _updateRegistrationStatus(SipRegistrationStatus.registering);

      // build account object
      AccountModel account = AccountModel();
      account.sipServer = credentials.realm;
      account.sipExtension = credentials.extension;
      account.sipPassword = credentials.password;
      account.expireTime = 120;
      account.sipProxy = credentials.outboundProxy;
      account.sipAuthId = credentials.extension;
      account.port = 5060;

      // Add account (await it)
      await _accountsModel!.addAccount(account);

      // Find index of the account we just added by matching URI (public API)
      _accountIndex = null;
      for (int i = 0; i < _accountsModel!.length; i++) {
        final a = _accountsModel![i]; // operator[] is public
        if (a.uri == account.uri) {
          _accountIndex = i;
          break;
        }
      }

      if (_accountIndex == null) {
        debugPrint('Could not find newly added account in AccountsModel');
        _updateRegistrationStatus(SipRegistrationStatus.registrationFailed);
        return false;
      }

      debugPrint('New account index: $_accountIndex');

      // Get the internal SDK accountId for listener comparison
      _accountId = _accountsModel!.getAccId(account.uri);
      debugPrint('New account SDK ID: $_accountId');

      // Register the account explicitly
      await _accountsModel!.registerAccount(_accountIndex!);

      // Set selected account by ID
      _accountsModel!.setSelectedAccountById(_accountId!);

      // Set up AccountsModel listener now that account is added
      _setupAccountModelListeners();

      // registration state updates will come via the model listeners
      return true;
    } catch (e) {
      debugPrint('SIP registration failed: $e');
      _errorMessage = 'Registration failed: $e';
      _updateRegistrationStatus(SipRegistrationStatus.registrationFailed);
      return false;
    }
  }

  /// Make a call to the specified number
  Future<bool> makeCall(String number) async {
    if (!isRegistered) {
      _errorMessage = 'Not registered. Cannot make call.';
      notifyListeners();
      return false;
    }

    if (_accountId == null || _callsModel == null) {
      _errorMessage = 'No active account. Cannot make call.';
      notifyListeners();
      return false;
    }

    try {
      final destination = CallDestination(number, _accountId!, false);
      await _callsModel!.invite(destination);

      // Create initial active call
      _activeCall = ActiveCall(
        callId: 0, // Will be updated when we get the actual call ID
        contactName: number,
        contactNumber: number,
        state: CallState.calling,
        startTime: DateTime.now(),
      );
      _callStateController.add(_activeCall);
      notifyListeners();

      debugPrint('Call initiated to number: $number');
      return true;
    } catch (e) {
      debugPrint('Failed to make call: $e');
      _errorMessage = 'Failed to make call: $e';
      notifyListeners();
      return false;
    }
  }

  /// Answer incoming call
  Future<bool> answerCall(int callId) async {
    try {
      await _sdk.accept(callId, false);
      debugPrint('Call answered: $callId');
      return true;
    } catch (e) {
      debugPrint('Failed to answer call: $e');
      _errorMessage = 'Failed to answer call: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hangup call
  Future<bool> hangupCall(int callId) async {
    try {
      await _sdk.bye(callId);
      debugPrint('Call hung up: $callId');
      return true;
    } catch (e) {
      debugPrint('Failed to hangup call: $e');
      _errorMessage = 'Failed to hangup call: $e';
      notifyListeners();
      return false;
    }
  }

  /// Unregister and cleanup
  Future<void> unregister() async {
    try {
      debugPrint("accountIndex: $_accountIndex, accountId: $_accountId");
      if (_accountIndex != null && _accountsModel != null) {
        try {
          final account = _accountsModel![_accountIndex!];

          debugPrint(
            "Unregistering account: ${account.sipExtension}@${account.sipServer}",
          );

          // Try to unregister (sends SIP unREGISTER if registered)
          await _accountsModel!.unregisterAccount(_accountIndex!);
          debugPrint("SIP unREGISTER attempted");

          // Now delete the account locally
          await _accountsModel!.deleteAccount(_accountIndex!);
          debugPrint('Account deleted successfully');
        } catch (e) {
          debugPrint('Account deletion/unregister failed: $e');
        }

        _accountIndex = null;
        _accountId = null;
      }

      _currentCredentials = null;
      _updateRegistrationStatus(SipRegistrationStatus.notRegistered);
      debugPrint('SIP account unregistered (local state reset)');
    } catch (e) {
      debugPrint('Error during unregistration: $e');
      _accountIndex = null;
      _accountId = null;
      _currentCredentials = null;
      _updateRegistrationStatus(SipRegistrationStatus.notRegistered);
    }
  }

  /// Dispose resources
  // @override
  // Future<void> dispose() async {
  //   await unregister();
  //   try {
  //     if (_isInitialized) {
  //       _sdk.unInitialize(null);
  //       _isInitialized = false;
  //     }
  //     debugPrint('Siprix VoIP SDK uninitialized');
  //   } catch (e) {
  //     debugPrint('Error uninitializing Siprix VoIP SDK: $e');
  //   }
  //   super.dispose();
  // }

  /// Fully cleanup and shutdown the Siprix SDK
  Future<void> disposeSdk() async {
    try {
      // Remove the registration state listener
      _sdk.accListener = null;

      // Unregister the account (if any)
      await unregister();

      // Mark as disposed but don't dispose immediately
      // This allows reinitialize to work when user logs back in
      if (_accountsModel != null) {
        _accountsModel!.dispose(); // stops listeners/timers
        _accountsModel = null; // Clear reference
        _callsModel = null; // Clear reference
        debugPrint("AccountsModel disposed");
      }

      _isDisposed = true;

      // Fully uninitialize the SDK
      if (_isInitialized) {
        _sdk.unInitialize(
          null,
        ); // stops all transports, timers, and background tasks
        _isInitialized = false;
        debugPrint("Siprix VoIP SDK uninitialized");
      }
    } catch (e) {
      debugPrint("Error during disposeSdk: $e");

      // Always reset state even on error
      _accountIndex = null;
      _accountId = null;
      _currentCredentials = null;
      _isInitialized = false;
      _isDisposed = true;
      _accountsModel = null;
      _callsModel = null;
    }
  }

  // Private methods
  void _updateRegistrationStatus(SipRegistrationStatus status) {
    debugPrint('_updateRegistrationStatus: $_registrationStatus -> $status');
    _registrationStatus = status;
    debugPrint('Calling notifyListeners()...');
    notifyListeners();
    debugPrint('notifyListeners() completed');
  }
}
