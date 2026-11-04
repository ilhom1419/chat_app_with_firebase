import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../core/security/screen_protector_service.dart';
import '../../domain/entities/secret_message.dart';
import '../../domain/entities/secret_media_payload.dart';
import '../../data/services/secret_media_crypto_service.dart';
import '../bloc/secret_chat_bloc.dart';
import '../bloc/secret_chat_event.dart';
import '../bloc/secret_chat_state.dart';

class SecretChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const SecretChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<SecretChatPage> createState() => _SecretChatPageState();
}

class _SecretChatPageState extends State<SecretChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  Timer? _expirationTicker;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _voiceDuration = 0;
  Timer? _voiceTimer;
  String? _currentVoicePath;

  @override
  void initState() {
    super.initState();
    ScreenProtectorService.enableSecure();
    WidgetsBinding.instance.addObserver(this);
    final bloc = context.read<SecretChatBloc>();
    bloc.add(LoadSecretChatSession(widget.chatId));
    bloc.add(const CheckSessionStatus());
  }

  @override
  void dispose() {
    ScreenProtectorService.disableSecure();
    WidgetsBinding.instance.removeObserver(this);
    _expirationTicker?.cancel();
    _voiceTimer?.cancel();
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ScreenProtectorService.reapplyIfActive();
      final chatState = context.read<SecretChatBloc>().state;
      if (chatState is SecretChatActive) {
        _checkAndMarkUnreadMessages(chatState.messages);
        _manageExpirationTicker(chatState.messages);
      }
    }
  }

  void _checkAndMarkUnreadMessages(List<SecretMessage> messages) {
    if (!mounted) return;
    for (final m in messages) {
      if (!m.isOutgoing && !m.isRead && m.isDecrypted) {
        context.read<SecretChatBloc>().add(
              MarkSecretMessageRead(
                chatId: widget.chatId,
                messageId: m.messageId,
              ),
            );
      }
    }
  }

  void _manageExpirationTicker(List<SecretMessage> messages) {
    final hasExpiring = messages.any((m) => m.isCountdownActive);

    if (hasExpiring) {
      if (_expirationTicker == null || !_expirationTicker!.isActive) {
        _expirationTicker =
            Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final state = context.read<SecretChatBloc>().state;
          if (state is! SecretChatActive) return;

          bool hasActive = false;
          for (final m in state.messages) {
            if (m.selfDestructDuration > 0 && m.isRead) {
              if (m.isExpired) {
                context.read<SecretChatBloc>().add(
                      DeleteSecretMessage(
                        chatId: widget.chatId,
                        messageId: m.messageId,
                      ),
                    );
              } else {
                hasActive = true;
              }
            }
          }

          if (hasActive) {
            setState(() {});
          } else {
            timer.cancel();
            _expirationTicker = null;
          }
        });
      }
    } else {
      _expirationTicker?.cancel();
      _expirationTicker = null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    context.read<SecretChatBloc>().add(SendSecretMessage(text));
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile == null || !mounted) return;

      final bytes = await pickedFile.readAsBytes();
      if (bytes.length > SecretMediaCryptoService.maxMediaSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate('media_too_large')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        context.read<SecretChatBloc>().add(
              SendSecretImage(
                imageBytes: bytes,
              ),
            );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.green),
              title: Text(LocalizationService.translate('pick_image')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.green),
              title: Text(LocalizationService.translate('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate('mic_permission_required')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/secret_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentVoicePath = path;

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      if (mounted) {
        setState(() {
          _isRecordingVoice = true;
          _voiceDuration = 0;
        });

        _voiceTimer?.cancel();
        _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            _voiceDuration++;
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _voiceTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}

    if (_currentVoicePath != null) {
      try {
        final f = File(_currentVoicePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      _currentVoicePath = null;
    }

    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _voiceDuration = 0;
      });
    }
  }

  Future<void> _finishAndSendVoiceRecording() async {
    _voiceTimer?.cancel();
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {}

    final finalPath = path ?? _currentVoicePath;
    final duration = _voiceDuration;

    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _voiceDuration = 0;
      });
    }

    if (finalPath != null) {
      final file = File(finalPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // Immediately delete temporary local file
        await file.delete();

        if (bytes.isNotEmpty && mounted) {
          context.read<SecretChatBloc>().add(
                SendSecretVoice(
                  audioBytes: bytes,
                  durationSeconds: duration > 0 ? duration : 1,
                ),
              );
          _scrollToBottom();
        }
      }
    }
    _currentVoicePath = null;
  }

  void _showSafetyNumberSheet(BuildContext context, String? safetyNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (safetyNumber == null || safetyNumber.isEmpty) {
      context.read<SecretChatBloc>().add(const LoadSafetyNumber());
    }

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return BlocBuilder<SecretChatBloc, SecretChatState>(
          builder: (context, state) {
            String? number = safetyNumber;
            if (state is SecretChatActive) {
              number = state.safetyNumber ?? number;
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user,
                              color: Colors.green, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.translate(
                                    'safety_number_title'),
                                style: AppTextStyles.h2().copyWith(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                LocalizationService.translate(
                                    'safety_number_verified'),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LocalizationService.translate('safety_number_desc'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.25),
                        ),
                      ),
                      child: number != null && number.isNotEmpty
                          ? Text(
                              number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                height: 1.6,
                              ),
                            )
                          : const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LocalizationService.translate('fingerprint_warning'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LocalizationService.translate(
                                      'screenshot_protection_badge'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  LocalizationService.translate(
                                      'screenshot_protection_desc'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(
                              LocalizationService.translate(
                                  'safety_number_copy'),
                            ),
                            onPressed: (number != null && number.isNotEmpty)
                                ? () {
                                    Clipboard.setData(
                                        ClipboardData(text: number!));
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          LocalizationService.translate(
                                              'safety_number_copied'),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTimerPicker(BuildContext context, int currentDuration) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      {'label': LocalizationService.translate('timer_off'), 'seconds': 0},
      {'label': LocalizationService.translate('timer_5s'), 'seconds': 5},
      {'label': LocalizationService.translate('timer_1m'), 'seconds': 60},
      {'label': LocalizationService.translate('timer_1h'), 'seconds': 3600},
    ];

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    LocalizationService.translate('auto_delete'),
                    style: AppTextStyles.h2().copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                ...options.map((opt) {
                  final sec = opt['seconds'] as int;
                  final isSelected = sec == currentDuration;
                  return ListTile(
                    leading: Icon(
                      sec == 0
                          ? Icons.timer_off_outlined
                          : Icons.timer_outlined,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                    title: Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<SecretChatBloc>().add(
                            ChangeSelfDestructTimer(
                              chatId: widget.chatId,
                              durationInSeconds: sec,
                            ),
                          );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmTermination(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('terminate_secret_chat')),
        content:
            Text(LocalizationService.translate('terminate_secret_chat_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<SecretChatBloc>()
                  .add(TerminateSecretChatSession(widget.chatId));
            },
            child: Text(
              LocalizationService.translate('terminate'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<SecretChatBloc, SecretChatState>(
      listener: (context, state) {
        if (state is SecretChatTerminated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService.translate('secret_chat_terminated_msg'),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (state is SecretChatError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is SecretChatActive) {
          if (state.sendError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.sendError!),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state.messages.length != _lastMessageCount) {
            _lastMessageCount = state.messages.length;
            _scrollToBottom();
          }

          // Automatically check and mark unread incoming messages once decrypted
          _checkAndMarkUnreadMessages(state.messages);

          // Manage self-destruct periodic countdown ticker
          _manageExpirationTicker(state.messages);
        }
      },
      builder: (context, state) {
        int duration = 0;
        bool isTerminated = false;
        bool isSessionEstablished = false;
        List<SecretMessage> messages = [];
        bool isSending = false;
        String? safetyNumber;

        if (state is SecretChatActive) {
          duration = state.session.selfDestructDuration;
          isTerminated = state.session.isTerminated;
          isSessionEstablished = state.isSessionEstablished;
          // Filter out expired messages
          messages = state.messages.where((m) => !m.isExpired).toList();
          isSending = state.isSending;
          safetyNumber = state.safetyNumber;
        } else if (state is SecretChatTerminated) {
          isTerminated = true;
        }

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 1,
            leading: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade400,
                      child: Text(
                        widget.otherUserName.isNotEmpty
                            ? widget.otherUserName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 6,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.lock, size: 8, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUserName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            isSessionEstablished
                                ? Icons.verified_user
                                : Icons.lock_outline,
                            size: 12,
                            color: isTerminated
                                ? Colors.red
                                : (isSessionEstablished
                                    ? Colors.green
                                    : Colors.orange),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTerminated
                                ? LocalizationService.translate('terminated')
                                : (isSessionEstablished
                                    ? LocalizationService.translate(
                                        'session_verified_badge')
                                    : LocalizationService.translate(
                                        'session_negotiating_badge')),
                            style: TextStyle(
                              fontSize: 11,
                              color: isTerminated
                                  ? Colors.red
                                  : (isSessionEstablished
                                      ? Colors.green
                                      : Colors.orange),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isTerminated) ...[
                IconButton(
                  tooltip:
                      LocalizationService.translate('safety_number_title'),
                  icon: const Icon(Icons.shield_outlined, color: Colors.green),
                  onPressed: () =>
                      _showSafetyNumberSheet(context, safetyNumber),
                ),
                IconButton(
                  tooltip: LocalizationService.translate('auto_delete'),
                  icon: Icon(
                    duration == 0 ? Icons.timer_off_outlined : Icons.timer,
                    color: duration > 0 ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: () => _showTimerPicker(context, duration),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: isDark ? Colors.white : Colors.black87),
                  onSelected: (val) {
                    if (val == 'safety') {
                      _showSafetyNumberSheet(context, safetyNumber);
                    } else if (val == 'terminate') {
                      _confirmTermination(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'safety',
                      child: Row(
                        children: [
                          const Icon(Icons.shield,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(LocalizationService.translate(
                              'safety_number_title')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'terminate',
                      child: Row(
                        children: [
                          const Icon(Icons.close, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            LocalizationService.translate('terminate'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              // Security status card
              InkWell(
                onTap: !isTerminated
                    ? () => _showSafetyNumberSheet(context, safetyNumber)
                    : null,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          duration > 0
                              ? '${LocalizationService.translate('e2ee_desc')} (${LocalizationService.translate('auto_delete')}: ${_formatDurationLabel(duration)}) • ${LocalizationService.translate('screenshot_protection_active')}'
                              : '${LocalizationService.translate('e2ee_desc')} • ${LocalizationService.translate('screenshot_protection_active')}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          color: Colors.green, size: 18),
                    ],
                  ),
                ),
              ),

              if (isTerminated)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.translate(
                              'secret_chat_terminated_msg'),
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages list or Empty state
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_person_outlined,
                                  size: 48,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                LocalizationService.translate(
                                    'empty_secret_chat'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return _SecretMessageBubble(
                            key: ValueKey(msg.messageId),
                            message: msg,
                            isDark: isDark,
                          );
                        },
                      ),
              ),

              // Chat Input Bar
              if (!isTerminated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, -1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: _isRecordingVoice
                        ? Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: _cancelVoiceRecording,
                                tooltip: LocalizationService.translate(
                                    'slide_to_cancel'),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.fiber_manual_record,
                                  color: Colors.red, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_voiceDuration ~/ 60}:${(_voiceDuration % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _cancelVoiceRecording,
                                child: Text(
                                  LocalizationService.translate(
                                      'slide_to_cancel'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: Colors.green,
                                child: IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white, size: 20),
                                  onPressed: _finishAndSendVoiceRecording,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                onPressed: isSending ? null : _showImageSourcePicker,
                                tooltip:
                                    LocalizationService.translate('pick_image'),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLines: null,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: LocalizationService.translate(
                                        'type_secret_message'),
                                    hintStyle: const TextStyle(fontSize: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_textController.text.trim().isNotEmpty)
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: isSending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send,
                                            color: Colors.white, size: 20),
                                    onPressed: isSending ? null : _sendMessage,
                                  ),
                                )
                              else
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: isSending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.mic,
                                            color: Colors.white, size: 20),
                                    onPressed: isSending
                                        ? null
                                        : _startVoiceRecording,
                                    tooltip: LocalizationService.translate(
                                        'encrypted_voice'),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDurationLabel(int seconds) {
    if (seconds == 5) return LocalizationService.translate('timer_5s');
    if (seconds == 60) return LocalizationService.translate('timer_1m');
    if (seconds == 3600) return LocalizationService.translate('timer_1h');
    return '${seconds}s';
  }
}

class _SecretMessageBubble extends StatefulWidget {
  final SecretMessage message;
  final bool isDark;

  const _SecretMessageBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  State<_SecretMessageBubble> createState() => _SecretMessageBubbleState();
}

class _SecretMessageBubbleState extends State<_SecretMessageBubble> {
  @override
  void initState() {
    super.initState();
    final msg = widget.message;
    if (msg.isMedia &&
        msg.mediaPayload != null &&
        msg.mediaPayload!.decryptedBytes == null &&
        !msg.isOutgoing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SecretChatBloc>().add(
                DownloadSecretMedia(
                  messageId: msg.messageId,
                  payload: msg.mediaPayload!,
                ),
              );
        }
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) return '${seconds ~/ 3600}h';
    if (seconds >= 60) return '${seconds ~/ 60}m';
    return '${seconds}s';
  }

  String _formatRemaining(Duration rem) {
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes.remainder(60)}m';
    }
    if (rem.inMinutes > 0) {
      return '${rem.inMinutes}m ${rem.inSeconds.remainder(60)}s';
    }
    return '${rem.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isOutgoing = message.isOutgoing;
    final isDark = widget.isDark;
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: message.isExpired ? 0.0 : 1.0,
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOutgoing
                ? const Color(0xFF15803D)
                : (isDark ? const Color(0xFF334155) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
              bottomRight: Radius.circular(isOutgoing ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.hasError) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        LocalizationService.translate('decryption_error'),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (message.isMedia) ...[
                if (message.isImage)
                  _SecretImageBubble(
                    message: message,
                    payload: message.mediaPayload!,
                    isOutgoing: isOutgoing,
                    isDark: isDark,
                  )
                else if (message.isVoice)
                  _SecretVoiceBubble(
                    message: message,
                    payload: message.mediaPayload!,
                    isOutgoing: isOutgoing,
                    isDark: isDark,
                  ),
                if (message.mediaPayload?.caption != null &&
                    message.mediaPayload!.caption!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message.mediaPayload!.caption!,
                    style: TextStyle(
                      color: isOutgoing
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  message.decryptedText ?? '...',
                  style: TextStyle(
                    color: isOutgoing
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.lock,
                    size: 11,
                    color: Colors.white70,
                  ),
                  if (message.selfDestructDuration > 0) ...[
                    const SizedBox(width: 4),
                    _buildTimerBadge(),
                  ],
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isOutgoing
                          ? Colors.white70
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBadge() {
    final message = widget.message;
    if (message.isRead) {
      final rem = message.remainingTime ?? Duration.zero;
      final isUrgent = rem.inSeconds <= 5;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: isUrgent
              ? Colors.red.withOpacity(0.35)
              : Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              size: 10,
              color: isUrgent ? Colors.amberAccent : Colors.white70,
            ),
            const SizedBox(width: 2),
            Text(
              _formatRemaining(rem),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                color: isUrgent ? Colors.amberAccent : Colors.white70,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 10,
              color: Colors.white70,
            ),
            const SizedBox(width: 2),
            Text(
              _formatDuration(message.selfDestructDuration),
              style: const TextStyle(
                fontSize: 9.5,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _SecretImageBubble extends StatelessWidget {
  final SecretMessage message;
  final SecretMediaPayload payload;
  final bool isOutgoing;
  final bool isDark;

  const _SecretImageBubble({
    required this.message,
    required this.payload,
    required this.isOutgoing,
    required this.isDark,
  });

  void _openFullscreen(BuildContext context) {
    if (payload.decryptedBytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              LocalizationService.translate('encrypted_image'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                payload.decryptedBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (payload.decryptedBytes != null) {
      return GestureDetector(
        onTap: () => _openFullscreen(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            payload.decryptedBytes!,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final isDownloading = context
        .select<SecretChatBloc, bool>((b) => (b.state is SecretChatActive &&
            (b.state as SecretChatActive)
                .downloadingMediaIds
                .containsKey(message.messageId)));

    return Container(
      width: 200,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: isDownloading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocalizationService.translate('downloading'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              )
            : InkWell(
                onTap: () {
                  context.read<SecretChatBloc>().add(
                        DownloadSecretMedia(
                          messageId: message.messageId,
                          payload: payload,
                        ),
                      );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 32, color: Colors.green),
                    const SizedBox(height: 4),
                    Text(
                      LocalizationService.translate('tap_to_download'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(payload.size / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SecretVoiceBubble extends StatefulWidget {
  final SecretMessage message;
  final SecretMediaPayload payload;
  final bool isOutgoing;
  final bool isDark;

  const _SecretVoiceBubble({
    required this.message,
    required this.payload,
    required this.isOutgoing,
    required this.isDark,
  });

  @override
  State<_SecretVoiceBubble> createState() => _SecretVoiceBubbleState();
}

class _SecretVoiceBubbleState extends State<_SecretVoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.payload.durationSeconds ?? 0);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (widget.payload.decryptedBytes != null) {
        await _player.play(BytesSource(widget.payload.decryptedBytes!));
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _duration.inSeconds > 0 ? _duration : const Duration(seconds: 1);
    final progress =
        (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    if (widget.payload.decryptedBytes == null) {
      final isDownloading = context.select<SecretChatBloc, bool>((b) =>
          (b.state is SecretChatActive &&
              (b.state as SecretChatActive)
                  .downloadingMediaIds
                  .containsKey(widget.message.messageId)));

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green,
                    ),
                  )
                : Icon(
                    Icons.download_rounded,
                    color: widget.isOutgoing ? Colors.white : Colors.green,
                    size: 28,
                  ),
            onPressed: isDownloading
                ? null
                : () {
                    context.read<SecretChatBloc>().add(
                          DownloadSecretMedia(
                            messageId: widget.message.messageId,
                            payload: widget.payload,
                          ),
                        );
                  },
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocalizationService.translate('encrypted_voice'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isOutgoing ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${widget.payload.durationSeconds ?? 0}s • ${(widget.payload.size / 1024).toStringAsFixed(1)} KB',
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isOutgoing ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: widget.isOutgoing ? Colors.white : Colors.green,
            size: 36,
          ),
          onPressed: _togglePlay,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: widget.isOutgoing
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isOutgoing ? Colors.white : Colors.green,
                ),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isPlaying
                  ? _formatDuration(_position)
                  : _formatDuration(_duration),
              style: TextStyle(
                fontSize: 11,
                color: widget.isOutgoing ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
