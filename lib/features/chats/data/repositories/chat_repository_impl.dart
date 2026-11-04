import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_member.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_model.dart';
import '../models/chat_member_model.dart';
import '../../domain/entities/topic.dart';
import '../models/topic_model.dart';
import '../../domain/entities/channel_stats.dart';
import '../../domain/entities/chat_folder.dart';
import '../models/chat_folder_model.dart';
import '../../../messages/data/models/message_model.dart';
import '../../presentation/widgets/join_preview_sheet.dart';

class ChatRepositoryImpl implements ChatRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Stream<List<Chat>> getChats(String currentUserId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ChatModel.fromFirestore(doc, currentUserId))
          .toList();
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list.cast<Chat>();
    });
  }

  @override
  Future<String> createOrGetChat(
      String currentUserId, String otherUserId) async {
    if (currentUserId.trim().isEmpty || otherUserId.trim().isEmpty) {
      throw ArgumentError('currentUserId and otherUserId must not be empty');
    }

    // chatId ni uid1_uid2 formatida tartiblab generatsiya qilamiz
    final ids = [currentUserId, otherUserId]..sort();
    final chatId = ids.join('_');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      // Foydalanuvchilar ma'lumotlarini olamiz
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final otherUserDoc =
          await _firestore.collection('users').doc(otherUserId).get();

      final currentData = currentUserDoc.data() ?? {};
      final otherData = otherUserDoc.data() ?? {};

      await _firestore.collection('chats').doc(chatId).set({
        'id': chatId,
        'participants': ids,
        'createdBy': currentUserId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'type': 'direct',
        'isGroup': false,
        'isChannel': false,

        // Universal dynamic map-lar
        'userNames': {
          currentUserId: currentData['displayName'] ?? 'User',
          otherUserId: otherData['displayName'] ?? 'User',
        },
        'userPhotos': {
          currentUserId: currentData['photoURL'],
          otherUserId: otherData['photoURL'],
        },
        'userOnlineStates': {
          currentUserId: currentData['isOnline'] ?? false,
          otherUserId: otherData['isOnline'] ?? false,
        }
      }, SetOptions(merge: true));
    } else {
      // Mavjud chatni ham yangi universal tuzilmaga o'tkazish uchun yangilaymiz (backward compatibility)
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final otherUserDoc =
          await _firestore.collection('users').doc(otherUserId).get();

      final currentData = currentUserDoc.data() ?? {};
      final otherData = otherUserDoc.data() ?? {};

      await _firestore.collection('chats').doc(chatId).set({
        'participants': ids,
        'type': 'direct',
        'isGroup': false,
        'isChannel': false,
        'userNames': {
          currentUserId: currentData['displayName'] ?? 'User',
          otherUserId: otherData['displayName'] ?? 'User',
        },
        'userPhotos': {
          currentUserId: currentData['photoURL'],
          otherUserId: otherData['photoURL'],
        },
        'userOnlineStates': {
          currentUserId: currentData['isOnline'] ?? false,
          otherUserId: otherData['isOnline'] ?? false,
        }
      }, SetOptions(merge: true));
    }

    return chatId;
  }

  @override
  Future<List<AppUser>> searchUsers(String query, String currentUserId) async {
    if (query.isEmpty) return [];

    // Username bo'yicha qidirish (@ bilan boshlansa)
    if (query.startsWith('@')) {
      final clean = query.replaceFirst('@', '').trim().toLowerCase();
      if (clean.isNotEmpty) {
        final usernameResult = await _firestore
            .collection('users')
            .where('username', isEqualTo: clean)
            .get();
        if (usernameResult.docs.isNotEmpty) {
          return usernameResult.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .where((user) => user.uid != currentUserId)
              .toList();
        }
      }
    }

    // Email bo'yicha qidirish
    if (query.contains('@')) {
      final emailResult = await _firestore
          .collection('users')
          .where('email', isEqualTo: query.trim())
          .get();
      return emailResult.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.uid != currentUserId)
          .toList();
    }

    // Ism bo'yicha qidirish (Capitalized formatni ham tekshiramiz)
    final trimmedQuery = query.trim();
    final capitalizedQuery = trimmedQuery.isEmpty
        ? trimmedQuery
        : trimmedQuery[0].toUpperCase() + trimmedQuery.substring(1);

    final result = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: capitalizedQuery)
        .where('displayName', isLessThanOrEqualTo: '$capitalizedQuery\uf8ff')
        .get();

    return result.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) => user.uid != currentUserId)
        .toList();
  }

  @override
  Future<void> markAsRead(String chatId, String userId) async {
    if (chatId.isEmpty || userId.isEmpty) return;
    try {
      final docRef = _firestore.collection('chats').doc(chatId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final data = docSnap.data() ?? {};
      final rawUnread = data['unreadCount'];

      final Map<String, dynamic> updates = {};

      if (rawUnread is Map) {
        updates['unreadCount.$userId'] = 0;
      } else {
        // If unreadCount was stored as an integer, missing, or corrupt, normalize to Map
        updates['unreadCount'] = {userId: 0};
      }

      // Clean up legacy keys if they exist on the document
      if (data.containsKey('unreadCount.$userId')) {
        updates['unreadCount.$userId'] = 0;
      }
      if (data['unreadCounts'] is Map) {
        updates['unreadCounts.$userId'] = 0;
      }
      if (data['unread'] is Map) {
        updates['unread.$userId'] = 0;
      }
      if (data.containsKey('unread_$userId')) {
        updates['unread_$userId'] = 0;
      }

      await docRef.update(updates);
    } catch (e) {
      try {
        await _firestore.collection('chats').doc(chatId).update({
          'unreadCount.$userId': 0,
        });
      } catch (inner) {
        print("Error marking chat as read: $inner");
      }
    }
  }

  @override
  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typingStates.$userId': isTyping,
        'typingLastActive.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating typing status: $e");
    }
  }

  @override
  Future<String> createChannel({
    required String currentUserId,
    required String currentUserName,
    required String name,
    String? description,
    String? avatar,
    bool isPublic = true,
    List<String> initialMemberIds = const [],
  }) async {
    final chatId = 'channel_${DateTime.now().millisecondsSinceEpoch}';
    final participants = [currentUserId, ...initialMemberIds];
    final inviteCode = InviteLinkService.generateInviteCode(isChannel: true);
    final inviteLink = InviteLinkService.formatInviteLink(inviteCode);

    final userNames = <String, String>{currentUserId: currentUserName};
    final userPhotos = <String, dynamic>{};
    final userOnlineStates = <String, bool>{};

    // Creator ma'lumotlari
    final creatorDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    String? creatorPhoto;
    if (creatorDoc.exists) {
      final cData = creatorDoc.data();
      creatorPhoto = cData?['photoURL'] as String?;
      userPhotos[currentUserId] = creatorPhoto;
      userOnlineStates[currentUserId] = cData?['isOnline'] as bool? ?? false;
    }

    // Tanlangan a'zolar ma'lumotlari
    for (final id in initialMemberIds) {
      final uDoc = await _firestore.collection('users').doc(id).get();
      if (uDoc.exists) {
        final uData = uDoc.data();
        userNames[id] = uData?['displayName'] as String? ?? 'User';
        userPhotos[id] = uData?['photoURL'];
        userOnlineStates[id] = uData?['isOnline'] as bool? ?? false;
      }
    }

    final unreadMap = <String, int>{};
    for (final id in participants) {
      unreadMap[id] = 0;
    }

    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);

    batch.set(chatRef, {
      'id': chatId,
      'participants': participants,
      'isGroup': false,
      'isChannel': true,
      'createdBy': currentUserId,
      'type': isPublic ? 'public' : 'private',
      'groupName': name,
      'groupAvatar': avatar,
      'description': description,
      'memberCount': participants.length,
      'inviteCode': inviteCode,
      'inviteLink': inviteLink,
      'slowModeSeconds': 0,
      'topicsEnabled': false,
      'signMessages': false,
      'lastMessage': 'Channel created by $currentUserName',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'userNames': userNames,
      'userPhotos': userPhotos,
      'userOnlineStates': userOnlineStates,
      'unreadCount': unreadMap,
    });

    // Creator as Owner in members subcollection
    final ownerMemberRef = chatRef.collection('members').doc(currentUserId);
    batch.set(
      ownerMemberRef,
      ChatMemberModel(
        userId: currentUserId,
        displayName: currentUserName,
        photoURL: creatorPhoto,
        role: MemberRole.owner,
        customTitle: '👑 Kanal Asoschisi',
        permissions: const MemberPermissions.admin(),
        joinedAt: DateTime.now(),
        isOnline: true,
      ).toFirestore(),
    );

    // Initial members as regular members in members subcollection
    for (final id in initialMemberIds) {
      final memberRef = chatRef.collection('members').doc(id);
      batch.set(
        memberRef,
        ChatMemberModel(
          userId: id,
          displayName: userNames[id] ?? 'User',
          photoURL: userPhotos[id] as String?,
          role: MemberRole.member,
          permissions: const MemberPermissions(),
          joinedAt: DateTime.now(),
          invitedBy: currentUserId,
        ).toFirestore(),
      );
    }

    // Initial system message
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final msgRef = chatRef.collection('messages').doc(msgId);
    batch.set(msgRef, {
      'id': msgId,
      'senderId': 'system',
      'text': 'Kanal "$name" ochildi.',
      'type': 'text',
      'isRead': false,
      'isDeleted': false,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    await batch.commit();
    return chatId;
  }

  @override
  Future<String> createGroup({
    required String currentUserId,
    required String currentUserName,
    required String name,
    String? description,
    String? avatar,
    bool isPublic = true,
    required List<String> initialMemberIds,
  }) async {
    final chatId = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final participants = [currentUserId, ...initialMemberIds];
    final inviteCode = InviteLinkService.generateInviteCode(isChannel: false);
    final inviteLink = InviteLinkService.formatInviteLink(inviteCode);

    final userNames = <String, String>{currentUserId: currentUserName};
    final userPhotos = <String, dynamic>{};
    final userOnlineStates = <String, bool>{};

    // Creator ma'lumotlari
    final creatorDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    String? creatorPhoto;
    if (creatorDoc.exists) {
      final cData = creatorDoc.data();
      creatorPhoto = cData?['photoURL'] as String?;
      userPhotos[currentUserId] = creatorPhoto;
      userOnlineStates[currentUserId] = cData?['isOnline'] as bool? ?? false;
    }

    // A'zolar ma'lumotlari
    for (final id in initialMemberIds) {
      final uDoc = await _firestore.collection('users').doc(id).get();
      if (uDoc.exists) {
        final uData = uDoc.data();
        userNames[id] = uData?['displayName'] as String? ?? 'User';
        userPhotos[id] = uData?['photoURL'];
        userOnlineStates[id] = uData?['isOnline'] as bool? ?? false;
      }
    }

    final unreadMap = <String, int>{};
    for (final id in participants) {
      unreadMap[id] = 0;
    }

    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);

    batch.set(chatRef, {
      'id': chatId,
      'participants': participants,
      'isGroup': true,
      'isChannel': false,
      'createdBy': currentUserId,
      'type': isPublic ? 'public' : 'private',
      'groupName': name,
      'groupAvatar': avatar,
      'description': description,
      'memberCount': participants.length,
      'inviteCode': inviteCode,
      'inviteLink': inviteLink,
      'slowModeSeconds': 0,
      'topicsEnabled': false,
      'signMessages': false,
      'lastMessage': 'Group created by $currentUserName',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'userNames': userNames,
      'userPhotos': userPhotos,
      'userOnlineStates': userOnlineStates,
      'unreadCount': unreadMap,
    });

    // Creator as Owner
    final ownerMemberRef = chatRef.collection('members').doc(currentUserId);
    batch.set(
      ownerMemberRef,
      ChatMemberModel(
        userId: currentUserId,
        displayName: currentUserName,
        photoURL: creatorPhoto,
        role: MemberRole.owner,
        customTitle: '👑 Guruh Asoschisi',
        permissions: const MemberPermissions.admin(),
        joinedAt: DateTime.now(),
        isOnline: true,
      ).toFirestore(),
    );

    // Initial members as regular members
    for (final id in initialMemberIds) {
      final memberRef = chatRef.collection('members').doc(id);
      batch.set(
        memberRef,
        ChatMemberModel(
          userId: id,
          displayName: userNames[id] ?? 'User',
          photoURL: userPhotos[id] as String?,
          role: MemberRole.member,
          permissions: const MemberPermissions(),
          joinedAt: DateTime.now(),
          invitedBy: currentUserId,
        ).toFirestore(),
      );
    }

    // Initial system message
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final msgRef = chatRef.collection('messages').doc(msgId);
    batch.set(msgRef, {
      'id': msgId,
      'senderId': 'system',
      'text': 'Guruh "$name" ochildi.',
      'type': 'text',
      'isRead': false,
      'isDeleted': false,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    await batch.commit();
    return chatId;
  }

  @override
  Stream<List<ChatMember>> getChatMembers(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMemberModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<ChatMember?> getChatMember(String chatId, String userId) async {
    final doc = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .doc(userId)
        .get();
    if (doc.exists) {
      return ChatMemberModel.fromFirestore(doc);
    }

    // Agar subcollection'da hali bo'lmasa, chat participants tekshiriladi (backward compatibility)
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final data = chatDoc.data() ?? {};
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(userId)) {
        final isOwner = (data['createdBy'] as String?) == userId;
        final names = data['userNames'] as Map<String, dynamic>? ?? {};
        final photos = data['userPhotos'] as Map<String, dynamic>? ?? {};
        return ChatMember(
          userId: userId,
          displayName: names[userId] as String? ?? 'User',
          photoURL: photos[userId] as String?,
          role: isOwner ? MemberRole.owner : MemberRole.member,
          customTitle: isOwner ? 'Asoschi' : null,
          permissions: isOwner
              ? const MemberPermissions.admin()
              : const MemberPermissions(),
          joinedAt: DateTime.now(),
        );
      }
    }
    return null;
  }

  @override
  Stream<ChatMember?> streamChatMember(String chatId, String userId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return ChatMemberModel.fromFirestore(doc);
      }
      return null;
    });
  }

  @override
  Future<void> updateMemberRole(
    String chatId,
    String targetUserId,
    MemberRole role, {
    String? customTitle,
    MemberPermissions? permissions,
  }) async {
    final effectivePermissions = permissions ??
        (role.isAdmin
            ? const MemberPermissions.admin()
            : (role.isRestricted
                ? const MemberPermissions.restricted()
                : const MemberPermissions()));

    final updates = <String, dynamic>{
      'role': role.name,
      'permissions': effectivePermissions.toMap(),
    };
    if (customTitle != null) {
      updates['customTitle'] = customTitle;
    }

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .doc(targetUserId)
        .set(updates, SetOptions(merge: true));
  }

  @override
  Future<void> updateMemberPermissions(
    String chatId,
    String targetUserId,
    MemberPermissions permissions,
  ) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .doc(targetUserId)
        .set({'permissions': permissions.toMap()}, SetOptions(merge: true));
  }

  @override
  Future<void> removeMember(String chatId, String targetUserId) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final memberRef = chatRef.collection('members').doc(targetUserId);

    batch.delete(memberRef);
    batch.update(chatRef, {
      'participants': FieldValue.arrayRemove([targetUserId]),
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  @override
  Future<void> banMember(String chatId, String targetUserId) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final memberRef = chatRef.collection('members').doc(targetUserId);

    batch.set(
      memberRef,
      {
        'role': MemberRole.banned.name,
        'permissions': const MemberPermissions.restricted().toMap(),
      },
      SetOptions(merge: true),
    );

    batch.update(chatRef, {
      'participants': FieldValue.arrayRemove([targetUserId]),
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  @override
  Future<void> unbanMember(String chatId, String targetUserId) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final memberRef = chatRef.collection('members').doc(targetUserId);

    batch.set(
      memberRef,
      {
        'role': MemberRole.member.name,
        'permissions': const MemberPermissions().toMap(),
      },
      SetOptions(merge: true),
    );

    batch.update(chatRef, {
      'participants': FieldValue.arrayUnion([targetUserId]),
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  @override
  Future<void> transferOwnership(String chatId, String newOwnerId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;

    final oldOwnerId = chatDoc.data()?['createdBy'] as String? ?? '';
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);

    // Yangi egasi
    batch.update(chatRef, {'createdBy': newOwnerId});

    // Yangi egasining a'zolik holati
    final newOwnerRef = chatRef.collection('members').doc(newOwnerId);
    batch.set(
      newOwnerRef,
      {
        'role': MemberRole.owner.name,
        'customTitle': '👑 Asoschi',
        'permissions': const MemberPermissions.admin().toMap(),
      },
      SetOptions(merge: true),
    );

    // Oldingi egasi administrator bo'lib qoladi
    if (oldOwnerId.isNotEmpty && oldOwnerId != newOwnerId) {
      final oldOwnerRef = chatRef.collection('members').doc(oldOwnerId);
      batch.set(
        oldOwnerRef,
        {
          'role': MemberRole.admin.name,
          'customTitle': 'Admin',
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  @override
  Future<void> updateChatSettings(
    String chatId, {
    String? name,
    String? description,
    String? avatar,
    bool? isPublic,
    int? slowModeSeconds,
    bool? topicsEnabled,
    bool? signMessages,
    bool? restrictContent,
    String? username,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['groupName'] = name;
    if (description != null) updates['description'] = description;
    if (avatar != null) updates['groupAvatar'] = avatar;
    if (isPublic != null) updates['type'] = isPublic ? 'public' : 'private';
    if (slowModeSeconds != null) updates['slowModeSeconds'] = slowModeSeconds;
    if (topicsEnabled != null) updates['topicsEnabled'] = topicsEnabled;
    if (signMessages != null) updates['signMessages'] = signMessages;
    if (restrictContent != null) updates['restrictContent'] = restrictContent;
    if (username != null) updates['username'] = username;

    if (updates.isNotEmpty) {
      await _firestore.collection('chats').doc(chatId).update(updates);
    }
  }

  @override
  Future<void> joinChat(String chatId, String userId, String userName) async {
    String? photo;
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        photo = userDoc.data()?['photoURL'] as String?;
      }
    } catch (_) {}

    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final memberRef = chatRef.collection('members').doc(userId);

    batch.update(chatRef, {
      'participants': FieldValue.arrayUnion([userId]),
      'memberCount': FieldValue.increment(1),
      'userNames.$userId': userName,
      'unreadCount.$userId': 0,
      if (photo != null) 'userPhotos.$userId': photo,
    });

    batch.set(
      memberRef,
      ChatMemberModel(
        userId: userId,
        displayName: userName,
        photoURL: photo,
        role: MemberRole.member,
        permissions: const MemberPermissions(),
        joinedAt: DateTime.now(),
      ).toFirestore(),
      SetOptions(merge: true),
    );

    // Initial system message for joining
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final msgRef = chatRef.collection('messages').doc(msgId);
    batch.set(msgRef, {
      'id': msgId,
      'senderId': 'system',
      'text': '$userName qo\'shildi.',
      'type': 'text',
      'isRead': false,
      'isDeleted': false,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    await batch.commit();
  }

  @override
  Future<void> leaveChat(String chatId, String userId) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final memberRef = chatRef.collection('members').doc(userId);

    batch.delete(memberRef);
    batch.update(chatRef, {
      'participants': FieldValue.arrayRemove([userId]),
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  @override
  Future<void> deleteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).delete();
  }

  @override
  Stream<List<Topic>> getTopics(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('topics')
        .orderBy('isPinned', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TopicModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<void> createTopic({
    required String chatId,
    required String title,
    required String iconEmoji,
    required String createdBy,
  }) async {
    final topicRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('topics')
        .doc();

    await topicRef.set({
      'id': topicRef.id,
      'chatId': chatId,
      'title': title,
      'iconEmoji': iconEmoji,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'isClosed': false,
      'isPinned': false,
      'messagesCount': 0,
    });
  }

  @override
  Future<void> closeTopic({
    required String chatId,
    required String topicId,
    required bool isClosed,
  }) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('topics')
        .doc(topicId)
        .update({'isClosed': isClosed});
  }

  @override
  Future<void> pinTopic({
    required String chatId,
    required String topicId,
    required bool isPinned,
  }) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('topics')
        .doc(topicId)
        .update({'isPinned': isPinned});
  }

  @override
  Future<void> deleteTopic({
    required String chatId,
    required String topicId,
  }) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('topics')
        .doc(topicId)
        .delete();
  }

  @override
  Future<ChannelStats> getChannelStats(String chatId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final totalMembers = (chatData['memberCount'] as num?)?.toInt() ??
        (chatData['participants'] as List?)?.length ??
        0;

    // Fetch messages to compute analytics
    final messagesSnap = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(150)
        .get();

    int totalViews = 0;
    int totalShares = 0;
    int totalReactions = 0;
    final reactionsMap = <String, int>{};
    final dailyViewsMap = <String, int>{};
    final now = DateTime.now();

    // Prepare last 7 days buckets
    final daysList = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dayKey =
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
      daysList.add(dayKey);
      dailyViewsMap[dayKey] = 0;
    }

    final messages = <MessageModel>[];
    for (final doc in messagesSnap.docs) {
      final msg = MessageModel.fromFirestore(doc);
      if (msg.isDeleted) continue;
      messages.add(msg);

      totalViews += msg.viewsCount > 0 ? msg.viewsCount : 1;
      totalShares += msg.forwardCount;

      for (final r in msg.reactions.values) {
        totalReactions++;
        reactionsMap[r] = (reactionsMap[r] ?? 0) + 1;
      }

      final msgDay =
          '${msg.timestamp.day.toString().padLeft(2, '0')}.${msg.timestamp.month.toString().padLeft(2, '0')}';
      if (dailyViewsMap.containsKey(msgDay)) {
        dailyViewsMap[msgDay] =
            (dailyViewsMap[msgDay] ?? 0) + (msg.viewsCount > 0 ? msg.viewsCount : 1);
      }
    }

    // Top posts sorted by engagement (views + reactions*2 + shares*3)
    final sortedMessages = List<MessageModel>.from(messages);
    sortedMessages.sort((a, b) {
      final scoreA =
          a.viewsCount + (a.reactions.length * 2) + (a.forwardCount * 3);
      final scoreB =
          b.viewsCount + (b.reactions.length * 2) + (b.forwardCount * 3);
      return scoreB.compareTo(scoreA);
    });
    final topMessages = sortedMessages.take(5).toList();

    // Daily views metrics
    final dailyViews = daysList.map((day) {
      return DailyMetric(dateLabel: day, value: dailyViewsMap[day] ?? 0);
    }).toList();

    // Daily growth metric list
    final dailyGrowth = daysList.map((day) {
      final viewsToday = dailyViewsMap[day] ?? 0;
      final estimatedGrowth = (viewsToday * 0.1).round().clamp(0, 50);
      return DailyMetric(dateLabel: day, value: estimatedGrowth);
    }).toList();

    final double engagementRate = totalViews > 0
        ? double.parse(
            (((totalReactions + totalShares) / totalViews) * 100)
                .toStringAsFixed(1))
        : 0.0;

    return ChannelStats(
      chatId: chatId,
      totalMembers: totalMembers,
      totalViews: totalViews,
      totalMessages: messages.length,
      totalReactions: totalReactions,
      totalShares: totalShares,
      engagementRate: engagementRate,
      reactionsBreakdown: reactionsMap,
      dailyViews: dailyViews,
      dailyGrowth: dailyGrowth,
      topMessages: topMessages,
    );
  }

  @override
  Future<void> linkDiscussionGroup({
    required String channelId,
    required String groupId,
    required String groupName,
  }) async {
    await _firestore.collection('chats').doc(channelId).update({
      'linkedGroupId': groupId,
      'linkedGroupName': groupName,
    });
    await _firestore.collection('chats').doc(groupId).update({
      'linkedChannelId': channelId,
    });
  }

  @override
  Future<void> unlinkDiscussionGroup({required String channelId}) async {
    final doc = await _firestore.collection('chats').doc(channelId).get();
    final groupId = doc.data()?['linkedGroupId'] as String?;
    await _firestore.collection('chats').doc(channelId).update({
      'linkedGroupId': FieldValue.delete(),
      'linkedGroupName': FieldValue.delete(),
    });
    if (groupId != null && groupId.isNotEmpty) {
      await _firestore.collection('chats').doc(groupId).update({
        'linkedChannelId': FieldValue.delete(),
      });
    }
  }

  @override
  Future<String> createAndLinkDiscussionGroup({
    required String channelId,
    required String channelName,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final groupName = '$channelName Discussion';
    final groupId = await createGroup(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      name: groupName,
      description: '$channelName kanali uchun rasmiy munozara guruhi',
      isPublic: true,
      initialMemberIds: [currentUserId],
    );

    await linkDiscussionGroup(
      channelId: channelId,
      groupId: groupId,
      groupName: groupName,
    );

    return groupId;
  }

  @override
  Stream<List<ChatFolder>> getUserFolders(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatFolderModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<void> createFolder(String userId, ChatFolder folder) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .doc();

    final model = ChatFolderModel.fromEntity(folder.copyWith(id: docRef.id));
    await docRef.set(model.toJson());
  }

  @override
  Future<void> updateFolder(String userId, ChatFolder folder) async {
    final model = ChatFolderModel.fromEntity(folder);
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .doc(folder.id)
        .update(model.toJson());
  }

  @override
  Future<void> deleteFolder(String userId, String folderId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .doc(folderId)
        .delete();
  }

  @override
  Future<void> reorderFolders(String userId, List<String> folderIds) async {
    final batch = _firestore.batch();
    for (int i = 0; i < folderIds.length; i++) {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('folders')
          .doc(folderIds[i]);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }
}
