import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/message.dart';

/// Represents the position of a message within a group of consecutive messages
/// sent by the same user within a short time window.
enum MessageGroupPosition {
  single,
  first,
  middle,
  last,
}

/// Design system specifications and styling utilities for Kakku chat message bubbles.
/// Inspired by Telegram and iMessage polish, retaining Kakku's signature blue-violet identity.
class ChatBubbleTheme {
  const ChatBubbleTheme._();

  // ===========================================================================
  // GROUPING LOGIC
  // ===========================================================================

  /// Threshold within which consecutive messages from the same sender are visually grouped.
  static const Duration groupingTimeThreshold = Duration(minutes: 5);

  /// Determines the grouping position of a message at [index] in [messages].
  static MessageGroupPosition calculateGroupPosition(
    List<Message> messages,
    int index,
    String? currentUserId,
  ) {
    if (index < 0 || index >= messages.length) {
      return MessageGroupPosition.single;
    }

    final current = messages[index];
    final hasPrev = index > 0;
    final hasNext = index < messages.length - 1;

    bool isGroupedWithPrev = false;
    if (hasPrev) {
      final prev = messages[index - 1];
      isGroupedWithPrev = _areMessagesInSameGroup(prev, current);
    }

    bool isGroupedWithNext = false;
    if (hasNext) {
      final next = messages[index + 1];
      isGroupedWithNext = _areMessagesInSameGroup(current, next);
    }

    if (isGroupedWithPrev && isGroupedWithNext) {
      return MessageGroupPosition.middle;
    } else if (!isGroupedWithPrev && isGroupedWithNext) {
      return MessageGroupPosition.first;
    } else if (isGroupedWithPrev && !isGroupedWithNext) {
      return MessageGroupPosition.last;
    } else {
      return MessageGroupPosition.single;
    }
  }

  static bool _areMessagesInSameGroup(Message a, Message b) {
    // Must be sent by the same user
    if (a.senderId != b.senderId) return false;

    // Must not be deleted
    if (a.isDeleted || b.isDeleted) return false;

    // Must be on the exact same calendar day
    if (a.timestamp.year != b.timestamp.year ||
        a.timestamp.month != b.timestamp.month ||
        a.timestamp.day != b.timestamp.day) {
      return false;
    }

    // Must be within grouping time threshold
    final diff = b.timestamp.difference(a.timestamp).abs();
    if (diff > groupingTimeThreshold) return false;

    // Must be in the same topic if topics are present
    if (a.topicId != b.topicId) return false;

    return true;
  }

  // ===========================================================================
  // CORNER RADII (Telegram / iMessage style)
  // ===========================================================================

  static const double radiusLarge = 18.0;
  static const double radiusSmall = 4.0;
  static const double radiusGroupInner = 6.0;

