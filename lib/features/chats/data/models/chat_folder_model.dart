import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_folder.dart';

class ChatFolderModel extends ChatFolder {
  const ChatFolderModel({
    required super.id,
    required super.name,
    super.icon = '📁',
    super.isDefault = false,
    super.includedChatIds = const [],
    super.excludedChatIds = const [],
    super.includeDirect = true,
    super.includeGroups = true,
    super.includeChannels = true,
    super.includeUnreadOnly = false,
    super.order = 0,
    super.presetId,
  });

  factory ChatFolderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatFolderModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Papka',
      icon: data['icon'] as String? ?? '📁',
      isDefault: data['isDefault'] as bool? ?? false,
      includedChatIds: List<String>.from(data['includedChatIds'] ?? []),
      excludedChatIds: List<String>.from(data['excludedChatIds'] ?? []),
      includeDirect: data['includeDirect'] as bool? ?? true,
      includeGroups: data['includeGroups'] as bool? ?? true,
      includeChannels: data['includeChannels'] as bool? ?? true,
      includeUnreadOnly: data['includeUnreadOnly'] as bool? ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      presetId: data['presetId'] as String?,
    );
  }

  factory ChatFolderModel.fromEntity(ChatFolder entity) {
    return ChatFolderModel(
      id: entity.id,
      name: entity.name,
      icon: entity.icon,
      isDefault: entity.isDefault,
      includedChatIds: entity.includedChatIds,
      excludedChatIds: entity.excludedChatIds,
      includeDirect: entity.includeDirect,
      includeGroups: entity.includeGroups,
      includeChannels: entity.includeChannels,
      includeUnreadOnly: entity.includeUnreadOnly,
      order: entity.order,
      presetId: entity.presetId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
      'isDefault': isDefault,
      'includedChatIds': includedChatIds,
      'excludedChatIds': excludedChatIds,
      'includeDirect': includeDirect,
      'includeGroups': includeGroups,
      'includeChannels': includeChannels,
      'includeUnreadOnly': includeUnreadOnly,
      'order': order,
      if (presetId != null) 'presetId': presetId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
