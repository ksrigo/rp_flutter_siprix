# siprix_voip_sdk_macos

The MacOS implementation of [`siprix_voip_sdk`][1].

Siprix VoIP SDK plugin for embedding voice and video communication (based on SIP/RTP protocols) into Flutter applications.

Plugin implements ready to use SIP VoIP Client with ability to:
- Add multiple SIP accounts
- Send/receive multiple calls (Audio and Video)
- Manage calls with: hold, mute microphone/camera, play sound to call from file, send/receive DTMF,...
- Join calls to conference, blind and attended transfer
- Secure SIP signaling (using TLS) and call media (using SRTP)
- Detect network changes and automatically update registration/switch and restore call(s) media
- Echo cancelation and noise suppression
- Create BLF/Presence subscriptions and monitor state of remote extension(s)

## Usage

This package is [endorsed][2], which means you can simply use `siprix_voip_sdk`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.


[1]: https://pub.dev/packages/siprix_voip_sdk
[2]: https://flutter.dev/to/endorsed-federated-plugin