  /// Coordinated rounded corner radii based on sender and consecutive grouping.
  static BorderRadius getBubbleRadius(bool isMe, MessageGroupPosition position) {
    if (isMe) {
      // Outgoing: flat/tail is on bottom-right
      switch (position) {
        case MessageGroupPosition.single:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusLarge),
            topRight: Radius.circular(radiusLarge),
            bottomLeft: Radius.circular(radiusLarge),
            bottomRight: Radius.circular(radiusSmall),
          );
        case MessageGroupPosition.first:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusLarge),
            topRight: Radius.circular(radiusLarge),
            bottomLeft: Radius.circular(radiusLarge),
            bottomRight: Radius.circular(radiusGroupInner),
          );
        case MessageGroupPosition.middle:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusLarge),
            topRight: Radius.circular(radiusGroupInner),
            bottomLeft: Radius.circular(radiusLarge),
            bottomRight: Radius.circular(radiusGroupInner),
          );
        case MessageGroupPosition.last:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusLarge),
            topRight: Radius.circular(radiusGroupInner),
            bottomLeft: Radius.circular(radiusLarge),
            bottomRight: Radius.circular(radiusSmall),
          );
      }
    } else {
      // Incoming: flat/tail is on bottom-left
      switch (position) {
        case MessageGroupPosition.single:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusLarge),
            topRight: Radius.circular(radiusLarge),
            bottomLeft: Radius.circular(radiusSmall),
            bottomRight: Radius.circular(radiusLarge),
          );
        case MessageGroupPosition.first:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusLarge),
            topRight: Radius.circular(radiusLarge),
            bottomLeft: Radius.circular(radiusGroupInner),
            bottomRight: Radius.circular(radiusLarge),
          );
        case MessageGroupPosition.middle:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusGroupInner),
            topRight: Radius.circular(radiusLarge),
            bottomLeft: Radius.circular(radiusGroupInner),
            bottomRight: Radius.circular(radiusLarge),
          );
        case MessageGroupPosition.last:
          return const BorderRadius.only(
            topLeft: Radius.circular(radiusGroupInner),
            topRight: Radius.circular(radiusLarge),
            bottomLeft: Radius.circular(radiusSmall),
            bottomRight: Radius.circular(radiusLarge),
          );
      }
    }
  }

  // ===========================================================================
  // SPACING & MARGINS
  // ===========================================================================

  /// Vertical margin below a message bubble.
  /// Grouped consecutive messages use tight spacing (2.5px); sender changes use 9px.
  static EdgeInsets getBubbleMargin(MessageGroupPosition position) {
    final bottomMargin = (position == MessageGroupPosition.first ||
            position == MessageGroupPosition.middle)
        ? 2.5
        : 9.0;
    return EdgeInsets.only(bottom: bottomMargin);
  }

  /// Default text message internal content padding.
  static const EdgeInsets textPadding =
      EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);

  // ===========================================================================
  // PALETTE & DECORATION
  // ===========================================================================

  // Kakku Signature Indigo-Violet Gradients
  static const Color outgoingIndigoLight = Color(0xFF6366F1); // Vivid Indigo
  static const Color outgoingIndigoDark = Color(0xFF4F46E5);  // Deep Indigo
  static const Color outgoingVioletEnd = Color(0xFF4338CA);   // Royal Indigo
  static const Color outgoingDarkViolet = Color(0xFF5346E6);  // Refined Blue-Violet

  // Incoming Surfaces
  static const Color incomingDarkSurface = Color(0xFF1E293B); // Dark slate
  static const Color incomingDarkBorder = Color(0x1AFFFFFF);  // 10% white
  static const Color incomingLightSurface = Color(0xFFFFFFFF); // Clean white
  static const Color incomingLightBorder = Color(0xFFE2E8F0); // Subtle gray border

  /// Premium bubble container decoration with smooth gradients and subtle shadows.
  static BoxDecoration getBubbleDecoration({
    required bool isMe,
    required bool isDark,
    required MessageGroupPosition position,
    bool isHighlighted = false,
  }) {
    final borderRadius = getBubbleRadius(isMe, position);

    if (isMe) {
      return BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF5B4FE9), Color(0xFF4338CA)]
              : const [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: isHighlighted
            ? Border.all(color: Colors.amber, width: 2)
            : null,
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: Colors.amber.withOpacity(0.55),
              blurRadius: 12,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: const Color(0xFF4338CA).withOpacity(isDark ? 0.35 : 0.20),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
        ],
      );
    } else {
      return BoxDecoration(
        borderRadius: borderRadius,
        color: isDark ? incomingDarkSurface : incomingLightSurface,
        border: isHighlighted
            ? Border.all(color: Colors.amber, width: 2)
            : Border.all(
                color: isDark ? incomingDarkBorder : incomingLightBorder,
                width: 0.75,
              ),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: Colors.amber.withOpacity(0.55),
              blurRadius: 12,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      );
    }
  }

  // ===========================================================================
  // TYPOGRAPHY & COLORS
  // ===========================================================================

  static Color getTextColor({required bool isMe, required bool isDark}) {
    if (isMe) return Colors.white;
    return isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  }

  static Color getTimestampColor({required bool isMe, required bool isDark}) {
    if (isMe) return Colors.white.withOpacity(0.72);
    return isDark ? Colors.white54 : AppColors.textSecondaryLight;
  }

  static Color getSecondaryIconColor({required bool isMe, required bool isDark}) {
    if (isMe) return Colors.white.withOpacity(0.70);
    return isDark ? Colors.white38 : Colors.black38;
  }
}
