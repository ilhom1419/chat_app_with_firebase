import 'package:equatable/equatable.dart';
import '../../../../core/localization/localization_service.dart';

enum MemberRole {
  owner,
  admin,
  member,
  restricted,
  banned;

  bool get isOwner => this == MemberRole.owner;
  bool get isAdmin => this == MemberRole.admin;
  bool get isMember => this == MemberRole.member;
  bool get isRestricted => this == MemberRole.restricted;
  bool get isBanned => this == MemberRole.banned;

  String get localizedName {
    switch (this) {
      case MemberRole.owner:
        return LocalizationService.translate('role_owner');
      case MemberRole.admin:
        return LocalizationService.translate('role_admin');
      case MemberRole.member:
        return LocalizationService.translate('role_member');
      case MemberRole.restricted:
        return LocalizationService.translate('role_restricted');
      case MemberRole.banned:
        return LocalizationService.translate('role_banned');
    }
  }

  static MemberRole fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'owner':
        return MemberRole.owner;
      case 'admin':
        return MemberRole.admin;
      case 'restricted':
        return MemberRole.restricted;
      case 'banned':
        return MemberRole.banned;
      case 'member':
      default:
        return MemberRole.member;
    }
  }
}

class MemberPermissions extends Equatable {
  final bool canSendMessages;
  final bool canSendMedia;
  final bool canSendPolls;
  final bool canAddMembers;
  final bool canPinMessages;
  final bool canChangeInfo;
  final bool canManageTopics;

  const MemberPermissions({
    this.canSendMessages = true,
    this.canSendMedia = true,
    this.canSendPolls = true,
    this.canAddMembers = true,
    this.canPinMessages = false,
    this.canChangeInfo = false,
    this.canManageTopics = false,
  });

  const MemberPermissions.admin()
      : canSendMessages = true,
        canSendMedia = true,
        canSendPolls = true,
        canAddMembers = true,
        canPinMessages = true,
        canChangeInfo = true,
        canManageTopics = true;

  const MemberPermissions.restricted()
      : canSendMessages = false,
        canSendMedia = false,
        canSendPolls = false,
        canAddMembers = false,
        canPinMessages = false,
        canChangeInfo = false,
        canManageTopics = false;

  MemberPermissions copyWith({
    bool? canSendMessages,
    bool? canSendMedia,
    bool? canSendPolls,
    bool? canAddMembers,
    bool? canPinMessages,
    bool? canChangeInfo,
    bool? canManageTopics,
  }) {
    return MemberPermissions(
      canSendMessages: canSendMessages ?? this.canSendMessages,
      canSendMedia: canSendMedia ?? this.canSendMedia,
      canSendPolls: canSendPolls ?? this.canSendPolls,
      canAddMembers: canAddMembers ?? this.canAddMembers,
      canPinMessages: canPinMessages ?? this.canPinMessages,
      canChangeInfo: canChangeInfo ?? this.canChangeInfo,
      canManageTopics: canManageTopics ?? this.canManageTopics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canSendMessages': canSendMessages,
      'canSendMedia': canSendMedia,
      'canSendPolls': canSendPolls,
      'canAddMembers': canAddMembers,
      'canPinMessages': canPinMessages,
      'canChangeInfo': canChangeInfo,
      'canManageTopics': canManageTopics,
    };
  }

  factory MemberPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MemberPermissions();
    return MemberPermissions(
      canSendMessages: map['canSendMessages'] as bool? ?? true,
      canSendMedia: map['canSendMedia'] as bool? ?? true,
      canSendPolls: map['canSendPolls'] as bool? ?? true,
      canAddMembers: map['canAddMembers'] as bool? ?? true,
      canPinMessages: map['canPinMessages'] as bool? ?? false,
      canChangeInfo: map['canChangeInfo'] as bool? ?? false,
      canManageTopics: map['canManageTopics'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        canSendMessages,
        canSendMedia,
        canSendPolls,
        canAddMembers,
        canPinMessages,
        canChangeInfo,
        canManageTopics,
      ];
}

class ChatMember extends Equatable {
  final String userId;
  final String displayName;
  final String? photoURL;
  final MemberRole role;
  final String? customTitle;
  final MemberPermissions permissions;
  final DateTime joinedAt;
  final String? invitedBy;
  final DateTime? untilDate;
  final bool isOnline;

  const ChatMember({
    required this.userId,
    required this.displayName,
    this.photoURL,
    this.role = MemberRole.member,
    this.customTitle,
    this.permissions = const MemberPermissions(),
    required this.joinedAt,
    this.invitedBy,
    this.untilDate,
    this.isOnline = false,
  });

  bool get isOwner => role == MemberRole.owner;
  bool get isAdmin => role == MemberRole.admin || role == MemberRole.owner;
  bool get isRestricted => role == MemberRole.restricted;
  bool get isBanned => role == MemberRole.banned;

  bool canPostMessage(bool isChannel) {
    if (isChannel) {
      return isAdmin; // Kanallarda faqat admin va egasi yozadi
    }
    if (isBanned) return false;
    if (isRestricted) return permissions.canSendMessages;
    return true;
  }

  ChatMember copyWith({
    String? displayName,
    String? photoURL,
    MemberRole? role,
    String? customTitle,
    MemberPermissions? permissions,
    DateTime? joinedAt,
    String? invitedBy,
    DateTime? untilDate,
    bool? isOnline,
  }) {
    return ChatMember(
      userId: userId,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      customTitle: customTitle ?? this.customTitle,
      permissions: permissions ?? this.permissions,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      untilDate: untilDate ?? this.untilDate,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        displayName,
        photoURL,
        role,
        customTitle,
        permissions,
        joinedAt,
        invitedBy,
        untilDate,
        isOnline,
      ];
}
