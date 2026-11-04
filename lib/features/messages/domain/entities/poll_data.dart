import 'package:equatable/equatable.dart';

class PollOption extends Equatable {
  final int id;
  final String text;
  final List<String> voterIds;

  const PollOption({
    required this.id,
    required this.text,
    this.voterIds = const [],
  });

  int get votesCount => voterIds.length;

  bool hasUserVoted(String userId) => voterIds.contains(userId);

  PollOption copyWith({
    int? id,
    String? text,
    List<String>? voterIds,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      voterIds: voterIds ?? this.voterIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'voterIds': voterIds,
    };
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: (map['id'] as num?)?.toInt() ?? 0,
      text: map['text'] as String? ?? '',
      voterIds: List<String>.from(map['voterIds'] ?? []),
    );
  }

  @override
  List<Object?> get props => [id, text, voterIds];
}

class PollData extends Equatable {
  final String id;
  final String question;
  final List<PollOption> options;
  final bool isAnonymous;
  final bool allowsMultipleAnswers;
  final bool isQuiz;
  final int? correctOptionId;
  final String? explanation;
  final bool isClosed;
  final String? creatorId;

  const PollData({
    required this.id,
    required this.question,
    required this.options,
    this.isAnonymous = false,
    this.allowsMultipleAnswers = false,
    this.isQuiz = false,
    this.correctOptionId,
    this.explanation,
    this.isClosed = false,
    this.creatorId,
  });

  int get totalVoters {
    final Set<String> uniqueVoters = {};
    for (final opt in options) {
      uniqueVoters.addAll(opt.voterIds);
    }
    return uniqueVoters.length;
  }

  int get totalVotes {
    int count = 0;
    for (final opt in options) {
      count += opt.voterIds.length;
    }
    return count;
  }

  bool hasVoted(String userId) {
    return options.any((opt) => opt.hasUserVoted(userId));
  }

  List<int> getUserSelectedOptionIds(String userId) {
    return options
        .where((opt) => opt.hasUserVoted(userId))
        .map((opt) => opt.id)
        .toList();
  }

  double getPercentage(int optionId) {
    final total = totalVoters;
    if (total == 0) return 0.0;
    final option = options.firstWhere(
      (opt) => opt.id == optionId,
      orElse: () => const PollOption(id: -1, text: ''),
    );
    return (option.votesCount / total).clamp(0.0, 1.0);
  }

  PollData copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    bool? isAnonymous,
    bool? allowsMultipleAnswers,
    bool? isQuiz,
    int? correctOptionId,
    String? explanation,
    bool? isClosed,
    String? creatorId,
  }) {
    return PollData(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      allowsMultipleAnswers:
          allowsMultipleAnswers ?? this.allowsMultipleAnswers,
      isQuiz: isQuiz ?? this.isQuiz,
      correctOptionId: correctOptionId ?? this.correctOptionId,
      explanation: explanation ?? this.explanation,
      isClosed: isClosed ?? this.isClosed,
      creatorId: creatorId ?? this.creatorId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options.map((opt) => opt.toMap()).toList(),
      'isAnonymous': isAnonymous,
      'allowsMultipleAnswers': allowsMultipleAnswers,
      'isQuiz': isQuiz,
      'correctOptionId': correctOptionId,
      'explanation': explanation,
      'isClosed': isClosed,
      'creatorId': creatorId,
    };
  }

  factory PollData.fromMap(Map<String, dynamic> map) {
    return PollData(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: (map['options'] as List<dynamic>? ?? [])
          .map((item) =>
              PollOption.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      isAnonymous: map['isAnonymous'] as bool? ?? false,
      allowsMultipleAnswers: map['allowsMultipleAnswers'] as bool? ?? false,
      isQuiz: map['isQuiz'] as bool? ?? false,
      correctOptionId: (map['correctOptionId'] as num?)?.toInt(),
      explanation: map['explanation'] as String?,
      isClosed: map['isClosed'] as bool? ?? false,
      creatorId: map['creatorId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        question,
        options,
        isAnonymous,
        allowsMultipleAnswers,
        isQuiz,
        correctOptionId,
        explanation,
        isClosed,
        creatorId,
      ];
}
