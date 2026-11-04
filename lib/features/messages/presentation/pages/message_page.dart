import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/widgets/adaptive_scaffold.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/message.dart';
import '../bloc/message_bloc.dart';
import '../bloc/message_event.dart';
import '../bloc/message_state.dart';
import '../../../../core/security/screen_protector_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../chats/domain/repositories/chat_repository.dart';
import '../../../chats/domain/entities/chat_member.dart';
import '../../../chats/data/models/chat_member_model.dart';
import '../../domain/repositories/message_repository.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../../../../core/localization/localization_service.dart';
import 'call_page.dart';
import '../widgets/file_bubble.dart';
import '../widgets/video_note_bubble.dart';
import '../widgets/video_message_bubble.dart';
import '../widgets/video_note_recorder.dart';
import '../widgets/location_picker_dialog.dart';
import '../../data/services/live_location_service.dart';
import '../widgets/live_location_bubble.dart';
import '../widgets/live_location_duration_sheet.dart';
import 'live_location_viewer_page.dart';
import '../widgets/chat_bubble_theme.dart';
import '../widgets/location_message_bubble.dart';
import '../widgets/voice_player_widget.dart';
import '../widgets/poll_bubble.dart';
import '../widgets/create_poll_sheet.dart';
import '../../domain/entities/poll_data.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../chats/presentation/widgets/join_preview_sheet.dart';
import '../../../chats/presentation/pages/channel_group_profile_page.dart';
import '../../../media_editor/presentation/pages/media_editor_page.dart';
import '../../../chats/presentation/widgets/topics_sheet.dart';
import '../widgets/pinned_messages_sheet.dart';
import 'post_comments_page.dart';
import '../../../voice_chat/presentation/widgets/voice_chat_banner.dart';
import '../../../voice_chat/presentation/widgets/start_voice_chat_dialog.dart';
import '../../../stickers/presentation/widgets/sticker_picker_sheet.dart';
import '../../../secret_chat/data/repositories/secret_chat_repository_impl.dart';
import '../../../secret_chat/presentation/bloc/secret_chat_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../secret_chat/presentation/pages/secret_chat_page.dart';
import '../widgets/send_options_sheet.dart';
import '../widgets/schedule_message_dialog.dart';
import 'scheduled_messages_page.dart';
import '../../data/services/scheduled_message_service.dart';
import '../../domain/entities/scheduled_message.dart';
import '../../../saved_messages/data/services/saved_message_service.dart';

