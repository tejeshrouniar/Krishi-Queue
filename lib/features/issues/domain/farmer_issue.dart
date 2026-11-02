enum IssueKind { registration, token, weighing, payment, other }

const issueEvidence = ['token', 'weighing', 'purchase', 'reference'];

DateTime localDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class IssueUpdate {
  final DateTime date;
  final String note;
  const IssueUpdate({required this.date, required this.note});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'note': note,
  };
  factory IssueUpdate.fromJson(Map<String, dynamic> json) => IssueUpdate(
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String,
  );
}

/// Personal follow-up notes; neither an official case nor a verified decision.
class FarmerIssue {
  final String id;
  final IssueKind kind;
  final String centre;
  final String description;
  final String officialReference;
  final DateTime occurredOn;
  final DateTime? followUpOn;
  final bool resolved;
  final Set<String> evidence;
  final List<IssueUpdate> updates;
  final DateTime updatedAt;

  FarmerIssue({
    required this.id,
    required this.kind,
    required this.centre,
    required this.description,
    required this.occurredOn,
    required this.updatedAt,
    this.officialReference = '',
    this.followUpOn,
    this.resolved = false,
    Set<String> evidence = const {},
    List<IssueUpdate> updates = const [],
  }) : evidence = Set.unmodifiable(evidence),
       updates = List.unmodifiable(updates);

  bool needsFollowUp(DateTime now) =>
      !resolved &&
      followUpOn != null &&
      !localDay(followUpOn!).isAfter(localDay(now));

  void validate() {
    if (id.isEmpty ||
        id.length > 100 ||
        centre.trim().isEmpty ||
        centre.length > 120 ||
        description.trim().isEmpty ||
        description.length > 1000 ||
        officialReference.length > 80 ||
        updates.length > 30 ||
        evidence.any((key) => !issueEvidence.contains(key)) ||
        updates.any(
          (entry) => entry.note.trim().isEmpty || entry.note.length > 500,
        )) {
      throw const FormatException(
        'The personal note has invalid or overlong fields.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'centre': centre,
    'description': description,
    'officialReference': officialReference,
    'occurredOn': occurredOn.toIso8601String(),
    'followUpOn': followUpOn?.toIso8601String(),
    'resolved': resolved,
    'evidence': evidence.toList(),
    'updates': updates.map((entry) => entry.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FarmerIssue.fromJson(Map<String, dynamic> json) {
    final issue = FarmerIssue(
      id: json['id'] as String,
      kind: IssueKind.values.byName(json['kind'] as String),
      centre: json['centre'] as String,
      description: json['description'] as String,
      officialReference: json['officialReference'] as String,
      occurredOn: DateTime.parse(json['occurredOn'] as String),
      followUpOn: json['followUpOn'] == null
          ? null
          : DateTime.parse(json['followUpOn'] as String),
      resolved: json['resolved'] as bool,
      evidence: (json['evidence'] as List).cast<String>().toSet(),
      updates: (json['updates'] as List)
          .map(
            (entry) =>
                IssueUpdate.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
    issue.validate();
    return issue;
  }
}
