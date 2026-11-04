import 'package:equatable/equatable.dart';
import '../../../../core/localization/localization_service.dart';
import 'chat.dart';

class ChatFolder extends Equatable {
  final String id;
  final String name;
  final String icon;
  final bool isDefault;
  final List<String> includedChatIds;
  final List<String> excludedChatIds;
  final bool includeDirect;
  final bool includeGroups;
  final bool includeChannels;
  final bool includeUnreadOnly;
  final int order;
  final String? presetId;

  const ChatFolder({
    required this.id,
    required this.name,
    this.icon = '📁',
    this.isDefault = false,
    this.includedChatIds = const [],
    this.excludedChatIds = const [],
    this.includeDirect = true,
    this.includeGroups = true,
    this.includeChannels = true,
    this.includeUnreadOnly = false,
    this.order = 0,
    this.presetId,
  });

  String get localizedName {
    if (isDefault ||
        id == allId ||
        id == directId ||
        id == groupsId ||
        id == channelsId ||
        id == unreadId) {
      switch (id) {
        case allId:
          return LocalizationService.translate('folder_all');
        case directId:
          return LocalizationService.translate('folder_direct');
        case groupsId:
          return LocalizationService.translate('folder_groups');
        case channelsId:
          return LocalizationService.translate('folder_channels');
        case unreadId:
          return LocalizationService.translate('folder_unread');
      }
    }
    // Check stable preset identifier
    if (presetId != null) {
      switch (presetId) {
        case 'work':
          return LocalizationService.translate('recommended_work');
        case 'study':
          return LocalizationService.translate('recommended_study');
        case 'friends':
          return LocalizationService.translate('recommended_friends');
        case 'family':
          return LocalizationService.translate('recommended_family');
        case 'important':
          return LocalizationService.translate('recommended_important');
        case 'projects':
          return LocalizationService.translate('recommended_projects');
      }
    }
    // Handle fallback by known canonical names
    if (name == 'Barchasi' || name == 'All' || name == 'Все') {
      return LocalizationService.translate('folder_all');
    }
    if (name == 'Shaxsiy' || name == 'Private' || name == 'Личные') {
      return LocalizationService.translate('folder_direct');
    }
    if (name == 'Guruhlar' || name == 'Groups' || name == 'Группы') {
      return LocalizationService.translate('folder_groups');
    }
    if (name == 'Kanallar' || name == 'Channels' || name == 'Каналы') {
      return LocalizationService.translate('folder_channels');
    }
    if (name == "O'qilmaganlar" ||
        name == 'O‘qilmaganlar' ||
        name == 'O‘qilmagan' ||
        name == 'Unread' ||
        name == 'Непрочитанные') {
      return LocalizationService.translate('folder_unread');
    }
    // Handle built-in preset folders dynamically (apostrophe-variant tolerant)
    final n = name
        .trim()
        .toLowerCase()
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u02BB', "'")
        .replaceAll('\u02BC', "'")
        .replaceAll('`', "'");
    if (n == 'ish' || n == 'work' || n == 'работа') {
      return LocalizationService.translate('recommended_work');
    }
    if (n == "o'qish" || n == 'study' || n == 'учёба' || n == 'учеба') {
      return LocalizationService.translate('recommended_study');
    }
    if (n == "do'stlar" || n == 'friends' || n == 'друзья') {
      return LocalizationService.translate('recommended_friends');
    }
    if (n == 'oila' || n == 'family' || n == 'семья') {
      return LocalizationService.translate('recommended_family');
    }
    if (n == 'muhim' || n == 'important' || n == 'важное') {
      return LocalizationService.translate('recommended_important');
    }
    if (n == 'loyihalar' || n == 'projects' || n == 'проекты') {
      return LocalizationService.translate('recommended_projects');
    }
    return name;
  }

  // Default system folders
  static const String allId = 'folder_all';
  static const String directId = 'folder_direct';
  static const String groupsId = 'folder_groups';
  static const String channelsId = 'folder_channels';
  static const String unreadId = 'folder_unread';

  static List<ChatFolder> defaultFolders() {
    return const [
      ChatFolder(
        id: allId,
        name: 'Barchasi',
        icon: '💬',
        isDefault: true,
        order: 0,
      ),
      ChatFolder(
        id: directId,
        name: 'Shaxsiy',
        icon: '👤',
        isDefault: true,
        includeDirect: true,
        includeGroups: false,
        includeChannels: false,
        order: 1,
      ),
      ChatFolder(
        id: groupsId,
        name: 'Guruhlar',
        icon: '👥',
        isDefault: true,
        includeDirect: false,
        includeGroups: true,
        includeChannels: false,
        order: 2,
      ),
      ChatFolder(
        id: channelsId,
        name: 'Kanallar',
        icon: '📢',
        isDefault: true,
        includeDirect: false,
        includeGroups: false,
        includeChannels: true,
        order: 3,
      ),
      ChatFolder(
        id: unreadId,
        name: 'O\'qilmaganlar',
        icon: '✉️',
        isDefault: true,
        includeUnreadOnly: true,
        order: 4,
      ),
    ];
  }

  bool matches(Chat chat) {
    // 1. Excluded check
    if (excludedChatIds.contains(chat.id)) return false;

    // 2. Explicitly included chat check
    if (includedChatIds.contains(chat.id)) return true;

    // 3. Default "Barchasi" includes all non-excluded
    if (id == allId) return true;

    // 4. Default "O'qilmaganlar"
    if (id == unreadId) return chat.unreadCount > 0;

    // 5. Default "Shaxsiy"
    if (id == directId) return !chat.isGroup && !chat.isChannel;

    // 6. Default "Guruhlar"
    if (id == groupsId) return chat.isGroup && !chat.isChannel;

    // 7. Default "Kanallar"
    if (id == channelsId) return chat.isChannel;

    // 8. Custom folder filter logic
    if (includeUnreadOnly && chat.unreadCount <= 0) return false;

    if (!chat.isGroup && !chat.isChannel) {
      if (includeDirect) return true;
    } else if (chat.isGroup && !chat.isChannel) {
      if (includeGroups) return true;
    } else if (chat.isChannel) {
      if (includeChannels) return true;
    }

    return false;
  }

  ChatFolder copyWith({
    String? id,
    String? name,
    String? icon,
    bool? isDefault,
    List<String>? includedChatIds,
    List<String>? excludedChatIds,
    bool? includeDirect,
    bool? includeGroups,
    bool? includeChannels,
    bool? includeUnreadOnly,
    int? order,
    String? presetId,
  }) {
    return ChatFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
      includedChatIds: includedChatIds ?? this.includedChatIds,
      excludedChatIds: excludedChatIds ?? this.excludedChatIds,
      includeDirect: includeDirect ?? this.includeDirect,
      includeGroups: includeGroups ?? this.includeGroups,
      includeChannels: includeChannels ?? this.includeChannels,
      includeUnreadOnly: includeUnreadOnly ?? this.includeUnreadOnly,
      order: order ?? this.order,
      presetId: presetId ?? this.presetId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        icon,
        isDefault,
        includedChatIds,
        excludedChatIds,
        includeDirect,
        includeGroups,
        includeChannels,
        includeUnreadOnly,
        order,
        presetId,
      ];
}
