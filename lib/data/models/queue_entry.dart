class QueueEntry {
  final int? id;
  final String episodeGuid;
  final int sortOrder;

  const QueueEntry({
    this.id,
    required this.episodeGuid,
    required this.sortOrder,
  });

  factory QueueEntry.fromMap(Map<String, Object?> map) {
    return QueueEntry(
      id: map['id'] as int?,
      episodeGuid: map['episode_guid'] as String,
      sortOrder: map['sort_order'] as int,
    );
  }

  Map<String, Object?> toMap() {
    final Map<String, Object?> map = {
      'episode_guid': episodeGuid,
      'sort_order': sortOrder,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}
