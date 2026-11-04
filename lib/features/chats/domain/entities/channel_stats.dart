import 'package:equatable/equatable.dart';
import '../../../messages/domain/entities/message.dart';

class DailyMetric extends Equatable {
  final String dateLabel; // Masalan: "14 Okt", "15 Okt"
  final int value;

  const DailyMetric({
    required this.dateLabel,
    required this.value,
  });

  @override
  List<Object?> get props => [dateLabel, value];
}

class ChannelStats extends Equatable {
  final String chatId;
  final int totalMembers;
  final int totalViews;
  final int totalMessages;
  final int totalReactions;
  final int totalShares;
  final double engagementRate; // Foizda: Masalan, 24.5%
  final Map<String, int> reactionsBreakdown; // emoji -> soni
  final List<DailyMetric> dailyViews; // Oxirgi 7 kunlik ko'rishlar
  final List<DailyMetric> dailyGrowth; // Oxirgi 7 kunlik a'zolar o'sishi
  final List<Message> topMessages; // Eng ko'p ko'rilgan va reaksiyaga boy xabarlar

  const ChannelStats({
    required this.chatId,
    required this.totalMembers,
    required this.totalViews,
    required this.totalMessages,
    required this.totalReactions,
    required this.totalShares,
    required this.engagementRate,
    this.reactionsBreakdown = const {},
    this.dailyViews = const [],
    this.dailyGrowth = const [],
    this.topMessages = const [],
  });

  @override
  List<Object?> get props => [
        chatId,
        totalMembers,
        totalViews,
        totalMessages,
        totalReactions,
        totalShares,
        engagementRate,
        reactionsBreakdown,
        dailyViews,
        dailyGrowth,
        topMessages,
      ];
}
