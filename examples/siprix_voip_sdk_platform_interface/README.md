# siprix_voip_sdk_platform_interface

A common platform interface for the [`siprix_voip_sdk`][1] plugin.

This interface allows platform-specific implementations of the `siprix_voip_sdk`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

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

[1]: https://pub.dev/packages/siprix_voip_sdk