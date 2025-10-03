import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/sip_service.dart';
import '../../../../core/services/voicemail_service.dart';
import '../../data/models/voicemail_model.dart';

class VoicemailDetailsScreen extends StatefulWidget {
  final String voicemailId;
  const VoicemailDetailsScreen({super.key, required this.voicemailId});

  @override
  State<VoicemailDetailsScreen> createState() => _VoicemailDetailsScreenState();
}

class _VoicemailDetailsScreenState extends State<VoicemailDetailsScreen> {
  final VoicemailService _voicemailService = VoicemailService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  VoicemailModel? _voicemail;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _currentPosition = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVoicemail();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadVoicemail() {
    _voicemail = _voicemailService.getVoicemailByUuid(widget.voicemailId);
    if (_voicemail != null && _voicemail!.isUnread) {
      // Mark as read when opening
      _voicemailService.markAsRead(widget.voicemailId);
    }
    setState(() {});
  }

  Future<void> _toggleSaveVoicemail() async {
    if (_voicemail == null) return;

    try {
      if (_voicemail!.isSaved) {
        await _voicemailService.unsaveVoicemail(widget.voicemailId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voicemail unsaved')),
          );
        }
      } else {
        await _voicemailService.saveVoicemail(widget.voicemailId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voicemail saved')),
          );
        }
      }
      // Reload to get updated state
      _loadVoicemail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });

        // When playback completes, reset to beginning
        if (state.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      }
    });

    // Listen to position changes
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position.inSeconds.toDouble();
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer.processingState == ProcessingState.idle) {
      // First time playing - load the audio
      await _loadAudio();
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _loadAudio() async {
    if (_voicemail == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the access token
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      // Download the audio file using Dio with authentication
      final audioUrl = '${ApiService.instance.baseUrl}/listen_voice_mail?uuid=${_voicemail!.uuid}';
      debugPrint('VoicemailDetails: Downloading audio from: $audioUrl');

      final response = await ApiService.instance.getAuthenticated(
        '/listen_voice_mail',
        queryParameters: {'uuid': _voicemail!.uuid},
        options: Options(responseType: ResponseType.bytes),
      );

      if (response == null || response.data == null) {
        throw Exception('Failed to download voicemail audio');
      }

      // Save the audio bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/voicemail_${_voicemail!.uuid}.wav';
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(response.data as List<int>);

      debugPrint('VoicemailDetails: Audio saved to: $tempFilePath');

      // Set the audio source from the local file
      await _audioPlayer.setFilePath(tempFilePath);

      debugPrint('VoicemailDetails: Audio loaded successfully');
    } catch (e) {
      debugPrint('VoicemailDetails: Error loading audio: $e');
      setState(() {
        _errorMessage = 'Failed to load voicemail audio';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading voicemail: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteVoicemail() async {
    try {
      await _voicemailService.deleteVoicemail(widget.voicemailId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voicemail deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting voicemail: $e')),
        );
      }
    }
  }

  Future<void> _callBack() async {
    if (_voicemail == null) return;

    final phoneNumber = _voicemail!.fromUser;
    if (phoneNumber.isEmpty) return;

    try {
      final callId = await SipService.instance.makeCall(phoneNumber);
      if (callId != null && mounted) {
        NavigationService.goToInCall(
          callId,
          phoneNumber: phoneNumber,
          contactName: _voicemail!.fromName.isNotEmpty ? _voicemail!.fromName : null,
        );
      }
    } catch (e) {
      debugPrint('VoicemailDetails: Error making call to $phoneNumber: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_voicemail == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Voicemail not found'),
        ),
      );
    }

    final totalDuration = _voicemail!.duration.toDouble();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Voicemail',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteVoicemail,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Caller info
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _voicemail!.displayName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _voicemail!.fromUser,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(_voicemail!.created),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Audio player card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Play/Pause button
                    GestureDetector(
                      onTap: _isLoading ? null : _togglePlayPause,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isLoading
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                              : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress bar
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor:
                                Theme.of(context).colorScheme.primary,
                            inactiveTrackColor: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.2),
                            thumbColor: Theme.of(context).colorScheme.primary,
                            overlayColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _currentPosition.clamp(0.0, totalDuration),
                            min: 0,
                            max: totalDuration > 0 ? totalDuration : 1,
                            onChanged: _isLoading
                                ? null
                                : (value) async {
                                    setState(() {
                                      _currentPosition = value;
                                    });
                                    await _audioPlayer.seek(Duration(seconds: value.toInt()));
                                  },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatTime(_currentPosition),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              Text(
                                _formatTime(totalDuration),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callBack,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleSaveVoicemail,
                      icon: Icon(_voicemail?.isSaved == true ? Icons.bookmark : Icons.bookmark_border),
                      label: Text(_voicemail?.isSaved == true ? 'Saved' : 'Save'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(1, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}
