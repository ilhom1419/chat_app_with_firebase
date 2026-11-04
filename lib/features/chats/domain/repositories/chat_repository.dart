import '../entities/chat.dart';
import '../entities/chat_member.dart';
import '../entities/topic.dart';
import '../entities/channel_stats.dart';
import '../entities/chat_folder.dart';
import '../../../auth/domain/entities/app_user.dart';

abstract class ChatRepository {
  Stream<List<Chat>> getChats(String currentUserId);
  Future<String> createOrGetChat(String currentUserId, String otherUserId);
  Future<List<AppUser>> searchUsers(String query, String currentUserId);
  Future<void> markAsRead(String chatId, String userId);
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping);

  // Kanal va Guruh yaratish (Create Channel & Group)
  Future<String> createChannel({
    required String currentUserId,
    required String currentUserName,
    required String name,
    String? description,
    String? avatar,
    bool isPublic = true,
    List<String> initialMemberIds = const [],
  });

  Future<String> createGroup({
    required String currentUserId,
    required String currentUserName,
    required String name,
    String? description,
    String? avatar,
    bool isPublic = true,
    required List<String> initialMemberIds,
  });

  // A'zolar va Ruxsatlarni boshqarish (Members & Permissions Management)
  Stream<List<ChatMember>> getChatMembers(String chatId);
  Future<ChatMember?> getChatMember(String chatId, String userId);
  Stream<ChatMember?> streamChatMember(String chatId, String userId);

  Future<void> updateMemberRole(
    String chatId,
    String targetUserId,
    MemberRole role, {
    String? customTitle,
    MemberPermissions? permissions,
  });

  Future<void> updateMemberPermissions(
    String chatId,
    String targetUserId,
    MemberPermissions permissions,
  );

  Future<void> removeMember(String chatId, String targetUserId);
  Future<void> banMember(String chatId, String targetUserId);
  Future<void> unbanMember(String chatId, String targetUserId);
  Future<void> transferOwnership(String chatId, String newOwnerId);

  // Sozlamalar va A'zolik (Settings & Membership)
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
  });

  Future<void> joinChat(String chatId, String userId, String userName);
  Future<void> leaveChat(String chatId, String userId);
  Future<void> deleteChat(String chatId);

  // Kanal va Guruh statistikasi (Channel & Group Analytics)
  Future<ChannelStats> getChannelStats(String chatId);

  // Forum Mavzulari (Topics)
  Stream<List<Topic>> getTopics(String chatId);
  Future<void> createTopic({
    required String chatId,
    required String title,
    required String iconEmoji,
    required String createdBy,
  });
  Future<void> closeTopic({
    required String chatId,
    required String topicId,
    required bool isClosed,
  });
  Future<void> pinTopic({
    required String chatId,
    required String topicId,
    required bool isPinned,
  });
  Future<void> deleteTopic({
    required String chatId,
    required String topicId,
  });

  // Kanalga bog'langan Munozara Guruhi (Linked Discussion Group)
  Future<void> linkDiscussionGroup({
    required String channelId,
    required String groupId,
    required String groupName,
  });
  Future<void> unlinkDiscussionGroup({required String channelId});
  Future<String> createAndLinkDiscussionGroup({
    required String channelId,
    required String channelName,
    required String currentUserId,
    required String currentUserName,
  });

  // Chat Papkalari (Chat Folders & Custom Tabs)
  Stream<List<ChatFolder>> getUserFolders(String userId);
  Future<void> createFolder(String userId, ChatFolder folder);
  Future<void> updateFolder(String userId, ChatFolder folder);
  Future<void> deleteFolder(String userId, String folderId);
  Future<void> reorderFolders(String userId, List<String> folderIds);
}
