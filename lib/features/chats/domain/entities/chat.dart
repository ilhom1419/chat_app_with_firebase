import 'package:equatable/equatable.dart';
import 'chat_member.dart';

class Chat extends Equatable {
  final String id;
  final List<String> participantIds;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final bool otherUserIsOnline;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? pinnedMessageId;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final bool isChannel;
  final String? createdBy;

  // Yangi Telegram darajasidagi xususiyatlar (New Telegram-grade properties)
  final String? description;
  final String? username; // Masalan: @flutter_uz
  final String type; // 'public', 'private', 'direct'
  final int memberCount;
  final int slowModeSeconds;
  final bool topicsEnabled; // Forum guruh rejimi
  final bool signMessages; // Kanal postlarida muallif imzosini ko'rsatish
  final bool restrictContent; // Xabarlardan nusxa olish va boshqa chatlarga ulashishni taqiqlash (Protect content)
  final String? linkedGroupId; // Bog'langan munozara guruhi ID-si (Linked Discussion Group)
  final String? linkedGroupName; // Bog'langan munozara guruhi nomi
  final String? inviteLink;
  final String? inviteCode;
  final MemberPermissions defaultPermissions;
  final MemberRole? currentUserRole;

  const Chat({
    required this.id,
    required this.participantIds,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.otherUserIsOnline,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.pinnedMessageId,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    this.isChannel = false,
    this.createdBy,
    this.description,
    this.username,
    this.type = 'direct',
    this.memberCount = 0,
    this.slowModeSeconds = 0,
    this.topicsEnabled = false,
    this.signMessages = false,
    this.restrictContent = false,
    this.linkedGroupId,
    this.linkedGroupName,
    this.inviteLink,
    this.inviteCode,
    this.defaultPermissions = const MemberPermissions(),
    this.currentUserRole,
  });

  bool get isPublic => type == 'public';
  bool get isPrivate => type == 'private';
  bool get hasDiscussion => linkedGroupId != null && linkedGroupId!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        participantIds,
        otherUserId,
        otherUserName,
        otherUserPhoto,
        otherUserIsOnline,
        lastMessage,
        lastMessageTime,
        unreadCount,
        pinnedMessageId,
        isGroup,
        groupName,
        groupAvatar,
        isChannel,
        createdBy,
        description,
        username,
        type,
        memberCount,
        slowModeSeconds,
        topicsEnabled,
        signMessages,
        restrictContent,
        linkedGroupId,
        linkedGroupName,
        inviteLink,
        inviteCode,
        defaultPermissions,
        currentUserRole,
      ];
}
