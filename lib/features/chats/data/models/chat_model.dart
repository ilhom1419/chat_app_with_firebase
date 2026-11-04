import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_member.dart';

class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.participantIds,
    required super.otherUserId,
    required super.otherUserName,
    super.otherUserPhoto,
    required super.otherUserIsOnline,
    required super.lastMessage,
    required super.lastMessageTime,
    required super.unreadCount,
    super.pinnedMessageId,
    super.isGroup,
    super.groupName,
    super.groupAvatar,
    super.isChannel,
    super.createdBy,
    super.description,
    super.username,
    super.type,
    super.memberCount,
    super.slowModeSeconds,
    super.topicsEnabled,
    super.signMessages,
    super.restrictContent,
    super.linkedGroupId,
    super.linkedGroupName,
    super.inviteLink,
    super.inviteCode,
    super.defaultPermissions,
    super.currentUserRole,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final participants = List<String>.from(data['participants'] ?? []);
    final isGroup = data['isGroup'] as bool? ?? false;
    final isChannel = data['isChannel'] as bool? ?? false;
    final createdByVal = data['createdBy'] as String?;

    // Suhbatdosh userning ID-si (Guruh/Kanal bo'lsa bo'sh bo'ladi)
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    // Boshqa foydalanuvchi ma'lumotlari universal map-lardan olinadi
    final names = data['userNames'] as Map<String, dynamic>? ?? {};
    final photos = data['userPhotos'] as Map<String, dynamic>? ?? {};
    final onlineStates =
        data['userOnlineStates'] as Map<String, dynamic>? ?? {};

    int resolvedUnread = 0;
    final unreadRaw = data['unreadCount'];
    if (unreadRaw is Map) {
      // Authoritative per-user unread map: { uid: count }
      // If currentUserId key is present, its value is authoritative (even if 0)
      if (currentUserId.isNotEmpty && unreadRaw.containsKey(currentUserId)) {
        resolvedUnread = (unreadRaw[currentUserId] as num?)?.toInt() ?? 0;
      } else {
        resolvedUnread = (unreadRaw[currentUserId] as num?)?.toInt() ?? 0;
      }
    } else if (unreadRaw is num) {
      resolvedUnread = unreadRaw.toInt();
    } else if (unreadRaw == null && currentUserId.isNotEmpty) {
      // Legacy backwards-compatibility fallback ONLY when unreadCount map is completely absent
      final dottedVal = data['unreadCount.$currentUserId'];
      if (dottedVal is num) {
        resolvedUnread = dottedVal.toInt();
      } else if (data['unread'] is Map) {
        resolvedUnread =
            ((data['unread'] as Map)[currentUserId] as num?)?.toInt() ?? 0;
      } else if (data['unreadCounts'] is Map) {
        resolvedUnread =
            ((data['unreadCounts'] as Map)[currentUserId] as num?)?.toInt() ??
                0;
      } else if (data['unread_$currentUserId'] is num) {
        resolvedUnread = (data['unread_$currentUserId'] as num).toInt();
      }
    }
    final groupNameVal = data['groupName'] as String?;
    final groupAvatarVal = data['groupAvatar'] as String?;

    MemberRole? calculatedRole;
    if (currentUserId.isNotEmpty && createdByVal == currentUserId) {
      calculatedRole = MemberRole.owner;
    }

    final typeVal = data['type'] as String? ??
        ((isGroup || isChannel) ? 'public' : 'direct');
    final memberCountVal =
        (data['memberCount'] as num?)?.toInt() ?? participants.length;

    return ChatModel(
      id: doc.id,
      participantIds: participants,
      otherUserId: (isGroup || isChannel) ? '' : otherId,
      otherUserName: (isGroup || isChannel)
          ? (groupNameVal ?? (isChannel ? 'Channel' : 'Group'))
          : (names[otherId] as String? ?? 'User'),
      otherUserPhoto:
          (isGroup || isChannel) ? groupAvatarVal : photos[otherId] as String?,
      otherUserIsOnline: (isGroup || isChannel)
          ? false
          : (onlineStates[otherId] as bool? ?? false),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
      unreadCount: resolvedUnread,
      pinnedMessageId: data['pinnedMessageId'] as String?,
      isGroup: isGroup,
      groupName: groupNameVal,
      groupAvatar: groupAvatarVal,
      isChannel: isChannel,
      createdBy: createdByVal,
      description: data['description'] as String?,
      username: data['username'] as String?,
      type: typeVal,
      memberCount: memberCountVal,
      slowModeSeconds: (data['slowModeSeconds'] as num?)?.toInt() ?? 0,
      topicsEnabled: data['topicsEnabled'] as bool? ?? false,
      signMessages: data['signMessages'] as bool? ?? false,
      restrictContent: data['restrictContent'] as bool? ?? false,
      linkedGroupId: data['linkedGroupId'] as String?,
      linkedGroupName: data['linkedGroupName'] as String?,
      inviteLink: data['inviteLink'] as String?,
      inviteCode: data['inviteCode'] as String?,
      defaultPermissions: MemberPermissions.fromMap(
          data['defaultPermissions'] as Map<String, dynamic>?),
      currentUserRole: calculatedRole,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'pinnedMessageId': pinnedMessageId,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'isChannel': isChannel,
      'createdBy': createdBy,
      'description': description,
      'username': username,
      'type': type,
      'memberCount': memberCount,
      'slowModeSeconds': slowModeSeconds,
      'topicsEnabled': topicsEnabled,
      'signMessages': signMessages,
      'restrictContent': restrictContent,
      'linkedGroupId': linkedGroupId,
      'linkedGroupName': linkedGroupName,
      'inviteLink': inviteLink,
      'inviteCode': inviteCode,
      'defaultPermissions': defaultPermissions.toMap(),
    };
  }
}