class MessagePage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const MessagePage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  int _prevMessageCount = 0;
  bool _markReadPending = false;
  final Set<String> _viewedMessageIds = {};
  final LiveLocationService _liveLocationService = LiveLocationService();
  final ScheduledMessageService _scheduledMessageService = ScheduledMessageService();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }



  String _formatMessageDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final lang = LocalizationService.langNotifier.value;

    if (msgDate == today) {
      if (lang == 'uz') return 'Bugun';
      if (lang == 'ru') return 'Сегодня';
      return 'Today';
    }
    if (msgDate == yesterday) {
      if (lang == 'uz') return 'Kecha';
      if (lang == 'ru') return 'Вчера';
      return 'Yesterday';
    }

    final year = dateTime.year;
    final day = dateTime.day;
    final month = dateTime.month;

    final monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthsUz = [
      'Yanvar',
      'Fevral',
      'Mart',
      'Aprel',
      'May',
      'Iyun',
      'Iyul',
      'Avgust',
      'Sentabr',
      'Oktabr',
      'Noyabr',
      'Dekabr'
    ];
    final monthsRu = [
      'Января',
      'Февраля',
      'Марта',
      'Апреля',
      'Мая',
      'Июня',
      'Июля',
      'Августа',
      'Сентября',
      'Октября',
      'Ноября',
      'Декабря'
    ];

    if (lang == 'uz') {
      return '$day-${monthsUz[month - 1]}, $year';
    } else if (lang == 'ru') {
      return '$day ${monthsRu[month - 1]} $year';
    }
    return '${monthsEn[month - 1]} $day, $year';
  }

  Widget _buildDateSeparator(String dateText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Timer? _typingTimer;
  bool _isTyping = false;
  DateTime? _lastTypingUpdate;
  String? _cachedMyUid;
  String? get _myUid {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.uid : null;
  }

  String get _myUserName {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated
        ? authState.user.displayName
        : 'User';
  }

  int _slowModeRemainingSeconds = 0;
  Timer? _slowModeTimer;

  bool get _isExemptFromSlowMode {
    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    final createdBy = chatData?['createdBy'] as String?;
    final isChannel = chatData?['isChannel'] as bool? ?? false;
    final uid = _myUid;
    return isChannel || createdBy == uid || (_currentMember?.isAdmin ?? false);
  }

  int get _chatSlowModeSeconds {
    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    return (chatData?['slowModeSeconds'] as num?)?.toInt() ?? 0;
  }

  void _startSlowModeCooldown(int seconds) {
    if (seconds <= 0) return;
    _slowModeTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _slowModeRemainingSeconds = seconds;
    });
    _slowModeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_slowModeRemainingSeconds > 1) {
          _slowModeRemainingSeconds--;
        } else {
          _slowModeRemainingSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  bool _checkSlowModeAndWarn() {
    if (!_isExemptFromSlowMode &&
        _chatSlowModeSeconds > 0 &&
        _slowModeRemainingSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sekin rejim yoqilgan (Slow mode). Yana $_slowModeRemainingSeconds soniya kuting.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  void _triggerSlowModeAfterSend() {
    if (!_isExemptFromSlowMode && _chatSlowModeSeconds > 0) {
      _startSlowModeCooldown(_chatSlowModeSeconds);
    }
  }

  late ChatRepository _chatRepository;
  Message? _replyingTo;
  Message? _editingMessage;
  StreamSubscription<DocumentSnapshot>? _chatSubscription;
  DocumentSnapshot? _chatDoc;
  StreamSubscription<DocumentSnapshot>? _memberSubscription;
  ChatMember? _currentMember;
  bool _isSilentPost = false;
  bool _isAttachmentMenuOpen = false;
  Stream<DocumentSnapshot>? _userStream;
  Uint8List? _otherUserPhotoBytes;
  String? _lastDecodedPhotoURL;

  // Voice recording state variables
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Wallpaper, Search, Self-destruct state variables
  String _wallpaperType = 'default';
  String _wallpaperValue = '';
  Box? _settingsBox;

  bool _isSearching = false;
  String _searchQuery = '';

  int? _selfDestructDuration;
  bool _isOffline = false;
  StreamSubscription? _connectivitySubscription;

  // Telegram Forum Topics & Multi-Pinned Messages
  String? _activeTopicId;
  String? _activeTopicTitle;
  String? _activeTopicEmoji;
  int _currentPinIndex = 0;
  String? _highlightedMessageId;

  bool get _canSendText =>
      _currentMember == null ||
      _currentMember!.isOwner ||
      _currentMember!.isAdmin ||
      _currentMember!.permissions.canSendMessages;

  bool get _canSendMedia =>
      _currentMember == null ||
      _currentMember!.isOwner ||
      _currentMember!.isAdmin ||
      _currentMember!.permissions.canSendMedia;

  bool get _canSendPolls =>
      _currentMember == null ||
      _currentMember!.isOwner ||
      _currentMember!.isAdmin ||
      _currentMember!.permissions.canSendPolls;

  bool get _canPinMessages =>
      _currentMember == null ||
      _currentMember!.isOwner ||
      _currentMember!.isAdmin ||
      _currentMember!.permissions.canPinMessages;

  bool get _canManageTopics =>
      _currentMember == null ||
      _currentMember!.isOwner ||
      _currentMember!.isAdmin ||
      _currentMember!.permissions.canManageTopics;

  void _jumpToMessage(String msgId, List<Message> allMessages) {
    final targetKey = _messageKeys[msgId];
    if (targetKey?.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else {
      final idx = allMessages
          .where((m) => !m.isDeleted)
          .toList()
          .indexWhere((m) => m.id == msgId);
      if (idx != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          (idx * 80.0).clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    setState(() {
      _highlightedMessageId = msgId;
    });
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted && _highlightedMessageId == msgId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ScreenProtectorService.disableSecure();
    WidgetsBinding.instance.addObserver(this);
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() {
          _isOffline = !results.any((r) =>
              r == ConnectivityResult.mobile ||
              r == ConnectivityResult.wifi ||
              r == ConnectivityResult.ethernet);
        });
      }
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        final offline = !results.any((r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet);
        if (_isOffline != offline) {
          setState(() {
            _isOffline = offline;
          });
        }
      }
    });
    _chatRepository = context.read<ChatRepository>();
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _chatDoc = doc;
        });
      }
    });
    if (widget.otherUserId.isNotEmpty) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .snapshots();
    }
    _loadWallpaperSettings();

    final authState = context.read<AuthBloc>().state;
    final resolvedUid = (authState is AuthAuthenticated)
        ? authState.user.uid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    if (resolvedUid.isNotEmpty) {
      _cachedMyUid = resolvedUid;
      _scheduledMessageService.processDueMessagesForUser(
        _cachedMyUid!,
        chatId: widget.chatId,
      );
      // Member holatini kuzatish (rol va ruxsatlar)
      _memberSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('members')
          .doc(_cachedMyUid)
          .snapshots()
          .listen((doc) {
        if (mounted && doc.exists) {
          setState(() {
            _currentMember = ChatMemberModel.fromFirestore(doc);
          });
        }
      });
      // Xabarlarni yuklash
      context.read<MessageBloc>().add(LoadMessages(widget.chatId, currentUserId: _cachedMyUid));
      // Chatdagi xabarlarni o'qilgan deb belgilash
      _chatRepository.markAsRead(widget.chatId, _cachedMyUid!);
      context.read<MessageRepository>().markMessagesAsRead(widget.chatId, _cachedMyUid!);

      // Typing listener-ni ulaymiz
      _textController.addListener(_onTextChanged);
    }
  }

  void _loadWallpaperSettings() async {
    _settingsBox = await Hive.openBox('settings');
    final box = _settingsBox;
    if (box != null) {
      if (mounted) {
        setState(() {
          _wallpaperType = box.get('wallpaper_type_${widget.chatId}',
              defaultValue: 'default');
          _wallpaperValue =
              box.get('wallpaper_val_${widget.chatId}', defaultValue: '');
        });
      }
    }
  }

  void _onTextChanged() {
    if (_myUid == null) return;

    // Trigger rebuild to update Send/Mic button visibility
    setState(() {});

    final text = _textController.text.trim();

    if (text.isEmpty) {
      if (_isTyping) {
        _isTyping = false;
        _lastTypingUpdate = null;
        _typingTimer?.cancel();
        _chatRepository.updateTypingStatus(widget.chatId, _myUid!, false);
      }
      return;
    }

    final now = DateTime.now();
    if (!_isTyping ||
        _lastTypingUpdate == null ||
        now.difference(_lastTypingUpdate!).inSeconds > 4) {
      _isTyping = true;
      _lastTypingUpdate = now;
      _chatRepository.updateTypingStatus(widget.chatId, _myUid!, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 5), () {
      if (_isTyping && mounted) {
        _isTyping = false;
        _lastTypingUpdate = null;
        _chatRepository.updateTypingStatus(widget.chatId, _myUid!, false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (_cachedMyUid != null && _isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        _chatRepository.updateTypingStatus(widget.chatId, _cachedMyUid!, false);
      }
    }
  }

  @override
  void dispose() {
    ScreenProtectorService.disableSecure();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _chatSubscription?.cancel();
    _memberSubscription?.cancel();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _slowModeTimer?.cancel();
    _audioRecorder.dispose();
    _liveLocationService.dispose();
    if (_cachedMyUid != null) {
      _chatRepository.updateTypingStatus(widget.chatId, _cachedMyUid!, false);
      _chatRepository.markAsRead(widget.chatId, _cachedMyUid!);
    }
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    // Notify MessageBloc that this conversation is closed
    context.read<MessageBloc>().add(LeaveChat(widget.chatId));
    super.dispose();
  }

  Widget _buildMessageStatusIcon(Message message, {double size = 14}) {
    switch (message.status) {
      case MessageStatus.queued:
        return Tooltip(
          message: LocalizationService.translate('waiting_to_send'),
          child: Icon(
            Icons.access_time_rounded,
            size: size - 1,
            color: Colors.white70,
          ),
        );
      case MessageStatus.sending:
        return Tooltip(
          message: LocalizationService.translate('sending'),
          child: SizedBox(
            width: size - 2,
            height: size - 2,
            child: const CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        );
      case MessageStatus.sent:
        return Tooltip(
          message: LocalizationService.translate('sent'),
          child: Icon(
            Icons.done_rounded,
            size: size,
            color: Colors.white70,
          ),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: Colors.white70,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: const Color(0xFF86EFAC),
        );
      case MessageStatus.failed:
        return Tooltip(
          message: LocalizationService.translate('tap_to_retry'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final authState = context.read<AuthBloc>().state;
              final uid = authState is AuthAuthenticated
                  ? authState.user.uid
                  : (_cachedMyUid ?? '');
              context.read<MessageBloc>().add(RetryOutboxMessage(
                    messageId: message.id,
                    chatId: widget.chatId,
                    senderId: uid,
                  ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LocalizationService.translate('sending')),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Icon(
              Icons.error_outline_rounded,
              size: size + 1,
              color: Colors.redAccent,
            ),
          ),
        );
    }
  }

  void _onSend({bool forceSilent = false}) {
    final text = _textController.text.trim();
    final authState = context.read<AuthBloc>().state;
    // Edit holatida bo'sh tekst yuborilmaydi
    if (_editingMessage != null && text.isEmpty) {
      setState(() {
        _editingMessage = null;
        _textController.clear();
      });
      return;
    }
    if (text.isEmpty && _replyingTo == null && _editingMessage == null) return;
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.uid;
    if (_editingMessage != null) {
      context.read<MessageBloc>().add(EditMessageRequested(
            chatId: widget.chatId,
            messageId: _editingMessage!.id,
            newText: text,
          ));
    } else {
      if (!_canSendText) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.of(context).get('restricted_send_messages')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!_checkSlowModeAndWarn()) return;

      final chatData = _chatDoc?.data() as Map<String, dynamic>?;
      final isChannel = chatData?['isChannel'] as bool? ?? false;
      final signMessages = chatData?['signMessages'] as bool? ?? false;
      final createdBy = chatData?['createdBy'] as String?;
      String? title = _currentMember?.customTitle;
      if (title == null) {
        if (createdBy == uid) {
          title = LocalizationService.translate('owner_badge');
        } else if (_currentMember?.isAdmin ?? false) {
          title = LocalizationService.translate('admin_badge');
        }
      }

      String? authorName;
      if (isChannel && signMessages) {
        authorName = authState.user.displayName.isNotEmpty
            ? authState.user.displayName
            : 'Admin';
      }

      final clientMsgId = const Uuid().v4();
      final effectiveSilent = forceSilent || _isSilentPost;
      context.read<MessageBloc>().add(SendTextMessage(
            messageId: clientMsgId,
            chatId: widget.chatId,
            senderId: uid,
            text: text,
            replyToMessageId: _replyingTo?.id,
            selfDestructDuration: _selfDestructDuration,
            senderTitle: title,
            authorName: authorName,
            isSilent: effectiveSilent,
            topicId: _activeTopicId,
          ));

      _triggerSlowModeAfterSend();
    }
    _textController.clear();
    // Keyboard yopish
    FocusScope.of(context).unfocus();
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
      _selfDestructDuration = null;
      _isSilentPost = false;
    });
    // Scroll pastga
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFeedbackSnackBar(
    String message, {
    IconData? icon,
    Color? iconColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor ?? Colors.white70),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSendOptionsMenu() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final option = await SendOptionsSheet.show(context);
    if (!mounted || option == null) return;

    switch (option) {
      case SendOptionType.sendNow:
        _onSend();
        break;
      case SendOptionType.sendWithoutSound:
        _onSend(forceSilent: true);
        break;
      case SendOptionType.schedule:
        final result = await ScheduleMessageDialog.show(context);
        if (!mounted || result == null) return;

        final authState = context.read<AuthBloc>().state;
        if (authState is! AuthAuthenticated) return;

        try {
          await _scheduledMessageService.scheduleMessage(
            chatId: widget.chatId,
            senderId: authState.user.uid,
            text: text,
            scheduledAt: result.scheduledAt,
            isSilent: result.isSilent,
          );

          if (!mounted) return;
          _textController.clear();
          FocusScope.of(context).unfocus();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService.translate('scheduled_successfully'),
              ),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: LocalizationService.translate('scheduled_messages'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduledMessagesPage(
                        chatId: widget.chatId,
                        chatTitle: widget.otherUserName,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${LocalizationService.translate('schedule_failed')}: $e',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
    }
  }

  void _onPickImage() async {
    if (!_canSendMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.of(context).get('restricted_send_media')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_checkSlowModeAndWarn()) return;
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty && mounted) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        for (final pickedFile in pickedFiles) {
          if (!mounted) break;
          final editedFile = await MediaEditorPage.open(
            context,
            imageFile: File(pickedFile.path),
            isStoryMode: false,
          );
          if (editedFile != null && mounted) {
            context.read<MessageBloc>().add(SendImageMessage(
                  chatId: widget.chatId,
                  senderId: authState.user.uid,
                  imageFile: editedFile,
                ));
            _triggerSlowModeAfterSend();
          }
        }
      }
    }
  }

  void _onPickVideo({required bool fromCamera}) async {
    if (!_canSendMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.of(context).get('restricted_send_media')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_checkSlowModeAndWarn()) return;
    final picker = ImagePicker();
    final pickedVideo = await picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );

    if (pickedVideo != null && mounted) {
      SendVideoPreviewDialog.show(
        context: context,
        videoFile: File(pickedVideo.path),
        onSend: (caption, targetVideo) {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated) {
            context.read<MessageBloc>().add(
                  SendVideoMessageRequested(
                    chatId: widget.chatId,
                    senderId: authState.user.uid,
                    videoFile: targetVideo,
                    caption: caption,
                  ),
                );
            _triggerSlowModeAfterSend();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(LocalizationService.of(context).get('video_sending'))),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        return AdaptiveScaffold(
          title: _isSearching
              ? TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: LocalizationService.translate('search_hint'),
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                )
              : (widget.otherUserId.isEmpty
                  ? Builder(
                      builder: (context) {
                        String gName = widget.otherUserName;
                        bool isChannel = false;
                        String? photoURL;
                        if (_chatDoc != null && _chatDoc!.exists) {
                          final data =
                              _chatDoc!.data() as Map<String, dynamic>?;
                          gName = data?['groupName'] as String? ?? gName;
                          isChannel = data?['isChannel'] as bool? ?? false;
                          photoURL = data?['groupAvatar'] as String?;
                        }

                        final hasPhoto = photoURL != null &&
                            photoURL.startsWith('data:image');
                        final gradient = AppColors.avatarGradients[
                            gName.length % AppColors.avatarGradients.length];

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChannelGroupProfilePage(
                                  chatId: widget.chatId,
                                  currentUserId: _myUid ?? '',
                                  currentUserName: _myUserName,
                                  chatRepository: _chatRepository,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: hasPhoto
                                      ? null
                                      : LinearGradient(
                                          colors: gradient,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: hasPhoto
                                      ? AppImage.memory(
                                          photoURL,
                                          fit: BoxFit.cover,
                                          width: 36,
                                          height: 36,
                                        )
                                      : Center(
                                          child: Text(
                                            gName.isNotEmpty
                                                ? gName
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'G',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      gName,
                                      style: AppTextStyles.title().copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      isChannel
                                          ? LocalizationService.translate('channel')
                                          : LocalizationService.translate('new_group'),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: _userStream,
                      builder: (context, userSnapshot) {
                        String displayName = widget.otherUserName;
                        String? photoURL;
                        bool isUserOnline = false;
                        DateTime? lastSeen;
                        bool showLastSeen = true;
                        String email = '';

                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final data = userSnapshot.data!.data()
                              as Map<String, dynamic>?;
                          displayName =
                              data?['displayName'] as String? ?? displayName;
                          photoURL = data?['photoURL'] as String?;
                          isUserOnline = data?['isOnline'] as bool? ?? false;
                          showLastSeen = data?['showLastSeen'] as bool? ?? true;
                          final ts = data?['lastSeen'] as Timestamp?;
                          lastSeen = ts?.toDate();
                          email = data?['email'] as String? ?? '';

                          if (photoURL != null &&
                              photoURL.startsWith('data:image')) {
                            if (_lastDecodedPhotoURL != photoURL) {
                              _lastDecodedPhotoURL = photoURL;
                              _otherUserPhotoBytes =
                                  base64Decode(photoURL.split(',').last);
                            }
                          } else {
                            _otherUserPhotoBytes = null;
                            _lastDecodedPhotoURL = null;
                          }
                        }

                        final hasPhoto = photoURL != null &&
                            photoURL.startsWith('data:image');
                        final gradient = AppColors.avatarGradients[
                            displayName.length %
                                AppColors.avatarGradients.length];

                        return Builder(
                          builder: (context) {
                            bool isTyping = false;
                            if (_chatDoc != null && _chatDoc!.exists) {
                              final data =
                                  _chatDoc!.data() as Map<String, dynamic>?;
                              final typingStates = data?['typingStates']
                                      as Map<String, dynamic>? ??
                                  {};
                              isTyping =
                                  typingStates[widget.otherUserId] as bool? ??
                                      false;

                              if (isTyping && isUserOnline) {
                                final typingLastActive =
                                    data?['typingLastActive']
                                            as Map<String, dynamic>? ??
                                        {};
                                final lastActiveTimestamp =
                                    typingLastActive[widget.otherUserId]
                                        as Timestamp?;
                                if (lastActiveTimestamp != null) {
                                  final lastActive =
                                      lastActiveTimestamp.toDate();
                                  final now = DateTime.now();
                                  if (now.difference(lastActive).inSeconds >
                                      8) {
                                    isTyping = false;
                                  }
                                }
                              } else {
                                isTyping = false;
                              }
                            }

                            final statusText = isTyping
                                ? LocalizationService.translate('typing')
                                : (isUserOnline
                                    ? LocalizationService.translate('online')
                                    : (showLastSeen && lastSeen != null
                                        ? LocalizationService.formatLastSeen(
                                            lastSeen)
                                        : LocalizationService.translate(
                                            'offline')));
                            final statusColor = isTyping
                                ? AppColors.primary
                                : (isUserOnline
                                    ? AppColors.online
                                    : Colors.grey);

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (widget.otherUserId.isEmpty) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChannelGroupProfilePage(
                                        chatId: widget.chatId,
                                        currentUserId: _myUid ?? '',
                                        currentUserName: _myUserName,
                                        chatRepository: _chatRepository,
                                      ),
                                    ),
                                  );
                                } else {
                                  _showUserInfoSheet(
                                    displayName: displayName,
                                    photoURL: photoURL,
                                    statusText: statusText,
                                    statusColor: statusColor,
                                    email: email,
                                  );
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: hasPhoto
                                          ? null
                                          : LinearGradient(
                                              colors: gradient,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: hasPhoto
                                          ? AppImage.memory(
                                              photoURL,
                                              fit: BoxFit.cover,
                                              width: 36,
                                              height: 36,
                                            )
                                          : Center(
                                              child: Text(
                                                displayName.isNotEmpty
                                                    ? displayName
                                                        .substring(0, 1)
                                                        .toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(displayName,
                                          style: AppTextStyles.title()),
                                      Text(
                                        statusText,
                                        style: AppTextStyles.caption().copyWith(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: isTyping
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    )),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            StreamBuilder<List<ScheduledMessage>>(
              stream: _myUid != null
                  ? _scheduledMessageService.watchPendingScheduledMessages(
                      _myUid!,
                      chatId: widget.chatId,
                    )
                  : null,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return IconButton(
                  icon: Badge(
                    label: Text('$count'),
                    backgroundColor: const Color(0xFFF59E0B),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  tooltip: LocalizationService.translate('scheduled_messages'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScheduledMessagesPage(
                          chatId: widget.chatId,
                          chatTitle: widget.otherUserName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = "";
                  });
                },
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'call') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallPage(
                        chatId: widget.chatId,
                        currentUserId: _myUid!,
                        otherUserName: widget.otherUserName,
                        receiverUserId: widget.otherUserId,
                        isVideo: false,
                        isCaller: true,
                      ),
                    ),
                  );
                } else if (value == 'video') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallPage(
                        chatId: widget.chatId,
                        currentUserId: _myUid!,
                        otherUserName: widget.otherUserName,
                        receiverUserId: widget.otherUserId,
                        isVideo: true,
                        isCaller: true,
                      ),
                    ),
                  );
                } else if (value == 'search') {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = "";
                    }
                  });
                } else if (value == 'voice_chat') {
                  final chatData =
                      _chatDoc?.data() as Map<String, dynamic>?;
                  final gName = chatData?['groupName'] as String? ??
                      widget.otherUserName;
                  final isChannel =
                      chatData?['isChannel'] as bool? ?? false;
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    StartVoiceChatDialog.show(
                      context: context,
                      chatId: widget.chatId,
                      chatTitle: gName,
                      currentUserId: authState.user.uid,
                      currentUserName: authState.user.displayName.isNotEmpty
                          ? authState.user.displayName
                          : 'Foydalanuvchi',
                      currentUserPhoto: authState.user.photoURL,
                      isChannel: isChannel,
                    );
                  }
                } else if (value == 'quick_info') {
                  _showGroupOrChannelInfoSheet();
                } else if (value == 'profile_settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChannelGroupProfilePage(
                        chatId: widget.chatId,
                        currentUserId: _myUid ?? '',
                        currentUserName: _myUserName,
                        chatRepository: _chatRepository,
                      ),
                    ),
                  );
                } else if (value == 'wallpaper') {
                  _showWallpaperMenu();
                } else if (value == 'scheduled_messages') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduledMessagesPage(
                        chatId: widget.chatId,
                        chatTitle: widget.otherUserName,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                if (widget.otherUserId.isEmpty) ...[
                  PopupMenuItem(
                    value: 'voice_chat',
                    child: Row(
                      children: [
                        const Icon(Icons.mic_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(LocalizationService.of(context).get('space_voice_chat')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'quick_info',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(LocalizationService.of(context).get('quick_info')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profile_settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(LocalizationService.of(context).get('profile_and_settings')),
                      ],
                    ),
                  ),
                ],
                if (!widget.chatId.startsWith('group_')) ...[
                  PopupMenuItem(
                    value: 'call',
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(LocalizationService.translate('audio_call')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'video',
                    child: Row(
                      children: [
                        const Icon(Icons.videocam_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(LocalizationService.translate('video_call')),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(
                          _isSearching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          size: 20),
                      const SizedBox(width: 12),
                      Text(_isSearching
                          ? LocalizationService.translate('cancel')
                          : LocalizationService.translate('search')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'wallpaper',
                  child: Row(
                    children: [
                      const Icon(Icons.wallpaper_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(LocalizationService.translate('wallpaper')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'scheduled_messages',
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(LocalizationService.translate('scheduled_messages')),
                    ],
                  ),
                ),
              ],
            ),
          ],
          body: Container(
            decoration: _getWallpaperDecoration(),
            child: Column(
              children: [
                // 🎙️ Live Voice Chat Banner (Telegram / Clubhouse Spaces)
                if (_myUid != null)
                  VoiceChatBanner(
                    chatId: widget.chatId,
                    currentUserId: _myUid!,
                    currentUserName: _myUserName,
                    currentUserPhoto: (context.read<AuthBloc>().state is AuthAuthenticated)
                        ? (context.read<AuthBloc>().state as AuthAuthenticated).user.photoURL
                        : null,
                  ),
                // Top Panels: Forum Topics Bar & Multi-Pinned Message Bar
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox();
                    }
                    final chatData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final isGroup = chatData?['isGroup'] as bool? ?? false;
                    final topicsEnabled =
                        chatData?['topicsEnabled'] as bool? ?? false;

                    // Pinned messages extraction
                    final rawPinnedIds =
                        List<String>.from(chatData?['pinnedMessageIds'] ?? []);
                    final singlePinnedId =
                        chatData?['pinnedMessageId'] as String?;
                    final List<String> pinnedIds = rawPinnedIds.isNotEmpty
                        ? rawPinnedIds
                        : (singlePinnedId != null && singlePinnedId.isNotEmpty
                            ? [singlePinnedId]
                            : <String>[]);

                    final messageState = context.watch<MessageBloc>().state;
                    final allMsgs = (messageState is MessageLoaded &&
                            (messageState.chatId.isEmpty ||
                                messageState.chatId == widget.chatId))
                        ? messageState.messages
                        : <Message>[];

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Offline Indicator Banner
                        if (_isOffline)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97706),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  LocalizationService.translate(
                                      'no_internet_connection'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 1. Forum Topics Switcher Bar
                        if (isGroup && topicsEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black12,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    showKakkuFloatingBottomSheet(
                                      context: context,
                                      builder: (ctx) => TopicsSheet(
                                        chatId: widget.chatId,
                                        currentUserId: _myUid ?? '',
                                        activeTopicId: _activeTopicId,
                                        canManageTopics: _canManageTopics,
                                        chatRepository: _chatRepository,
                                        onTopicSelected: (topic) {
                                          setState(() {
                                            if (topic == null) {
                                              _activeTopicId = null;
                                              _activeTopicTitle = null;
                                              _activeTopicEmoji = null;
                                            } else {
                                              _activeTopicId = topic.id;
                                              _activeTopicTitle = topic.title;
                                              _activeTopicEmoji =
                                                  topic.iconEmoji;
                                            }
                                          });
                                        },
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _activeTopicId != null
                                          ? AppColors.primary.withOpacity(0.15)
                                          : (isDark
                                              ? Colors.white10
                                              : Colors.black
                                                  .withOpacity(0.06)),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _activeTopicId != null
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _activeTopicEmoji ?? '💬',
                                          style:
                                              const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 6),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 180),
                                          child: Text(
                                            _activeTopicTitle ??
                                                'Barcha mavzular (Topics)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _activeTopicId != null
                                                  ? AppColors.primary
                                                  : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: _activeTopicId != null
                                              ? AppColors.primary
                                              : (isDark
                                                  ? Colors.white60
                                                  : Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_activeTopicId != null) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _activeTopicId = null;
                                        _activeTopicTitle = null;
                                        _activeTopicEmoji = null;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.black.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          size: 14),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  _activeTopicId != null
                                      ? 'Mavzu bo\'yicha'
                                      : 'Forum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 2. Multi-Pinned Messages Bar
                        if (pinnedIds.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final activeIndex =
                                  _currentPinIndex % pinnedIds.length;
                              final activePinnedId = pinnedIds[activeIndex];
                              final pinnedMsg = allMsgs.firstWhere(
                                (m) => m.id == activePinnedId && !m.isDeleted,
                                orElse: () => Message(
                                  id: activePinnedId,
                                  senderId: '',
                                  text: 'Mahkamlangan xabar',
                                  type: MessageType.text,
                                  isRead: true,
                                  timestamp: DateTime.now(),
                                ),
                              );

                              String previewText = pinnedMsg.text ?? '';
                              if (pinnedMsg.type == MessageType.poll &&
                                  pinnedMsg.poll != null) {
                                previewText = '📊 ${pinnedMsg.poll!.question}';
                              } else if (pinnedMsg.imageUrl != null) {
                                previewText = LocalizationService.translate('photo_snippet');
                              } else if (pinnedMsg.fileName != null) {
                                previewText = '📁 ${pinnedMsg.fileName}';
                              }

                              return InkWell(
                                onTap: () {
                                  _jumpToMessage(activePinnedId, allMsgs);
                                  if (pinnedIds.length > 1) {
                                    setState(() {
                                      _currentPinIndex =
                                          (activeIndex + 1) % pinnedIds.length;
                                    });
                                  }
                                },
                                onLongPress: () {
                                  showKakkuFloatingBottomSheet(
                                    context: context,
                                    builder: (ctx) => PinnedMessagesSheet(
                                      pinnedMessages: allMsgs.where((m) => pinnedIds.contains(m.id) && !m.isDeleted).toList(),
                                      canUnpin: _canPinMessages,
                                      onMessageSelected: (msg) =>
                                          _jumpToMessage(msg.id, allMsgs),
                                      onUnpin: (msg) {
                                        if (!_canPinMessages) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Xabarni bekor qilish huquqingiz cheklangan.'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                        context
                                            .read<MessageBloc>()
                                            .add(PinMessageRequested(
                                              chatId: widget.chatId,
                                              messageId: msg.id,
                                              isUnpin: true,
                                            ));
                                      },
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.black12,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.push_pin_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  pinnedIds.length > 1
                                                      ? '${activeIndex + 1}/${pinnedIds.length} ${LocalizationService.translate('pinned_message_title')}'
                                                      : LocalizationService
                                                          .translate(
                                                              'pinned_message_title'),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                if (pinnedIds.length > 1) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withOpacity(0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      'O\'tish uchun bosing',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              previewText.isNotEmpty
                                                  ? previewText
                                                  : 'Mahkamlangan xabar',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (pinnedIds.length > 1)
                                        IconButton(
                                          tooltip: LocalizationService.of(context).get('all_pinned'),
                                          icon: const Icon(
                                              Icons.format_list_bulleted_rounded,
                                              size: 18),
                                          onPressed: () {
                                            showKakkuFloatingBottomSheet(
                                              context: context,
                                              builder: (ctx) =>
                                                  PinnedMessagesSheet(
                                                pinnedMessages: allMsgs
                                                    .where((m) =>
                                                        pinnedIds.contains(m.id) &&
                                                        !m.isDeleted)
                                                    .toList(),
                                                canUnpin: _canPinMessages,
                                                onMessageSelected: (msg) =>
                                                    _jumpToMessage(msg.id, allMsgs),
                                                onUnpin: (msg) {
                                                  if (!_canPinMessages) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(LocalizationService.of(context).get('unpin_restricted')),
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  context
                                                      .read<MessageBloc>()
                                                      .add(PinMessageRequested(
                                                        chatId: widget.chatId,
                                                        messageId: msg.id,
                                                        isUnpin: true,
                                                      ));
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      IconButton(
                                        tooltip: LocalizationService.of(context).get('unpin_tooltip'),
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18),
                                        onPressed: () {
                                          if (!_canPinMessages) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(LocalizationService.of(context).get('unpin_restricted')),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                            return;
                                          }
                                          context
                                              .read<MessageBloc>()
                                              .add(PinMessageRequested(
                                                chatId: widget.chatId,
                                                messageId: activePinnedId,
                                                isUnpin: true,
                                              ));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
                Expanded(
                  child: BlocBuilder<MessageBloc, MessageState>(
                    builder: (context, state) {
                      if (state is MessageLoading ||
                          (state is MessageLoaded &&
                              state.chatId.isNotEmpty &&
                              state.chatId != widget.chatId)) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is MessageLoaded) {
                        final messages = state.messages;
                        final authState = context.read<AuthBloc>().state;
                        final currentUserId = authState is AuthAuthenticated
                            ? authState.user.uid
                            : '';

                        if (messages.length > _prevMessageCount) {
                          _prevMessageCount = messages.length;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToBottom();
                          });
                          // Yangi xabar kelganda bir marta o'qilgan deb belgilaymiz
                          if (currentUserId.isNotEmpty && !_markReadPending) {
                            final hasForeignUnread = messages.any(
                                (m) => m.senderId != currentUserId && !m.isRead);
                            if (hasForeignUnread) {
                              _markReadPending = true;
                              context
                                  .read<MessageRepository>()
                                  .markMessagesAsRead(
                                      widget.chatId, currentUserId)
                                  .whenComplete(() {
                                if (mounted) {
                                  _markReadPending = false;
                                }
                              });
                            }
                          }
                        }

                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'Say Hello 👋',
                              style: AppTextStyles.body().copyWith(
                                  color: AppColors.textSecondaryLight),
                            ),
                          );
                        }

                        var visibleMessages =
                            messages.where((m) => !m.isDeleted).toList();

                        // Forum Topic filter
                        if (_activeTopicId != null) {
                          visibleMessages = visibleMessages
                              .where((m) => m.topicId == _activeTopicId)
                              .toList();
                        }

                        // Search filter
                        if (_isSearching && _searchQuery.isNotEmpty) {
                          visibleMessages = visibleMessages.where((m) {
                            final text = m.text?.toLowerCase() ?? '';
                            final file = m.fileName?.toLowerCase() ?? '';
                            return text.contains(_searchQuery) ||
                                file.contains(_searchQuery);
                          }).toList();
                        }

                        if (visibleMessages.isEmpty) {
                          return Center(
                            child: Text(
                              _isSearching
                                  ? 'No messages found.'
                                  : (_activeTopicId != null
                                      ? 'Ushbu mavzuda hozircha xabarlar yo\'q 💬'
                                      : 'Say Hello 👋'),
                              style: AppTextStyles.body().copyWith(
                                  color: AppColors.textSecondaryLight),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, top: 8, bottom: 24),
                          itemCount: visibleMessages.length,
                          itemBuilder: (context, index) {
                            final msg = visibleMessages[index];
                            final isMe = msg.senderId == currentUserId;
                            final grouping =
                                ChatBubbleTheme.calculateGroupPosition(
                              visibleMessages,
                              index,
                              currentUserId,
                            );

                            bool showDateSeparator = false;
                            if (index == 0) {
                              showDateSeparator = true;
                            } else {
                              final prevMsg = visibleMessages[index - 1];
                              final prevDate = DateTime(
                                  prevMsg.timestamp.year,
                                  prevMsg.timestamp.month,
                                  prevMsg.timestamp.day);
                              final currDate = DateTime(msg.timestamp.year,
                                  msg.timestamp.month, msg.timestamp.day);
                              if (prevDate != currDate) {
                                showDateSeparator = true;
                              }
                            }

                            // Har bir xabarga GlobalKey tayinlaymiz
                            final msgKey = _messageKeys.putIfAbsent(
                              msg.id,
                              () => GlobalKey(),
                            );

                            final bubble = _buildMessageBubble(
                              msg,
                              isMe,
                              visibleMessages,
                              grouping: grouping,
                              msgKey: msgKey,
                            );

                            if (showDateSeparator) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildDateSeparator(
                                      _formatMessageDate(msg.timestamp)),
                                  bubble,
                                ],
                              );
                            }
                            return bubble;
                          },
                        );
                      } else if (state is MessageFailure) {
                        return Center(child: Text(LocalizationService.formatError(state.error)));
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(_myUid)
                      .snapshots(),
                  builder: (context, myUserSnap) {
                    if (widget.otherUserId.isNotEmpty) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.otherUserId)
                            .snapshots(),
                        builder: (context, otherUserSnap) {
                          List<String> myBlocked = [];
                          List<String> otherBlocked = [];

                          if (myUserSnap.hasData && myUserSnap.data!.exists) {
                            final data = myUserSnap.data!.data()
                                as Map<String, dynamic>?;
                            myBlocked =
                                List<String>.from(data?['blockedUsers'] ?? []);
                          }
                          if (otherUserSnap.hasData &&
                              otherUserSnap.data!.exists) {
                            final data = otherUserSnap.data!.data()
                                as Map<String, dynamic>?;
                            otherBlocked =
                                List<String>.from(data?['blockedUsers'] ?? []);
                          }

                          final iBlockedOther =
                              myBlocked.contains(widget.otherUserId);
                          final otherBlockedMe = otherBlocked.contains(_myUid);

                          if (iBlockedOther) {
                            return ValueListenableBuilder<String>(
                              valueListenable: LocalizationService.langNotifier,
                              builder: (context, _, __) => _buildBlockBanner(
                                LocalizationService.translate(
                                    'you_have_blocked_user'),
                              ),
                            );
                          }
                          if (otherBlockedMe) {
                            return ValueListenableBuilder<String>(
                              valueListenable: LocalizationService.langNotifier,
                              builder: (context, _, __) => _buildBlockBanner(
                                LocalizationService.translate(
                                    'you_have_been_blocked'),
                              ),
                            );
                          }

                          return _buildInputBar();
                        },
                      );
                    }

                    if (_chatDoc != null && _chatDoc!.exists) {
                      final data = _chatDoc!.data() as Map<String, dynamic>?;
                      final isChannel = data?['isChannel'] as bool? ?? false;
                      final createdBy = data?['createdBy'] as String?;
                      final participants =
                          List<String>.from(data?['participants'] ?? []);

                      if (isChannel) {
                        if (!participants.contains(_myUid)) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final updatedParticipants = [
                                  ...participants,
                                  _myUid
                                ];

                                String myName = 'User';
                                final myUserDoc = await FirebaseFirestore
                                    .instance
                                    .collection('users')
                                    .doc(_myUid)
                                    .get();
                                if (myUserDoc.exists) {
                                  myName = myUserDoc.data()?['displayName']
                                          as String? ??
                                      'User';
                                }

                                await FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(widget.chatId)
                                    .update({
                                  'participants': updatedParticipants,
                                  'userNames.$_myUid': myName,
                                });
                              },
                              child: ValueListenableBuilder<String>(
                                valueListenable:
                                    LocalizationService.langNotifier,
                                builder: (context, _, __) => Text(
                                  LocalizationService.translate('join_channel'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        if (createdBy != _myUid) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              border: Border(
                                top: BorderSide(
                                  color:
                                      isDark ? Colors.white10 : Colors.black12,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                LocalizationService.translate(
                                    'only_admins_post'),
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    }
                    return _buildInputBar();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockBanner(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Decoration? _getWallpaperDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_wallpaperType == 'solid') {
      try {
        final color = Color(int.parse(_wallpaperValue));
        return BoxDecoration(color: color);
      } catch (e) {
        print("Error parsing solid wallpaper color: $e");
      }
    } else if (_wallpaperType == 'gradient') {
      final index = int.tryParse(_wallpaperValue) ?? 0;
      final gradients = [
        [
          const Color(0xFF1E293B),
          const Color(0xFF0F172A)
        ], // Dark Slate (Default)
        [
          const Color(0xFFEEF2F6),
          const Color(0xFFDDE3EA)
        ], // Light Gray (Default)
        [const Color(0xFFFF9A9E), const Color(0xFFFECFEF)], // Pink Gradient
        [const Color(0xFFA1C4FD), const Color(0xFFC2E9FB)], // Sky Blue Gradient
        [const Color(0xFF3B0066), const Color(0xFF1A0033)], // Purple Night
        [
          const Color(0xFF0F2027),
          const Color(0xFF203A43),
          const Color(0xFF2C5364)
        ], // Midnight Blue
      ];
      final colors = index < gradients.length ? gradients[index] : gradients[0];
      return BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else if (_wallpaperType == 'image') {
      final imageProvider = AppImage.provider(_wallpaperValue);
      if (imageProvider != null) {
        return BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    // Default background
    return BoxDecoration(
      color: isDark ? const Color(0xFF0B141B) : const Color(0xFFE5DDD5),
    );
  }

  void _showAddParticipantSheet(
      String chatId, List<String> currentParticipants) {
    showKakkuFloatingBottomSheet(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A\'zo qo\'shish (Add Subscriber)',
                style: AppTextStyles.title().copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!.docs
                        .where((doc) => !currentParticipants.contains(doc.id))
                        .toList();
                    if (users.isEmpty) {
                      return Center(
                          child: Text(LocalizationService.of(context).get('no_new_users_to_add')));
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userDoc = users[index];
                        final userData = userDoc.data() as Map<String, dynamic>;
                        final displayName =
                            userData['displayName'] as String? ?? 'User';
                        final photoURL = userData['photoURL'] as String?;
                        final hasPhoto = photoURL != null &&
                            photoURL.startsWith('data:image');
                        final gradient = AppColors.avatarGradients[
                            displayName.length %
                                AppColors.avatarGradients.length];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: hasPhoto
                                  ? null
                                  : LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: hasPhoto
                                  ? Image.memory(
                                      base64Decode(photoURL.split(',').last),
                                      fit: BoxFit.cover,
                                      width: 36,
                                      height: 36,
                                    )
                                  : Center(
                                      child: Text(
                                        displayName.isNotEmpty
                                            ? displayName
                                                .substring(0, 1)
                                                .toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(displayName,
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black)),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                color: AppColors.primary),
                            onPressed: () async {
                              try {
                                final updatedParticipants = [
                                  ...currentParticipants,
                                  userDoc.id
                                ];

                                await FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(chatId)
                                    .update({
                                  'participants': updatedParticipants,
                                  'userNames.${userDoc.id}': displayName,
                                });

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(LocalizationService.of(context).get('member_added_named', args: {'name': displayName}))),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(LocalizationService.formatError(e)),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupOrChannelInfoSheet() {
    showKakkuFloatingBottomSheet(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Text(LocalizationService.formatError(snapshot.error),
                      style: const TextStyle(color: Colors.red)),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final id = data['id'] as String;
            final isChannel = data['isChannel'] as bool? ?? false;
            final groupName = data['groupName'] as String? ?? 'Group';
            final createdBy = data['createdBy'] as String?;
            final participants = List<String>.from(data['participants'] ?? []);
            final photoURL = data['groupAvatar'] as String?;
            final type = data['type'] as String? ?? 'public';
            String inviteLink = data['inviteLink'] as String? ?? '';
            final existingCode = data['inviteCode'] as String?;
            if (inviteLink.isEmpty || inviteLink.contains('t.me/')) {
              final code = existingCode ??
                  InviteLinkService.generateInviteCode(isChannel: isChannel);
              inviteLink = InviteLinkService.formatInviteLink(code);
              FirebaseFirestore.instance.collection('chats').doc(id).update({
                'inviteLink': inviteLink,
                'inviteCode': code,
              });
            }

            final hasPhoto =
                photoURL != null && photoURL.startsWith('data:image');
            final gradient = AppColors.avatarGradients[
                groupName.length % AppColors.avatarGradients.length];
            final isAdmin = createdBy == _myUid;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: hasPhoto
                            ? null
                            : LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: hasPhoto
                            ? Image.memory(
                                base64Decode(photoURL.split(',').last),
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                              )
                            : Center(
                                child: Text(
                                  groupName.isNotEmpty
                                      ? groupName.substring(0, 1).toUpperCase()
                                      : 'G',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          groupName,
                          style: AppTextStyles.h1().copyWith(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.blue, size: 20),
                            tooltip: LocalizationService.of(context).get('edit'),
                            onPressed: () => _showEditChannelDialog(
                                id, groupName, type, photoURL),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.settings_rounded,
                                color: Colors.blue, size: 22),
                            tooltip: LocalizationService.of(context).get('profile_and_settings'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChannelGroupProfilePage(
                                    chatId: widget.chatId,
                                    currentUserId: _myUid ?? '',
                                    currentUserName: _myUserName,
                                    chatRepository: _chatRepository,
                                  ),
                                ),
                              );
                            },
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Text(
                        isChannel
                            ? (type == 'public'
                                ? LocalizationService.of(context).get('public_channel_option')
                                : LocalizationService.of(context).get('private_channel_option'))
                            : LocalizationService.of(context).get('group_chat'),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    isChannel
                        ? '${LocalizationService.of(context).get('channel_link')}:'
                        : '${LocalizationService.of(context).get('group_link')}:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            inviteLink,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: LocalizationService.of(context).get('copy'),
                        icon: const Icon(Icons.copy_rounded,
                            color: Colors.blue),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: inviteLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(LocalizationService.of(context).get('link_copied_success'))),
                          );
                        },
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: LocalizationService.of(context).get('refresh_link_tooltip'),
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.orangeAccent),
                          onPressed: () {
                            _showRegenerateLinkConfirmation(id, isChannel);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${LocalizationService.of(context).get('members')} (${participants.length}):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isAdmin)
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(LocalizationService.of(context).get('add')),
                          onPressed: () =>
                              _showAddParticipantSheet(id, participants),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(id)
                          .collection('members')
                          .snapshots(),
                      builder: (context, memberSnap) {
                        if (memberSnap.hasData &&
                            memberSnap.data!.docs.isNotEmpty) {
                          final members = memberSnap.data!.docs
                              .map((doc) => ChatMemberModel.fromFirestore(doc))
                              .toList();

                          return ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final isThisMemberOwner =
                                  member.isOwner || member.userId == createdBy;
                              final isThisMemberAdmin = member.isAdmin;
                              final canManage = (createdBy == _myUid ||
                                      (_currentMember?.isOwner ?? false) ||
                                      (_currentMember?.isAdmin ?? false)) &&
                                  member.userId != _myUid;

                              final hasPhoto = member.photoURL != null &&
                                  member.photoURL!.startsWith('data:image');
                              final gradient = AppColors.avatarGradients[
                                  member.displayName.length %
                                      AppColors.avatarGradients.length];

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: canManage
                                    ? () => _showMemberManagementModal(
                                        id, member, isChannel)
                                    : null,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: hasPhoto
                                        ? null
                                        : LinearGradient(
                                            colors: gradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: hasPhoto
                                        ? Image.memory(
                                            base64Decode(member.photoURL!
                                                .split(',')
                                                .last),
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                          )
                                        : Center(
                                            child: Text(
                                              member.displayName.isNotEmpty
                                                  ? member.displayName
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  member.displayName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  member.customTitle ??
                                      (isThisMemberOwner
                                          ? LocalizationService.of(context).get('owner')
                                          : (isThisMemberAdmin
                                              ? LocalizationService.of(context).get('admin')
                                              : (member.isRestricted
                                                  ? LocalizationService.of(context).get('restricted')
                                                  : LocalizationService.of(context).get('member')))),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isThisMemberOwner
                                        ? Colors.amber
                                        : (isThisMemberAdmin
                                            ? Colors.blue
                                            : (member.isRestricted
                                                ? Colors.redAccent
                                                : (isDark
                                                    ? Colors.white54
                                                    : Colors.black54))),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isThisMemberOwner
                                            ? Colors.amber.withOpacity(0.15)
                                            : (isThisMemberAdmin
                                                ? Colors.blue.withOpacity(0.15)
                                                : (member.isRestricted
                                                    ? Colors.redAccent
                                                        .withOpacity(0.15)
                                                    : (isDark
                                                        ? Colors.white10
                                                        : Colors.black12))),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isThisMemberOwner
                                            ? '👑 ${LocalizationService.of(context).get('owner')}'
                                            : (isThisMemberAdmin
                                                ? '⭐️ ${LocalizationService.of(context).get('admin')}'
                                                : (member.isRestricted
                                                    ? '🚫 ${LocalizationService.of(context).get('restricted')}'
                                                    : LocalizationService.of(context).get('member'))),
                                        style: TextStyle(
                                          color: isThisMemberOwner
                                              ? Colors.amber
                                              : (isThisMemberAdmin
                                                  ? Colors.blue
                                                  : (member.isRestricted
                                                      ? Colors.redAccent
                                                      : (isDark
                                                          ? Colors.white70
                                                          : Colors.black87))),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (canManage) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.more_vert_rounded,
                                          size: 18,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        }

                        // Legacy fallback
                        return ListView.builder(
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final pId = participants[index];
                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(pId)
                                  .snapshots(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData ||
                                    !userSnap.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                final uData = userSnap.data!.data()
                                    as Map<String, dynamic>;
                                final pName =
                                    uData['displayName'] as String? ?? 'User';
                                final pPhoto = uData['photoURL'] as String?;
                                final pHasPhoto = pPhoto != null &&
                                    pPhoto.startsWith('data:image');
                                final pGradient = AppColors.avatarGradients[
                                    pName.length %
                                        AppColors.avatarGradients.length];

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: pHasPhoto
                                          ? null
                                          : LinearGradient(
                                              colors: pGradient,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: pHasPhoto
                                          ? Image.memory(
                                              base64Decode(
                                                  pPhoto.split(',').last),
                                              fit: BoxFit.cover,
                                              width: 36,
                                              height: 36,
                                            )
                                          : Center(
                                              child: Text(
                                                pName.isNotEmpty
                                                    ? pName
                                                        .substring(0, 1)
                                                        .toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    pName,
                                    style: TextStyle(
                                      color:
                                          isDark ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: pId == createdBy
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Admin',
                                            style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : (isAdmin
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.person_remove_rounded,
                                                  color: Colors.redAccent,
                                                  size: 20),
                                              onPressed: () =>
                                                  _chatRepository.removeMember(
                                                      id, pId),
                                            )
                                          : null),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever_rounded,
                            color: Colors.white),
                        label: Text(
                            isChannel
                                ? LocalizationService.of(context).get('delete_channel_completely')
                                : LocalizationService.of(context).get('delete_group_completely'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close sheet
                          _showDeleteChannelConfirmation(id, isChannel);
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.redAccent),
                        label: Text(
                            isChannel
                                ? LocalizationService.of(context).get('leave_channel')
                                : LocalizationService.of(context).get('leave_group'),
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close sheet
                          _showLeaveChatConfirmation(id, isChannel);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRegenerateLinkConfirmation(String chatId, bool isChannel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.of(ctx).get('regenerate_link_title'),
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(LocalizationService.of(ctx).get('regenerate_link_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.of(ctx).get('cancel')),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final newLink = await InviteLinkService.regenerateInviteLink(
                  chatId: chatId,
                  isChannel: isChannel,
                );
                if (mounted) {
                  Clipboard.setData(ClipboardData(text: newLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.of(context).get('new_link_created')),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(LocalizationService.formatError(e)),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(LocalizationService.of(ctx).get('regenerate_link_action'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLeaveChatConfirmation(String chatId, bool isChannel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isChannel
              ? LocalizationService.translate('leave_channel')
              : LocalizationService.translate('leave_group'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isChannel
              ? LocalizationService.translate('leave_channel_confirm')
              : LocalizationService.translate('leave_group_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                if (_myUid != null) {
                  final chatRef = FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId);
                  await chatRef.update({
                    'participants': FieldValue.arrayRemove([_myUid]),
                  });

                  String myName = 'Foydalanuvchi';
                  try {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_myUid)
                        .get();
                    if (userDoc.exists) {
                      myName = userDoc.data()?['displayName'] as String? ??
                          myName;
                    }
                  } catch (_) {}

                  final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
                  await chatRef.collection('messages').doc(msgId).set({
                    'id': msgId,
                    'senderId': 'system',
                    'text': isChannel
                        ? '$myName kanalni tark etdi'
                        : '$myName guruhni tark etdi',
                    'type': 'text',
                    'isRead': false,
                    'isDeleted': false,
                    'timestamp': FieldValue.serverTimestamp(),
                    'reactions': {},
                  });
                }
                if (mounted) {
                  Navigator.of(context).pop(); // Exit MessagePage!
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isChannel
                          ? LocalizationService.translate('channel_left')
                          : LocalizationService.translate('group_left')),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(LocalizationService.formatError(e)),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(LocalizationService.translate('leave'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteChannelConfirmation(String chatId, bool isChannel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isChannel
              ? LocalizationService.translate('delete_channel')
              : LocalizationService.translate('delete_group'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isChannel
              ? LocalizationService.translate('delete_channel_confirm')
              : LocalizationService.translate('delete_group_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .delete();
                if (mounted) {
                  Navigator.of(context).pop(); // Exit MessagePage!
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          LocalizationService.translate('successfully_deleted')),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(LocalizationService.formatError(e)),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(LocalizationService.of(ctx).get('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMemberManagementModal(
      String chatId, ChatMember member, bool isChannel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwnerViewer = _cachedMyUid != null &&
        (_chatDoc?.data() as Map<String, dynamic>?)?['createdBy'] ==
            _cachedMyUid;

    showKakkuFloatingBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            member.customTitle ?? member.role.localizedName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // 1. Promote to Admin or Demote to Member
                if (isOwnerViewer) ...[
                  if (!member.isAdmin)
                    ListTile(
                      leading:
                          const Icon(Icons.star_rounded, color: Colors.blue),
                      title: Text(LocalizationService.of(ctx).get('assign_as_admin')),
                      subtitle: Text(LocalizationService.of(ctx).get('assign_as_admin_desc')),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _chatRepository.updateMemberRole(
                          chatId,
                          member.userId,
                          MemberRole.admin,
                          customTitle: '⭐️ Admin',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocalizationService.of(context).get('assigned_as_admin_named', args: {'name': member.displayName})),
                            ),
                          );
                        }
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.star_border_rounded,
                          color: Colors.orange),
                      title: Text(LocalizationService.of(ctx).get('dismiss_admin')),
                      subtitle: Text(LocalizationService.of(ctx).get('ordinary_member')),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _chatRepository.updateMemberRole(
                          chatId,
                          member.userId,
                          MemberRole.member,
                          customTitle: 'A\'zo',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocalizationService.of(context).get('dismissed_admin_named', args: {'name': member.displayName})),
                            ),
                          );
                        }
                      },
                    ),
                ],

                // 2. Restrict sending messages in group
                if (!isChannel && !member.isOwner) ...[
                  ListTile(
                    leading: Icon(
                      member.permissions.canSendMessages
                          ? Icons.speaker_notes_off_rounded
                          : Icons.speaker_notes_rounded,
                      color: member.permissions.canSendMessages
                          ? Colors.orangeAccent
                          : Colors.green,
                    ),
                    title: Text(
                      member.permissions.canSendMessages
                          ? LocalizationService.of(ctx).get('restrict_sending_messages')
                          : LocalizationService.of(ctx).get('allow_sending_messages'),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final updated = member.permissions.copyWith(
                        canSendMessages: !member.permissions.canSendMessages,
                      );
                      await _chatRepository.updateMemberPermissions(
                        chatId,
                        member.userId,
                        updated,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              updated.canSendMessages
                                  ? LocalizationService.of(context).get('messages_allowed_for_named', args: {'name': member.displayName})
                                  : LocalizationService.of(context).get('messages_restricted_for_named', args: {'name': member.displayName}),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],

                // 3. Kick / Remove member
                ListTile(
                  leading: const Icon(Icons.person_remove_rounded,
                      color: Colors.redAccent),
                  title: Text(
                    LocalizationService.of(ctx).get('remove_from_group_kick'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _chatRepository.removeMember(chatId, member.userId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LocalizationService.of(context).get('member_removed_named', args: {'name': member.displayName})),
                        ),
                      );
                    }
                  },
                ),

                // 4. Transfer Ownership
                if (isOwnerViewer && !member.isOwner) ...[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.amber),
                    title: Text(
                      LocalizationService.of(ctx).get('transfer_ownership_title'),
                      style: const TextStyle(color: Colors.amber),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      _showTransferOwnershipDialog(chatId, member);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTransferOwnershipDialog(String chatId, ChatMember member) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(LocalizationService.of(ctx).get('transfer_ownership')),
          content: Text(LocalizationService.of(ctx).get('transfer_ownership_desc', args: {'name': member.displayName})),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(LocalizationService.of(ctx).get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _chatRepository.transferOwnership(chatId, member.userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.of(context).get('ownership_transferred_named', args: {'name': member.displayName})),
                    ),
                  );
                }
              },
              child: Text(LocalizationService.of(ctx).get('confirm_transfer_ownership'),
                  style: const TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showEditChannelDialog(String chatId, String currentName,
      String currentType, String? currentAvatar) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: currentName);
    String selectedType = currentType;
    String? selectedAvatar = currentAvatar;
    String? newLink;
    bool isPicking = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasPhoto = selectedAvatar != null &&
                selectedAvatar!.startsWith('data:image');
            final gradient = AppColors.avatarGradients[
                nameCtrl.text.length % AppColors.avatarGradients.length];

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(LocalizationService.of(context).get('edit_channel'),
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (isPicking) return;
                        setDialogState(() => isPicking = true);
                        try {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 512,
                              maxHeight: 512);
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            final base64Image = base64Encode(bytes);
                            setDialogState(() {
                              selectedAvatar =
                                  "data:image/jpeg;base64,$base64Image";
                            });
                          }
                        } catch (e) {
                          print("Edit avatar picker error: $e");
                        } finally {
                          setDialogState(() => isPicking = false);
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: hasPhoto
                              ? null
                              : LinearGradient(
                                  colors: gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          children: [
                            ClipOval(
                              child: hasPhoto
                                  ? Image.memory(
                                      base64Decode(
                                          selectedAvatar!.split(',').last),
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                    )
                                  : const Center(
                                      child: Icon(Icons.camera_alt_rounded,
                                          color: Colors.white, size: 30),
                                    ),
                            ),
                            if (hasPhoto)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: LocalizationService.of(context).get('channel_name_label'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: LocalizationService.of(context).get('channel_type_label'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'public',
                            child: Text(LocalizationService.of(context).get('public_channel_option'))),
                        DropdownMenuItem(
                            value: 'private',
                            child: Text(LocalizationService.of(context).get('private_channel_option'))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(LocalizationService.of(context).get('generate_new_link_btn')),
                      onPressed: () {
                        final chars =
                            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                        final rand = Random();
                        final code = String.fromCharCodes(Iterable.generate(
                            16,
                            (_) =>
                                chars.codeUnitAt(rand.nextInt(chars.length))));

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(LocalizationService.of(context).get('new_link_generated_press_save'))),
                        );

                        setDialogState(() {
                          newLink = 'app://join/c_$code';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(LocalizationService.of(ctx).get('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final updates = <String, dynamic>{
                        'groupName': nameCtrl.text.trim(),
                        'type': selectedType,
                        'groupAvatar': selectedAvatar,
                      };

                      if (newLink != null) {
                        updates['inviteLink'] = newLink;
                      }

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .update(updates);

                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(LocalizationService.of(context).get('channel_settings_saved'))),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(LocalizationService.formatError(e)),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text(LocalizationService.of(ctx).get('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUserInfoSheet({
    required String displayName,
    required String? photoURL,
    required String statusText,
    required Color statusColor,
    required String email,
  }) {
    showKakkuFloatingBottomSheet(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final hasPhoto = photoURL != null &&
            photoURL.startsWith('data:image') &&
            _otherUserPhotoBytes != null;
        final gradient = AppColors.avatarGradients[
            displayName.length % AppColors.avatarGradients.length];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_myUid)
              .snapshots(),
          builder: (context, userSnap) {
            List<String> blockedUsers = [];
            if (userSnap.hasData && userSnap.data!.exists) {
              final uData = userSnap.data!.data() as Map<String, dynamic>?;
              blockedUsers = List<String>.from(uData?['blockedUsers'] ?? []);
            }
            final isBlocked = blockedUsers.contains(widget.otherUserId);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: hasPhoto
                          ? null
                          : LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasPhoto
                          ? AppImage.memory(
                              photoURL,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )
                          : Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: AppTextStyles.h1().copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: AppTextStyles.caption().copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 24),
                  if (email.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.email_outlined,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.translate('email_hint'),
                                style: AppTextStyles.caption().copyWith(
                                  color: isDark ? Colors.white38 : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: AppTextStyles.body().copyWith(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.87)
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        LocalizationService.translate('cancel'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (widget.otherUserId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.lock_rounded,
                          color: Colors.green,
                        ),
                        label: Text(
                          LocalizationService.translate('start_secret_chat'),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(LocalizationService.translate(
                                        'start_secret_chat')),
                                  ],
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            final repo = SecretChatRepositoryImpl();
                            final session = await repo.createSecretChatSession(
                              recipientUid: widget.otherUserId,
                              selfDestructDuration: 0,
                            );
                            if (mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) => SecretChatBloc(
                                      repository: repo,
                                    ),
                                    child: SecretChatPage(
                                      chatId: session.chatId,
                                      otherUserId: widget.otherUserId,
                                      otherUserName: displayName,
                                      otherUserPhoto: photoURL,
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e
                                      .toString()
                                      .replaceAll('Exception: ', '')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(
                          isBlocked
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          color: isBlocked ? Colors.green : Colors.red,
                        ),
                        label: Text(
                          isBlocked
                              ? LocalizationService.of(context).get('unblock_user')
                              : LocalizationService.of(context).get('block_user'),
                          style: TextStyle(
                            color: isBlocked ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: isBlocked ? Colors.green : Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            if (isBlocked) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_myUid)
                                  .update({
                                'blockedUsers': FieldValue.arrayRemove(
                                    [widget.otherUserId]),
                              });
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_myUid)
                                  .update({
                                'blockedUsers':
                                    FieldValue.arrayUnion([widget.otherUserId]),
                              });
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isBlocked
                                      ? LocalizationService.of(context).get('user_unblocked_success')
                                      : LocalizationService.of(context).get('user_blocked_success')),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(LocalizationService.formatError(e)),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
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

  void _showWallpaperMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_myUid)
              .snapshots(),
          builder: (context, userSnapshot) {
            bool showLastSeen = true;
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final data = userSnapshot.data!.data() as Map<String, dynamic>?;
              showLastSeen = data?['showLastSeen'] as bool? ?? true;
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      LocalizationService.translate('options_wallpapers'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                        showLastSeen
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.blue),
                    title: Text(
                        LocalizationService.translate('last_seen_privacy')),
                    subtitle: Text(showLastSeen
                        ? LocalizationService.translate('last_seen_visible')
                        : LocalizationService.translate('last_seen_hidden')),
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(_myUid)
                          .update({
                        'showLastSeen': !showLastSeen,
                      });
                      Navigator.of(ctx).pop();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.color_lens_rounded,
                        color: Colors.blue),
                    title: Text(LocalizationService.of(ctx).get('wallpaper_lavender')),
                    onTap: () {
                      _saveWallpaper('solid', '0xFFE0E0FF');
                      Navigator.of(ctx).pop();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.gradient_rounded,
                        color: Colors.purple),
                    title: Text(LocalizationService.of(ctx).get('wallpaper_pink_dusk')),
                    onTap: () {
                      _saveWallpaper('gradient', '2');
                      Navigator.of(ctx).pop();
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.gradient_rounded, color: Colors.teal),
                    title: Text(LocalizationService.of(ctx).get('wallpaper_midnight_blue')),
                    onTap: () {
                      _saveWallpaper('gradient', '5');
                      Navigator.of(ctx).pop();
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.image_rounded, color: Colors.orange),
                    title: Text(LocalizationService.of(ctx).get('wallpaper_custom_gallery')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickCustomWallpaper();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded,
                        color: Colors.grey),
                    title: Text(LocalizationService.of(ctx).get('default_option')),
                    onTap: () {
                      _saveWallpaper('default', '');
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveWallpaper(String type, String value) {
    setState(() {
      _wallpaperType = type;
      _wallpaperValue = value;
    });
    _settingsBox?.put('wallpaper_type_${widget.chatId}', type);
    _settingsBox?.put('wallpaper_val_${widget.chatId}', value);
  }

  void _pickCustomWallpaper() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1080,
      maxHeight: 1920,
    );
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      _saveWallpaper('image', base64Image);
    }
  }

  void _showMessageMenu(Message message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = message.senderId == _myUid;

    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    final isChannel = chatData?['isChannel'] as bool? ?? false;
    final createdBy = chatData?['createdBy'] as String?;
    final isChannelAdmin = _myUid != null &&
        (createdBy == _myUid || (_currentMember?.isAdmin ?? false));
    final isProtected = chatData?['restrictContent'] as bool? ?? false;

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reactions Row (Telegram-style quick reaction bar)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      '👍', '❤️', '🔥', '🎉', '👏', '😂', '😮', '😢', '🙏', '💯', '🤔', '⚡'
                    ].map((emoji) {
                      final hasReacted = message.reactions[_myUid] == emoji;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            if (_myUid == null) return;
                            context.read<MessageBloc>().add(
                                  ToggleReactionRequested(
                                    chatId: widget.chatId,
                                    messageId: message.id,
                                    userId: _myUid!,
                                    emoji: emoji,
                                  ),
                                );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasReacted
                                  ? AppColors.primary.withOpacity(0.18)
                                  : (isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.04)),
                              shape: BoxShape.circle,
                              border: hasReacted
                                  ? Border.all(
                                      color: AppColors.primary, width: 1.8)
                                  : null,
                            ),
                            child:
                                Text(emoji, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1),
              if (isChannel)
                ListTile(
                  leading: const Icon(Icons.mode_comment_outlined,
                      color: AppColors.primary),
                  title: Text(
                    message.commentsCount > 0
                        ? '${LocalizationService.translate('comments')} (${message.commentsCount})'
                        : LocalizationService.translate('leave_comment'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openPostComments(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(LocalizationService.translate('reply_option')),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _replyingTo = message;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.forward_rounded,
                    color: isProtected ? Colors.grey : null),
                title: Text(LocalizationService.translate('forward_option'),
                    style: TextStyle(color: isProtected ? Colors.grey : null)),
                subtitle: isProtected
                    ? Text(LocalizationService.of(context).get('forward_restricted'),
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  if (isProtected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.of(context).get('forward_prohibited_here')),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  _showForwardBottomSheet(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.bookmark_add_rounded,
                    color: isProtected ? Colors.grey : AppColors.primary),
                title: Text(LocalizationService.translate('save_to_saved_messages'),
                    style: TextStyle(color: isProtected ? Colors.grey : null)),
                subtitle: isProtected
                    ? Text(LocalizationService.of(context).get('save_restricted'),
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey))
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  if (isProtected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.of(context).get('saving_prohibited_here')),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  _saveMessageToSavedMessages(message);
                },
              ),
              if (message.text != null && message.text!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.copy_rounded,
                      color: isProtected ? Colors.grey : null),
                  title: Text(LocalizationService.of(context).get('copy_action_title'),
                      style: TextStyle(color: isProtected ? Colors.grey : null)),
                  subtitle: isProtected
                      ? Text(LocalizationService.of(context).get('copying_prohibited'),
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey))
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isProtected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LocalizationService.of(context).get('copying_prohibited_here')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: message.text!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.of(context).get('message_copied_success')),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    bool isPinned = false;
                    final List<String> pinnedIds = [];
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final rawPinned =
                          List<String>.from(data?['pinnedMessageIds'] ?? []);
                      pinnedIds.addAll(rawPinned);
                      final legacyPin = data?['pinnedMessageId'] as String?;
                      if (legacyPin != null &&
                          legacyPin.isNotEmpty &&
                          !pinnedIds.contains(legacyPin)) {
                        pinnedIds.add(legacyPin);
                      }
                      isPinned = pinnedIds.contains(message.id);
                    }
                    return ListTile(
                      leading: Icon(isPinned
                          ? Icons.pin_drop_rounded
                          : Icons.push_pin_rounded),
                      title: Text(isPinned
                          ? LocalizationService.translate('unpin_option')
                          : LocalizationService.translate('pin_option')),
                      onTap: () {
                        Navigator.of(context).pop();
                        if (!_canPinMessages) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocalizationService.of(context).get('pin_restricted')),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        context.read<MessageBloc>().add(PinMessageRequested(
                              chatId: widget.chatId,
                              messageId: message.id,
                              isUnpin: isPinned,
                            ));
                      },
                    );
                  }),
              if ((isMe || (isChannel && isChannelAdmin)) &&
                  message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: Text(LocalizationService.translate('edit_option')),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _editingMessage = message;
                      _textController.text = message.text ?? '';
                      _replyingTo = null;
                    });
                  },
                ),
              if (isMe)
                ListTile(
                  leading:
                      const Icon(Icons.delete_rounded, color: AppColors.error),
                  title: Text(LocalizationService.translate('delete_option'),
                      style: const TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDeleteDialog(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showForwardBottomSheet(Message message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '${LocalizationService.translate('forward_option')} →',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 20),
                ),
                title: Text(
                  LocalizationService.translate('saved_messages'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  LocalizationService.translate('private_storage'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _saveMessageToSavedMessages(message);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('chats')
                      .where('participants', arrayContains: _myUid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs
                        .where((d) => d.id != widget.chatId)
                        .toList();
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(LocalizationService.of(context).get('no_other_chats')),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final chatDoc = docs[index];
                        final data = chatDoc.data() as Map<String, dynamic>;
                        final isGroup = data['isGroup'] as bool? ?? false;
                        final isChannel = data['isChannel'] as bool? ?? false;
                        final chatParticipants =
                            List<String>.from(data['participants'] ?? []);
                        final names =
                            data['userNames'] as Map<String, dynamic>? ?? {};

                        // Guruh/kanal nomini yoki boshqa foydalanuvchi nomini ko'rsatish
                        String displayName;
                        IconData leadingIcon;
                        if (isGroup || isChannel) {
                          displayName = data['groupName'] as String? ?? 'Group';
                          leadingIcon = isChannel
                              ? Icons.campaign_rounded
                              : Icons.group_rounded;
                        } else {
                          final otherId = chatParticipants.firstWhere(
                            (id) => id != _myUid,
                            orElse: () => '',
                          );
                          displayName = names[otherId] as String? ?? 'User';
                          leadingIcon = Icons.person_rounded;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withAlpha(30),
                            child: Icon(leadingIcon,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                          ),
                          subtitle: Text(
                            isChannel
                                ? 'Kanal'
                                : (isGroup ? 'Guruh' : 'Shaxsiy'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            context.read<MessageBloc>().add(SendTextMessage(
                                  chatId: chatDoc.id,
                                  senderId: _cachedMyUid!,
                                  text: message.text ?? '',
                                  imageUrl: message.imageUrl,
                                  fileUrl: message.fileUrl,
                                  fileName: message.fileName,
                                  fileSize: message.fileSize,
                                  type: message.type,
                                  isForwarded: true,
                                ));
                            // Increment forwardCount in Firestore
                            FirebaseFirestore.instance
                                .collection('chats')
                                .doc(widget.chatId)
                                .collection('messages')
                                .doc(message.id)
                                .update({'forwardCount': FieldValue.increment(1)});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"$displayName" ga yuborildi!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveMessageToSavedMessages(Message message) async {
    if (widget.chatId.startsWith('secret_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.translate('secret_chat_forward_blocked')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final savedService = SavedMessageService();
      await savedService.saveForwardedMessage(
        uid: _cachedMyUid ?? _myUid ?? '',
        message: message,
        originalSenderName: widget.otherUserName,
        originalChatId: widget.chatId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(LocalizationService.translate('saved_successfully')),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService.translate("save_failed")}: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(Message message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.of(ctx).get('delete_message_title')),
        content: Text(LocalizationService.of(ctx).get('delete_message_confirm')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.of(ctx).get('cancel')),
          ),
          TextButton(
            onPressed: () {
              context.read<MessageBloc>().add(DeleteMessageRequested(
                    widget.chatId,
                    message.id,
                  ));
              Navigator.of(ctx).pop();
            },
            child: Text(LocalizationService.of(ctx).get('delete'),
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openImageFullscreen(Message message) {
    final url = message.imageUrl ?? message.fileUrl ?? '';
    if (url.startsWith('data:image')) {
      final decoded = AppImage.decode(url);
      if (decoded != null) {
        _showFullScreenImage(decoded);
        return;
      }
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: url.startsWith('http')
                      ? Image.network(url, fit: BoxFit.contain)
                      : (File(url).existsSync()
                          ? Image.file(File(url), fit: BoxFit.contain)
                          : const Icon(Icons.broken_image_rounded,
                              color: Colors.white54, size: 64)),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildImageBubbleContent(
    Message message,
    bool isMe,
    bool isDark,
    BorderRadius bubbleRadius,
    bool hasCaption,
  ) {
    final url = message.imageUrl ?? message.fileUrl ?? '';
    final maxBubbleWidth =
        (MediaQuery.of(context).size.width * 0.78).clamp(210.0, 280.0);
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    Widget imageWidget;
    if (url.startsWith('data:image')) {
      imageWidget = AppImage.memory(
        url,
        fit: BoxFit.cover,
        width: maxBubbleWidth,
        height: 220,
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        width: maxBubbleWidth,
        height: 220,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: maxBubbleWidth,
            height: 220,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: maxBubbleWidth,
          height: 180,
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          child: const Center(
            child:
                Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
          ),
        ),
      );
    } else if (url.isNotEmpty && File(url).existsSync()) {
      imageWidget = Image.file(
        File(url),
        fit: BoxFit.cover,
        width: maxBubbleWidth,
        height: 220,
      );
    } else {
      imageWidget = Container(
        width: maxBubbleWidth,
        height: 180,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 40),
        ),
      );
    }

    final imageRadius = hasCaption
        ? BorderRadius.only(
            topLeft: bubbleRadius.topLeft,
            topRight: bubbleRadius.topRight,
          )
        : bubbleRadius;

    return GestureDetector(
      onTap: () => _openImageFullscreen(message),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: imageRadius,
            child: imageWidget,
          ),
          if (!hasCaption)
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited) ...[
                      Text(
                        '(${LocalizationService.translate('edited')})',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      _buildMessageStatusIcon(message, size: 12),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullScreenImage(Uint8List bytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon:
                        const Icon(Icons.download_rounded, color: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(LocalizationService.of(context).get('image_saved_success'))),
                      );
                    },
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showSelfDestructMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  LocalizationService.translate('self_destruct_title'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.timer_off_rounded,
                    color: _selfDestructDuration == null
                        ? AppColors.primary
                        : Colors.grey),
                title: Text(LocalizationService.translate('off_option')),
                onTap: () {
                  setState(() => _selfDestructDuration = null);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.timer_rounded,
                    color: _selfDestructDuration == 5
                        ? AppColors.primary
                        : Colors.grey),
                title: Text(
                    '5 ${LocalizationService.translate('seconds_option')}'),
                onTap: () {
                  setState(() => _selfDestructDuration = 5);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.timer_rounded,
                    color: _selfDestructDuration == 10
                        ? AppColors.primary
                        : Colors.grey),
                title: Text(
                    '10 ${LocalizationService.translate('seconds_option')}'),
                onTap: () {
                  setState(() => _selfDestructDuration = 10);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.timer_rounded,
                    color: _selfDestructDuration == 30
                        ? AppColors.primary
                        : Colors.grey),
                title: Text(
                    '30 ${LocalizationService.translate('seconds_option')}'),
                onTap: () {
                  setState(() => _selfDestructDuration = 30);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _localizeSystemMessageText(String rawText) {
    final trimmed = rawText.trim();
    // Channel created pattern across languages:
    // EN: Channel "Namangan" created.
    // UZ: "Namangan" kanali yaratildi. or Kanal "Namangan" yaratildi.
    // RU: Канал "Namangan" создан.
    final chMatch1 = RegExp(r'^Channel\s+"([^"]+)"\s+created\.?$', caseSensitive: false).firstMatch(trimmed);
    final chMatch2 = RegExp(r'^"([^"]+)"\s+kanali\s+yaratildi\.?$', caseSensitive: false).firstMatch(trimmed);
    final chMatch3 = RegExp(r'^Kanal\s+"([^"]+)"\s+yaratildi\.?$', caseSensitive: false).firstMatch(trimmed);
    final chMatch4 = RegExp(r'^Канал\s+"([^"]+)"\s+создан\.?$', caseSensitive: false).firstMatch(trimmed);
    final chName = chMatch1?.group(1) ?? chMatch2?.group(1) ?? chMatch3?.group(1) ?? chMatch4?.group(1);
    if (chName != null) {
      return LocalizationService.translate('channel_created_msg', params: {'name': chName});
    }

    // Group created pattern across languages:
    final grMatch1 = RegExp(r'^Group\s+"([^"]+)"\s+created\.?$', caseSensitive: false).firstMatch(trimmed);
    final grMatch2 = RegExp(r'^"([^"]+)"\s+guruhi\s+yaratildi\.?$', caseSensitive: false).firstMatch(trimmed);
    final grMatch3 = RegExp(r'^Guruh\s+"([^"]+)"\s+yaratildi\.?$', caseSensitive: false).firstMatch(trimmed);
    final grMatch4 = RegExp(r'^Группа\s+"([^"]+)"\s+создана\.?$', caseSensitive: false).firstMatch(trimmed);
    final grName = grMatch1?.group(1) ?? grMatch2?.group(1) ?? grMatch3?.group(1) ?? grMatch4?.group(1);
    if (grName != null) {
      return LocalizationService.translate('group_created_msg', params: {'name': grName});
    }

    return rawText;
  }

  Widget _buildSearchRichText(String text, String query, Color defaultColor) {
    final displayText = _localizeSystemMessageText(text);
    if (query.isEmpty || !displayText.toLowerCase().contains(query)) {
      return Text(
        displayText,
        style: AppTextStyles.messageBubble().copyWith(
          color: defaultColor,
          fontSize: 15,
          height: 1.3,
        ),
      );
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(
          text: text.substring(start, indexOfMatch),
          style: TextStyle(color: defaultColor),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: const TextStyle(
            color: Colors.black, backgroundColor: Colors.yellow),
      ));
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: defaultColor),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: AppTextStyles.messageBubble().copyWith(
          fontSize: 15,
          height: 1.3,
        ),
      ),
    );
  }

  Future<void> _joinChannelViaLink(String link) async {
    if (link.isEmpty) return;

    if (_myUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.of(context).get('user_not_authenticated'))),
        );
      }
      return;
    }

    try {
      final chatDoc = await InviteLinkService.resolveChat(link);

      if (chatDoc == null || !chatDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocalizationService.of(context).get('invalid_link_or_chat'))),
          );
        }
        return;
      }

      String myName = 'Foydalanuvchi';
      final myUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();
      if (myUserDoc.exists) {
        myName = myUserDoc.data()?['displayName'] as String? ?? myName;
      }

      if (mounted) {
        TelegramJoinPreviewSheet.show(
          context: context,
          chatDoc: chatDoc,
          currentUserId: _myUid!,
          currentUserName: myName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.formatError(e))),
        );
      }
    }
  }

  Widget _buildMessageTextWidget(
      String text, String query, Color defaultColor, {bool isMe = false}) {
    final linkRegex = RegExp(
        r'(?:https?:\/\/)?(?:chat\.me|t\.me)\/(?:\+|joinchat\/)?[a-zA-Z0-9_\-]+|app:\/\/join\/\S+');

    if (linkRegex.hasMatch(text)) {
      final matches = linkRegex.allMatches(text);
      final List<InlineSpan> spans = [];
      int start = 0;
      String? firstInviteLink;

      for (final match in matches) {
        if (match.start > start) {
          spans.add(TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(color: defaultColor),
          ));
        }

        final linkText = match.group(0)!;
        firstInviteLink ??= linkText;

        // Zero-width space after / and _ allows natural wrapping within bubble boundaries
        final displayLink = linkText
            .replaceAll('/', '/\u200B')
            .replaceAll('_', '_\u200B');

        spans.add(TextSpan(
          text: displayLink,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.blueAccent,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: isMe ? Colors.white70 : Colors.blueAccent,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _joinChannelViaLink(linkText),
        ));

        start = match.end;
      }

      if (start < text.length) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(color: defaultColor),
        ));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: spans,
              style: AppTextStyles.messageBubble().copyWith(
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
          if (firstInviteLink != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _joinChannelViaLink(firstInviteLink!),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withOpacity(0.18)
                      : AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMe
                        ? Colors.white24
                        : AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_add_rounded,
                      size: 16,
                      color: isMe ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kanalga / Guruhga qo\'shilish',
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    return _buildSearchRichText(text, query, defaultColor);
  }

  Widget _buildMessageBubble(
      Message message, bool isMe, List<Message> allMessages,
      {MessageGroupPosition grouping = MessageGroupPosition.single,
      GlobalKey? msgKey}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    final isChannel = chatData?['isChannel'] as bool? ?? false;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Find replied message snippet
    final repliedMsg = message.replyToMessageId != null
        ? allMessages.cast<Message?>().firstWhere(
            (m) => m?.id == message.replyToMessageId && !m!.isDeleted,
            orElse: () => null)
        : null;

    // Aggregate reactions
    final reactionCounts = <String, int>{};
    for (final emoji in message.reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    // Increment message views if viewed by non-sender
    if (_myUid != null &&
        message.senderId != _myUid &&
        !_viewedMessageIds.contains(message.id)) {
      _viewedMessageIds.add(message.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MessageBloc>().add(
                IncrementMessageViewRequested(
                  chatId: widget.chatId,
                  messageId: message.id,
                ),
              );
        }
      });
    }

    final bubbleRadius = ChatBubbleTheme.getBubbleRadius(isMe, grouping);
    final isGif = message.type == MessageType.gif;
    final isSticker = message.type == MessageType.sticker;
    final isVideo =
        message.type == MessageType.video && message.fileUrl != null;
    final isPoll = message.type == MessageType.poll && message.poll != null;
    final isLiveLocation = message.type == MessageType.liveLocation;
    final isLocation = message.type == MessageType.location &&
        message.latitude != null &&
        message.longitude != null;
    final isImage = message.type == MessageType.image &&
        (message.imageUrl != null || message.fileUrl != null);
    final hasCaption =
        message.text != null && message.text!.trim().isNotEmpty;
    final isStandaloneBubble = isGif ||
        isSticker ||
        isVideo ||
        isPoll ||
        isLiveLocation ||
        isLocation ||
        (isImage && !hasCaption);
    final isHighlighted = _highlightedMessageId == message.id;

    final decoration = isStandaloneBubble
        ? BoxDecoration(
            color: Colors.transparent,
            borderRadius: bubbleRadius,
            border: isHighlighted
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          )
        : ChatBubbleTheme.getBubbleDecoration(
            isMe: isMe,
            isDark: isDark,
            position: grouping,
            isHighlighted: isHighlighted,
          );

    final bubblePadding = isStandaloneBubble
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final textColor = ChatBubbleTheme.getTextColor(isMe: isMe, isDark: isDark);
    final timestampColor =
        ChatBubbleTheme.getTimestampColor(isMe: isMe, isDark: isDark);
    final secondaryIconColor =
        ChatBubbleTheme.getSecondaryIconColor(isMe: isMe, isDark: isDark);

    return GestureDetector(
      onLongPress: () => _showMessageMenu(message),
      child: Padding(
        key: msgKey,
        padding: ChatBubbleTheme.getBubbleMargin(grouping)
            .add(const EdgeInsets.symmetric(horizontal: 4.0)),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              padding: bubblePadding,
              constraints: BoxConstraints(
                maxWidth: (isGif || isSticker || isVideo || isPoll)
                    ? MediaQuery.of(context).size.width * 0.82
                    : MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: decoration,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Sender name & title in group/channel (only for first/single in consecutive group)
                  if (widget.otherUserId.isEmpty &&
                      !isMe &&
                      (grouping == MessageGroupPosition.single ||
                          grouping == MessageGroupPosition.first)) ...[
                    Builder(
                      builder: (context) {
                        final chatData =
                            _chatDoc?.data() as Map<String, dynamic>?;
                        final names =
                            chatData?['userNames'] as Map<String, dynamic>? ??
                                {};
                        final senderName =
                            names[message.senderId] as String? ?? 'User';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                senderName,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (message.senderTitle != null &&
                                  message.senderTitle!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      String displayTitle = message.senderTitle!;
                                      if (displayTitle.contains('Asoschi') ||
                                          displayTitle.contains('Owner') ||
                                          displayTitle.contains('Владелец')) {
                                        displayTitle = LocalizationService.translate('owner_badge');
                                      } else if (displayTitle.contains('Admin') ||
                                          displayTitle.contains('Админ')) {
                                        displayTitle = LocalizationService.translate('admin_badge');
                                      }
                                      return Text(
                                        displayTitle,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  // Forwarded label
                  if (message.isForwarded) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward_rounded,
                            size: 11,
                            color: isMe
                                ? Colors.white70
                                : (isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600)),
                        const SizedBox(width: 4),
                        Text(
                          'Forwarded',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: isMe
                                ? Colors.white70
                                : (isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Reply Preview in bubble
                  if (message.replyToMessageId != null) ...[
                    GestureDetector(
                      onTap: () {
                        final replyId = message.replyToMessageId!;
                        final targetKey = _messageKeys[replyId];
                        if (targetKey?.currentContext != null) {
                          Scrollable.ensureVisible(
                            targetKey!.currentContext!,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            alignment: 0.5,
                          );
                        } else {
                          // fallback: idx bilan taxminiy scroll
                          final idx =
                              allMessages.indexWhere((m) => m.id == replyId);
                          if (idx != -1 && _scrollController.hasClients) {
                            _scrollController.animateTo(
                              (idx * 80.0).clamp(0.0,
                                  _scrollController.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.14)
                              : (isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(
                              color: isMe ? Colors.white : AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repliedMsg != null
                                  ? (repliedMsg.senderId == _myUid
                                      ? 'You'
                                      : widget.otherUserName)
                                  : 'Message',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                                color:
                                    isMe ? Colors.white : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              repliedMsg?.text ??
                                  (repliedMsg?.imageUrl != null
                                      ? '📷 Photo'
                                      : (repliedMsg?.type == MessageType.location
                                          ? '📍 Location'
                                          : 'Deleted message')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (isImage) ...[
                    _buildImageBubbleContent(
                      message,
                      isMe,
                      isDark,
                      bubbleRadius,
                      hasCaption,
                    ),
                    if (hasCaption) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          right: 4,
                          top: 6,
                          bottom: 2,
                        ),
                        child: _buildMessageTextWidget(
                          message.text!,
                          _searchQuery,
                          textColor,
                          isMe: isMe,
                        ),
                      ),
                    ],
                  ] else if (message.type == MessageType.gif &&
                      message.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        message.imageUrl!,
                        fit: BoxFit.cover,
                        width: 180,
                        height: 180,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 180,
                            height: 180,
                            color: Colors.grey.withOpacity(0.1),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          if (message.imageUrl!.startsWith('data:image')) {
                            try {
                              return AppImage.memory(
                                message.imageUrl!,
                                fit: BoxFit.cover,
                                width: 180,
                                height: 180,
                              );
                            } catch (_) {}
                          }
                          return Container(
                            width: 180,
                            height: 180,
                            color: Colors.grey.withOpacity(0.1),
                            child: const Icon(Icons.gif_rounded,
                                size: 48, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ] else if (message.type == MessageType.sticker &&
                      message.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () {
                        _showStickerDetailDialog(context, message);
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.network(
                              message.imageUrl!,
                              fit: BoxFit.contain,
                              width: 165,
                              height: 165,
                              gaplessPlayback: true,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 165,
                                  height: 165,
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 165,
                                height: 165,
                                color: Colors.grey.withOpacity(0.1),
                                child: const Icon(Icons.sticky_note_2_rounded,
                                    size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('HH:mm').format(message.timestamp),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 3),
                                  _buildMessageStatusIcon(message, size: 13),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isLocation) ...[
                    LocationMessageBubble(
                      message: message,
                      isMe: isMe,
                      position: grouping,
                      statusWidget: isMe
                          ? _buildMessageStatusIcon(message, size: 13)
                          : null,
                    ),
                  ] else if (message.type == MessageType.liveLocation) ...[
                    LiveLocationBubble(
                      message: message,
                      chatId: widget.chatId,
                      currentUserId: _cachedMyUid ?? '',
                      liveLocationService: _liveLocationService,
                    ),
                  ] else if (message.type == MessageType.contact &&
                      message.contactName != null &&
                      message.contactPhone != null) ...[
                    Container(
                      width: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blueGrey.shade800.withOpacity(0.5)
                            : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isMe
                                    ? Colors.white.withOpacity(0.2)
                                    : AppColors.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.person_rounded,
                                  color:
                                      isMe ? Colors.white : AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.contactName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message.contactPhone!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey.shade600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMe
                                    ? Colors.white24
                                    : AppColors.primary.withOpacity(0.1),
                                foregroundColor:
                                    isMe ? Colors.white : AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Saved contact: ${message.contactName}'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_alt_rounded,
                                      size: 14,
                                      color: isMe
                                          ? Colors.white
                                          : AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(LocalizationService.of(context).get('save_contact'),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (message.type == MessageType.voice &&
                      message.fileUrl != null &&
                      message.duration != null) ...[
                    VoicePlayerWidget(
                      url: message.fileUrl!,
                      duration: message.duration!,
                      isMe: isMe,
                      messageId: message.id,
                    ),
                  ] else if (isVideo) ...[
                    VideoMessageBubble(
                      message: message,
                      isMe: isMe,
                      position: grouping,
                    ),
                  ] else if (message.type == MessageType.file &&
                      message.fileUrl != null) ...[
                    FileBubble(
                      message: message,
                      isMe: isMe,
                    ),
                  ] else if (message.type == MessageType.videoNote) ...[
                    VideoNoteBubble(
                      message: message,
                      isMe: isMe,
                    ),
                  ] else if (message.type == MessageType.poll &&
                      message.poll != null) ...[
                    PollBubble(
                      message: message,
                      chatId: widget.chatId,
                      currentUserId: _myUid ?? '',
                      isMe: isMe,
                      isChannelOwnerOrAdmin: ((_chatDoc?.data()
                              as Map<String, dynamic>?)?['createdBy'] ==
                          _myUid),
                    ),
                  ] else ...[
                    _buildMessageTextWidget(
                      message.text ?? '',
                      _searchQuery,
                      textColor,
                      isMe: isMe,
                    ),
                  ],
                  if (!isGif &&
                      !isSticker &&
                      !isVideo &&
                      !isPoll &&
                      !isLocation &&
                      !(isImage && !hasCaption)) ...[
                    const SizedBox(height: 3),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (message.expiresAt != null) ...[
                            SelfDestructTimerWidget(
                              chatId: widget.chatId,
                              messageId: message.id,
                              expiresAt: message.expiresAt!,
                              textColor: textColor,
                            ),
                            const SizedBox(width: 5),
                          ],
                          if (message.isEdited) ...[
                            Text(
                              '(${LocalizationService.translate('edited')})',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontStyle: FontStyle.italic,
                                color: timestampColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (message.authorName != null &&
                              message.authorName!.isNotEmpty) ...[
                            Text(
                              message.authorName!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: timestampColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          if (message.viewsCount > 0 ||
                              ((_chatDoc?.data()
                                      as Map<String, dynamic>?)?['isChannel'] ==
                                  true)) ...[
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 11.5,
                              color: secondaryIconColor,
                            ),
                            const SizedBox(width: 2.5),
                            Text(
                              '${message.viewsCount > 0 ? message.viewsCount : 1}',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: timestampColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (message.forwardCount > 0) ...[
                            Icon(
                              Icons.shortcut_rounded,
                              size: 11.5,
                              color: secondaryIconColor,
                            ),
                            const SizedBox(width: 2.5),
                            Text(
                              '${message.forwardCount}',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: timestampColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (message.isSilent) ...[
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 11.5,
                              color: secondaryIconColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style: AppTextStyles.timestamp().copyWith(
                              color: timestampColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 3.5),
                            _buildMessageStatusIcon(message, size: 14),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
            // Interactive reactions display below bubble
            if (reactionCounts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: reactionCounts.entries.map((e) {
                  final hasMyReaction = message.reactions[_myUid] == e.key;
                  return GestureDetector(
                    onTap: () {
                      if (_myUid == null) return;
                      context.read<MessageBloc>().add(
                            ToggleReactionRequested(
                              chatId: widget.chatId,
                              messageId: message.id,
                              userId: _myUid!,
                              emoji: e.key,
                            ),
                          );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasMyReaction
                            ? AppColors.primary.withOpacity(0.18)
                            : (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasMyReaction
                              ? AppColors.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: hasMyReaction ? 1.2 : 0.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            e.value.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: hasMyReaction
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: hasMyReaction
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white70
                                      : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (isChannel) ...[
              const SizedBox(height: 4),
              _buildChannelCommentsButton(message, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChannelCommentsButton(Message message, bool isDark) {
    final count = message.commentsCount;
    final hasComments = count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPostComments(message),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.9)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mode_comment_outlined,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                hasComments ? LocalizationService.formatCommentsCount(count) : LocalizationService.translate('leave_comment_action'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPostComments(Message message) {
    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    final gName = chatData?['groupName'] as String? ?? widget.otherUserName;
    final linkedGroupId = chatData?['linkedGroupId'] as String?;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostCommentsPage(
          chatId: widget.chatId,
          channelName: gName,
          post: message,
          currentUserId: _myUid ?? '',
          currentUserName: _myUserName,
          messageRepository: context.read<MessageRepository>(),
          chatRepository: _chatRepository,
          linkedGroupId: linkedGroupId,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSend = _textController.text.trim().isNotEmpty || _isRecording;

    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    final isChannel = chatData?['isChannel'] as bool? ?? false;
    final createdBy = chatData?['createdBy'] as String?;
    final isChannelAdmin = createdBy == _myUid;

    if (isChannel && !isChannelAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_off_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 8),
              Text(
                LocalizationService.translate('only_admins_send_messages'),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isGroup = chatData?['isGroup'] as bool? ?? false;
    if (isGroup && !_canSendText) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 8),
              Text(
                'Guruhda xabar yozish huquqingiz cheklangan',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editingMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom:
                    BorderSide(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.translate('editing_message'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.primary),
                      ),
                      Text(
                        _editingMessage!.text ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _editingMessage = null;
                      _textController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom:
                    BorderSide(color: isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingTo!.senderId == _myUid
                            ? 'You'
                            : widget.otherUserName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.primary),
                      ),
                      Text(
                        _replyingTo!.text ?? '📷 Photo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _replyingTo = null;
                    });
                  },
                ),
              ],
            ),
          ),
        Builder(
          builder: (context) {
            final chatData = _chatDoc?.data() as Map<String, dynamic>?;
            final isChannel = chatData?['isChannel'] as bool? ?? false;
            final isGroup = chatData?['isGroup'] as bool? ?? false;
            final createdBy = chatData?['createdBy'] as String?;
            final participants =
                List<String>.from(chatData?['participants'] ?? []);
            final isSubscribed =
                _cachedMyUid != null && participants.contains(_cachedMyUid);
            final isChannelAdmin = _cachedMyUid != null &&
                (createdBy == _cachedMyUid || _currentMember?.isAdmin == true);

            // Kanallar uchun: agar oddiy obunachi yoki mehmon bo'lsa
            if (isChannel && !isChannelAdmin) {
              if (!isSubscribed) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: Border(
                        top: BorderSide(
                            color: isDark ? Colors.white10 : Colors.black12)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final authState = context.read<AuthBloc>().state;
                          if (authState is AuthAuthenticated) {
                            await _chatRepository.joinChat(
                              widget.chatId,
                              authState.user.uid,
                              authState.user.displayName.isNotEmpty
                                  ? authState.user.displayName
                                  : LocalizationService.translate('user'),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(LocalizationService.of(context).get('channel_subscribed_success'))),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.campaign_rounded),
                        label: Text(LocalizationService.of(context).get('subscribe_channel_btn'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: Border(
                        top: BorderSide(
                            color: isDark ? Colors.white10 : Colors.black12)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.campaign_rounded,
                            size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          LocalizationService.translate('only_admins_post'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }

            // Guruhlar uchun: a'zolik ruxsati tekshiruvi
            if (isGroup &&
                _currentMember != null &&
                !_currentMember!.permissions.canSendMessages &&
                !_currentMember!.isAdmin) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(
                      top: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block_rounded,
                          size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        LocalizationService.translate('group_messaging_restricted'),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // 1. Single Action Menu (+) button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (!_checkSlowModeAndWarn()) return;
                          if (_isAttachmentMenuOpen) {
                            Navigator.of(context).pop();
                          } else {
                            _showAttachmentMenu();
                          }
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          child: Icon(
                            _isAttachmentMenuOpen
                                ? Icons.close_rounded
                                : Icons.add_rounded,
                            size: 24,
                            color: _selfDestructDuration != null
                                ? Colors.orange
                                : (_isSilentPost ? Colors.redAccent : AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Center Content: Recording container or Responsive Text Input Field
                    if (_isRecording)
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : AppColors.inputLight,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent,
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const RecordingWaveformWidget(),
                              const SizedBox(width: 10),
                              Text(
                                '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 22),
                                tooltip: LocalizationService.translate('cancel'),
                                onPressed: () => _stopRecording(send: false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: 5,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          scrollPhysics: const BouncingScrollPhysics(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                LocalizationService.translate('type_message'),
                            hintStyle: TextStyle(
                              color:
                                  isDark ? Colors.white38 : Colors.grey.shade500,
                              fontSize: 14.5,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.06),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: AppColors.primary.withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 3. Right side: Send button / Slow mode / Mic (responsive)
                    if (_slowModeRemainingSeconds > 0 && !_isExemptFromSlowMode) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _checkSlowModeAndWarn(),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFFD97706),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${_slowModeRemainingSeconds}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else if (!isChannel || showSend || _isRecording) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (_isRecording) {
                              _stopRecording(send: true);
                            } else if (showSend) {
                              _onSend();
                            } else {
                              if (!_checkSlowModeAndWarn()) return;
                              _startRecording();
                            }
                          },
                          onLongPress: (showSend && !_isRecording)
                              ? () => _showSendOptionsMenu()
                              : null,
                          borderRadius: BorderRadius.circular(22),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _isRecording
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFEF4444),
                                        Color(0xFFDC2626)
                                      ],
                                    )
                                  : (showSend
                                      ? const LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            Color(0xFF6366F1)
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: isDark
                                              ? [
                                                  const Color(0xFF334155),
                                                  const Color(0xFF1E293B)
                                                ]
                                              : [
                                                  const Color(0xFFE2E8F0),
                                                  const Color(0xFFCBD5E1)
                                                ],
                                        )),
                              border: Border.all(
                                color: _isRecording || showSend
                                    ? Colors.transparent
                                    : (isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.08)),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording
                                          ? Colors.redAccent
                                          : (showSend
                                              ? AppColors.primary
                                              : Colors.black))
                                      .withOpacity(_isRecording || showSend
                                          ? 0.35
                                          : (isDark ? 0.2 : 0.06)),
                                  blurRadius: _isRecording || showSend ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.send_rounded
                                  : (showSend
                                      ? Icons.send_rounded
                                      : Icons.mic_rounded),
                              color: _isRecording || showSend
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B)),
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _startRecording() async {
    if (!_canSendMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.of(context).get('restricted_send_voice')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Studio-quality HD voice recording configuration
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000, // 128 kbps crystal clear voice
            sampleRate: 44100, // 44.1 kHz Studio Sampling Rate
            numChannels: 1, // Mono voice channel
            autoGain: true, // Automatic volume leveling
            echoCancel: true, // Echo cancellation
            noiseSuppress: true, // Noise reduction
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDuration = 0;
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration =
                DateTime.now().difference(_recordingStartTime!).inSeconds;
          });
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  void _stopRecording({required bool send}) async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    if (!mounted) return;
    final duration = _recordingDuration;
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });

    if (send && path != null && duration > 0 && mounted) {
      if (!_checkSlowModeAndWarn()) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        String cleanPath = path;
        if (cleanPath.startsWith('file://')) {
          cleanPath = cleanPath.substring(7);
        }
        if (mounted) {
          context.read<MessageBloc>().add(SendVoiceMessageRequested(
                chatId: widget.chatId,
                senderId: authState.user.uid,
                voiceFile: File(cleanPath),
                durationSeconds: duration,
              ));
          _triggerSlowModeAfterSend();
        }
      }
    }
  }

  void _onPickFile() async {
    if (!_canSendMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.of(context).get('restricted_send_media')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_checkSlowModeAndWarn()) return;
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null && mounted) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        String cleanPath = result.files.single.path!;
        if (cleanPath.startsWith('file://')) {
          cleanPath = cleanPath.substring(7);
        }
        context.read<MessageBloc>().add(SendFileMessageRequested(
              chatId: widget.chatId,
              senderId: authState.user.uid,
              file: File(cleanPath),
            ));
        _triggerSlowModeAfterSend();
      }
    }
  }

  void _showAttachmentMenu() {
    if (_isAttachmentMenuOpen) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isAttachmentMenuOpen = true;
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatData = _chatDoc?.data() as Map<String, dynamic>?;
    final isChannel = chatData?['isChannel'] as bool? ?? false;
    final createdBy = chatData?['createdBy'] as String?;
    final isChannelAdmin = _cachedMyUid != null &&
        (createdBy == _cachedMyUid || _currentMember?.isAdmin == true);

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final bottomPadding =
                MediaQuery.of(modalContext).viewPadding.bottom;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grabber Handle
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Channel Silent Post toggle card (shown for channel admins)
                  if (isChannel && isChannelAdmin)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final newVal = !_isSilentPost;
                            setModalState(() {
                              _isSilentPost = newVal;
                            });
                            setState(() {
                              _isSilentPost = newVal;
                            });
                            _showFeedbackSnackBar(
                              newVal
                                  ? LocalizationService.translate('silent_post_on')
                                  : LocalizationService.translate('silent_post_off'),
                              icon: newVal
                                  ? Icons.notifications_off_rounded
                                  : Icons.notifications_active_rounded,
                              iconColor: newVal ? Colors.redAccent : Colors.greenAccent,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _isSilentPost
                                        ? Colors.redAccent.withOpacity(0.15)
                                        : AppColors.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isSilentPost
                                        ? Icons.notifications_off_rounded
                                        : Icons.notifications_active_rounded,
                                    color: _isSilentPost
                                        ? Colors.redAccent
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isSilentPost
                                            ? LocalizationService.translate('silent_post')
                                            : LocalizationService.translate('notifications'),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _isSilentPost
                                            ? LocalizationService.translate(
                                                'silent_post_desc')
                                            : LocalizationService.translate(
                                                'normal_post_desc'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _isSilentPost,
                                  activeColor: Colors.redAccent,
                                  onChanged: (val) {
                                    setModalState(() {
                                      _isSilentPost = val;
                                    });
                                    setState(() {
                                      _isSilentPost = val;
                                    });
                                    _showFeedbackSnackBar(
                                      val
                                          ? LocalizationService.translate(
                                              'silent_post_on')
                                          : LocalizationService.translate(
                                              'silent_post_off'),
                                      icon: val
                                          ? Icons.notifications_off_rounded
                                          : Icons.notifications_active_rounded,
                                      iconColor: val ? Colors.redAccent : Colors.greenAccent,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Action Menu Grid
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: 14,
                        right: 14,
                        top: 2,
                        bottom: bottomPadding + 14,
                      ),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.82,
                        children: [
                          if (_canSendMedia)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.photo_library_rounded,
                              label: LocalizationService.translate(
                                  'images_gallery'),
                              gradientColors: const [
                                Color(0xFF6366F1),
                                Color(0xFF4F46E5)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                _onPickImage();
                              },
                            ),
                          if (_canSendMedia)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.video_library_rounded,
                              label: LocalizationService.translate(
                                  'video'),
                              gradientColors: const [
                                Color(0xFFEF4444),
                                Color(0xFFDC2626)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                _onPickVideo(fromCamera: false);
                              },
                            ),
                          if (_canSendMedia)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.videocam_rounded,
                              label: LocalizationService.translate(
                                  'camera_video'),
                              gradientColors: const [
                                Color(0xFFF97316),
                                Color(0xFFEA580C)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                _onPickVideo(fromCamera: true);
                              },
                            ),
                          if (_canSendMedia)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.slow_motion_video_rounded,
                              label: LocalizationService.translate('video_note'),
                              gradientColors: const [
                                Color(0xFF06B6D4),
                                Color(0xFF0891B2)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                if (!_checkSlowModeAndWarn()) return;
                                _showVideoNoteRecorder();
                              },
                            ),
                          if (_canSendMedia)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.mic_rounded,
                              label: LocalizationService.translate(
                                  'voice_message'),
                              gradientColors: const [
                                Color(0xFF10B981),
                                Color(0xFF059669)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                if (!_checkSlowModeAndWarn()) return;
                                _startRecording();
                              },
                            ),
                          if (_canSendMedia)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.description_rounded,
                              label: LocalizationService.translate(
                                  'document_file'),
                              gradientColors: const [
                                Color(0xFF3B82F6),
                                Color(0xFF2563EB)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                _onPickFile();
                              },
                            ),
                          _buildActionGridItem(
                            context: modalContext,
                            icon: Icons.location_on_rounded,
                            label: LocalizationService.translate(
                                'send_current_location'),
                            gradientColors: const [
                              Color(0xFF14B8A6),
                              Color(0xFF0D9488)
                            ],
                            onTap: () {
                              Navigator.of(modalContext).pop();
                              _showLocationPickerDialog();
                            },
                          ),
                          _buildActionGridItem(
                            context: modalContext,
                            icon: Icons.share_location_rounded,
                            label: LocalizationService.translate(
                                'share_live_location'),
                            gradientColors: const [
                              Color(0xFF10B981),
                              Color(0xFF047857)
                            ],
                            onTap: () {
                              Navigator.of(modalContext).pop();
                              _showLiveLocationPicker();
                            },
                          ),
                          _buildActionGridItem(
                            context: modalContext,
                            icon: Icons.person_pin_rounded,
                            label:
                                LocalizationService.translate('share_contact'),
                            gradientColors: const [
                              Color(0xFFF59E0B),
                              Color(0xFFD97706)
                            ],
                            onTap: () {
                              Navigator.of(modalContext).pop();
                              _showContactPickerDialog();
                            },
                          ),
                          if (_canSendPolls)
                            _buildActionGridItem(
                              context: modalContext,
                              icon: Icons.poll_rounded,
                              label: LocalizationService.translate(
                                  'poll_and_quiz'),
                              gradientColors: const [
                                Color(0xFF8B5CF6),
                                Color(0xFF7C3AED)
                              ],
                              onTap: () {
                                Navigator.of(modalContext).pop();
                                _showCreatePollSheet();
                              },
                            ),
                          _buildActionGridItem(
                            context: modalContext,
                            icon: Icons.sticky_note_2_rounded,
                            label: LocalizationService.translate(
                                'stickers_and_gifs'),
                            gradientColors: const [
                              Color(0xFFEC4899),
                              Color(0xFFDB2777)
                            ],
                            onTap: () {
                              Navigator.of(modalContext).pop();
                              _showStickerGifDrawer();
                            },
                          ),
                          _buildActionGridItem(
                            context: modalContext,
                            icon: _selfDestructDuration != null
                                ? Icons.timer_rounded
                                : Icons.timer_outlined,
                            label: _selfDestructDuration != null
                                ? LocalizationService.translate(
                                        'self_destruct_active')
                                    .replaceAll(
                                        '{sec}', '$_selfDestructDuration')
                                : LocalizationService.translate(
                                    'self_destruct_timer'),
                            gradientColors: _selfDestructDuration != null
                                ? const [
                                    Color(0xFFF59E0B),
                                    Color(0xFFD97706)
                                  ]
                                : const [
                                    Color(0xFF64748B),
                                    Color(0xFF475569)
                                  ],
                            onTap: () {
                              Navigator.of(modalContext).pop();
                              _showSelfDestructMenu();
                            },
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
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isAttachmentMenuOpen = false;
        });
      }
    });
  }

  Widget _buildActionGridItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    String? semanticsLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first
                            .withOpacity(isDark ? 0.35 : 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showCreatePollSheet() {
    if (!_canSendPolls) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.of(context).get('restricted_create_polls')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_checkSlowModeAndWarn()) return;
    showKakkuFloatingBottomSheet(
      context: context,
      builder: (ctx) => CreatePollSheet(
        onPollCreated: (poll) {
          _sendPoll(poll);
        },
      ),
    );
  }

  void _sendPoll(PollData poll) {
    if (_myUid == null) return;
    context.read<MessageBloc>().add(
          SendPollRequested(
            chatId: widget.chatId,
            senderId: _myUid!,
            poll: poll,
            isSilent: false,
            topicId: _activeTopicId,
          ),
        );
    _triggerSlowModeAfterSend();
  }

  void _showVideoNoteRecorder() {
    if (!_canSendMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.of(context).get('restricted_send_media')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_checkSlowModeAndWarn()) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VideoNote',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return VideoNoteRecorder(
          onVideoRecorded: (videoPath, duration) {
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              context.read<MessageBloc>().add(
                    SendVideoNoteRequested(
                      chatId: widget.chatId,
                      senderId: authState.user.uid,
                      videoFile: File(videoPath),
                      durationSeconds: duration,
                    ),
                  );
              _triggerSlowModeAfterSend();
            }
          },
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _showLocationPickerDialog() {
    if (!_checkSlowModeAndWarn()) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) {
          return InteractiveMapPickerDialog(
            onLocationSelected: (lat, lng, address) {
              final authState = this.context.read<AuthBloc>().state;
              if (authState is AuthAuthenticated) {
                this.context.read<MessageBloc>().add(SendTextMessage(
                      chatId: widget.chatId,
                      senderId: authState.user.uid,
                      text: '📍 Location: $address',
                      type: MessageType.location,
                      latitude: lat,
                      longitude: lng,
                      address: address,
                    ));
                _triggerSlowModeAfterSend();
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _showLiveLocationPicker() async {
    if (!_checkSlowModeAndWarn()) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final durationSeconds = await LiveLocationDurationSheet.show(context);
    if (durationSeconds == null) return;

    try {
      final senderDisplayName = authState.user.displayName.isNotEmpty
          ? authState.user.displayName
          : (authState.user.email.isNotEmpty
              ? authState.user.email.split('@').first
              : 'Foydalanuvchi');

      final session = await _liveLocationService.startLiveLocation(
        chatId: widget.chatId,
        senderId: authState.user.uid,
        senderName: senderDisplayName,
        durationSeconds: durationSeconds,
      );

      if (!mounted) return;

      context.read<MessageBloc>().add(SendTextMessage(
            chatId: widget.chatId,
            senderId: authState.user.uid,
            text: '📍 ${LocalizationService.translate('live_location')}',
            type: MessageType.liveLocation,
            latitude: session.latitude,
            longitude: session.longitude,
            liveLocationSessionId: session.sessionId,
            liveLocationDuration: durationSeconds,
          ));
      _triggerSlowModeAfterSend();

      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => LiveLocationViewerPage(
            chatId: widget.chatId,
            sessionId: session.sessionId,
            currentUserId: authState.user.uid,
            initialLatitude: session.latitude,
            initialLongitude: session.longitude,
            liveLocationService: _liveLocationService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showContactPickerDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Text(LocalizationService.of(context).get('share_contact_title'),
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: LocalizationService.of(context).get('contact_name_label')),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: LocalizationService.of(context).get('phone_number_label')),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LocalizationService.of(context).get('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) return;

                final authState = this.context.read<AuthBloc>().state;
                if (authState is AuthAuthenticated) {
                  this.context.read<MessageBloc>().add(SendTextMessage(
                        chatId: widget.chatId,
                        senderId: authState.user.uid,
                        text: '👤 Contact: $name',
                        type: MessageType.contact,
                        contactName: name,
                        contactPhone: phone,
                      ));
                }
                Navigator.of(context).pop();
              },
              child: Text(LocalizationService.of(context).get('share')),
            ),
          ],
        );
      },
    );
  }

  void _showStickerGifDrawer() {
    StickerPickerSheet.show(
      context,
      onStickerSelected: (sticker) {
        if (!_checkSlowModeAndWarn()) return;
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          context.read<MessageBloc>().add(SendTextMessage(
                chatId: widget.chatId,
                senderId: authState.user.uid,
                text: sticker.title,
                type: MessageType.sticker,
                imageUrl: sticker.imageUrl,
                replyToMessageId: _replyingTo?.id,
                selfDestructDuration: _selfDestructDuration,
              ));
          _triggerSlowModeAfterSend();
          setState(() {
            _replyingTo = null;
          });
        }
      },
      onGifSelected: (url) {
        if (!_checkSlowModeAndWarn()) return;
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          context.read<MessageBloc>().add(SendTextMessage(
                chatId: widget.chatId,
                senderId: authState.user.uid,
                text: 'GIF',
                type: MessageType.gif,
                imageUrl: url,
                replyToMessageId: _replyingTo?.id,
                selfDestructDuration: _selfDestructDuration,
              ));
          _triggerSlowModeAfterSend();
          setState(() {
            _replyingTo = null;
          });
        }
      },
    );
  }

  void _showStickerDetailDialog(BuildContext context, Message message) {
    if (message.imageUrl == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (c, o, s) => const Icon(
                      Icons.sticky_note_2_rounded,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                ),
                if (message.text != null && message.text!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    message.text!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SelfDestructTimerWidget extends StatefulWidget {
  final String chatId;
  final String messageId;
  final DateTime expiresAt;
  final Color textColor;

  const SelfDestructTimerWidget({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.expiresAt,
    required this.textColor,
  });

  @override
  State<SelfDestructTimerWidget> createState() =>
      _SelfDestructTimerWidgetState();
}

class _SelfDestructTimerWidgetState extends State<SelfDestructTimerWidget> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.expiresAt.difference(DateTime.now()).inSeconds;
    if (_secondsLeft <= 0) {
      _triggerDelete();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _secondsLeft =
                widget.expiresAt.difference(DateTime.now()).inSeconds;
          });
          if (_secondsLeft <= 0) {
            _timer?.cancel();
            _triggerDelete();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerDelete() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessageBloc>().add(DeleteMessageRequested(
            widget.chatId,
            widget.messageId,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) return const SizedBox();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt_rounded, color: Colors.orange, size: 12),
        const SizedBox(width: 2),
        Text(
          '${_secondsLeft}s',
          style: TextStyle(
            color: widget.textColor.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class RecordingWaveformWidget extends StatefulWidget {
  const RecordingWaveformWidget({super.key});

  @override
  State<RecordingWaveformWidget> createState() =>
      _RecordingWaveformWidgetState();
}

class _RecordingWaveformWidgetState extends State<RecordingWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(12, (index) {
            final double phase = (index * 0.12 + _controller.value) % 1.0;
            final double height = 4.0 + (18.0 * (phase - 0.5).abs());
            return Container(
              width: 2.8,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

class GiphyService {
  static const String _apiKey = 'dc6zaTOxFJmzC';

  static Future<List<String>> searchGifs(String query) async {
    try {
      final client = HttpClient();
      final url = query.isEmpty
          ? 'https://api.giphy.com/v1/gifs/trending?api_key=$_apiKey&limit=24'
          : 'https://api.giphy.com/v1/gifs/search?api_key=$_apiKey&q=${Uri.encodeComponent(query)}&limit=24';

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        return data.map((item) {
          final images = item['images'] as Map<String, dynamic>;
          final fixedWidth = images['fixed_width'] as Map<String, dynamic>;
          return fixedWidth['url'] as String;
        }).toList();
      }
    } catch (e) {
      print('Giphy fetch error: $e');
    }
    return [
      'https://media.giphy.com/media/l3q2zVr6cu95nF6O4/giphy.gif',
      'https://media.giphy.com/media/l2JhORT5IFnj6ioko/giphy.gif',
      'https://media.giphy.com/media/3o7qE1YN7aBOFPRw8E/giphy.gif',
      'https://media.giphy.com/media/26AHONQ79uqx894eQ/giphy.gif',
      'https://media.giphy.com/media/xT39CXg70n42o5tSMU/giphy.gif',
      'https://media.giphy.com/media/l0ExdPMcAd99Z5t84/giphy.gif',
    ];
  }
}

class GifTabWidget extends StatefulWidget {
  final String chatId;
  final Function(String) onGifSelected;

  const GifTabWidget({
    super.key,
    required this.chatId,
    required this.onGifSelected,
  });

  @override
  State<GifTabWidget> createState() => _GifTabWidgetState();
}

class _GifTabWidgetState extends State<GifTabWidget> {
  final _searchController = TextEditingController();
  List<String> _gifs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGifs('');
  }

  void _loadGifs(String query) async {
    setState(() => _isLoading = true);
    final results = await GiphyService.searchGifs(query);
    if (mounted) {
      setState(() {
        _gifs = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: LocalizationService.of(context).get('search_giphy_hint'),
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (val) {
              _loadGifs(val.trim());
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _gifs.length,
                  itemBuilder: (context, index) {
                    final url = _gifs[index];
                    return GestureDetector(
                      onTap: () => widget.onGifSelected(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.gif_rounded,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class StickerTabWidget extends StatelessWidget {
  final Function(String) onStickerSelected;

  StickerTabWidget({
    super.key,
    required this.onStickerSelected,
  });

  final List<String> _stickers = [
    'https://media.giphy.com/media/l3q2zVr6cu95nF6O4/giphy.gif',
    'https://media.giphy.com/media/l2JhORT5IFnj6ioko/giphy.gif',
    'https://media.giphy.com/media/3o7qE1YN7aBOFPRw8E/giphy.gif',
    'https://media.giphy.com/media/26AHONQ79uqx894eQ/giphy.gif',
    'https://media.giphy.com/media/xT39CXg70n42o5tSMU/giphy.gif',
    'https://media.giphy.com/media/l0ExdPMcAd99Z5t84/giphy.gif',
    'https://media.giphy.com/media/3o7qE4opvo4SSIQXt6/giphy.gif',
    'https://media.giphy.com/media/l0Ex8ovvEz1t5yBu0/giphy.gif',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _stickers.length,
      itemBuilder: (context, index) {
        final url = _stickers[index];
        return GestureDetector(
          onTap: () => onStickerSelected(url),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (c, o, s) => const Icon(
                  Icons.sentiment_satisfied_rounded,
                  size: 48,
                  color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
