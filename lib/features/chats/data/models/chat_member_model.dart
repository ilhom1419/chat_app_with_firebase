import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/chat_member.dart';

class ChatMemberModel extends ChatMember {
  const ChatMemberModel({
    required super.userId,
    required super.displayName,
    super.photoURL,
    super.role = MemberRole.member,
    super.customTitle,
    super.permissions = const MemberPermissions(),
    required super.joinedAt,
    super.invitedBy,
    super.untilDate,
    super.isOnline = false,
  });

  factory ChatMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ChatMemberModel.fromMap(data, doc.id);
  }

  factory ChatMemberModel.fromMap(Map<String, dynamic> data, String userId) {
    final roleStr = data['role'] as String? ?? 'member';
    final role = MemberRole.fromString(roleStr);

    final permissionsMap = data['permissions'] as Map<String, dynamic>?;
    final permissions = permissionsMap != null
        ? MemberPermissions.fromMap(permissionsMap)
        : (role.isAdmin
            ? const MemberPermissions.admin()
            : (role.isRestricted
                ? const MemberPermissions.restricted()
                : const MemberPermissions()));

    DateTime joinedAt = DateTime.now();
    if (data['joinedAt'] != null && data['joinedAt'] is Timestamp) {
      joinedAt = (data['joinedAt'] as Timestamp).toDate();
    }

    DateTime? untilDate;
    if (data['untilDate'] != null && data['untilDate'] is Timestamp) {
      untilDate = (data['untilDate'] as Timestamp).toDate();
    }

    return ChatMemberModel(
      userId: userId,
      displayName: data['displayName'] as String? ?? 'User',
      photoURL: data['photoURL'] as String?,
      role: role,
      customTitle: data['customTitle'] as String?,
      permissions: permissions,
      joinedAt: joinedAt,
      invitedBy: data['invitedBy'] as String?,
      untilDate: untilDate,
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.name,
      'customTitle': customTitle,
      'permissions': permissions.toMap(),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'invitedBy': invitedBy,
      'untilDate': untilDate != null ? Timestamp.fromDate(untilDate!) : null,
      'isOnline': isOnline,
    };
  }
}
