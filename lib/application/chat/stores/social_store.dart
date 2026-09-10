class SocialStore {
  final int friendRevision;
  final int groupRevision;

  const SocialStore({
    this.friendRevision = 0,
    this.groupRevision = 0,
  });

  SocialStore copyWith({int? friendRevision, int? groupRevision}) {
    if (friendRevision == null && groupRevision == null) return this;
    return SocialStore(
      friendRevision: friendRevision ?? this.friendRevision,
      groupRevision: groupRevision ?? this.groupRevision,
    );
  }
}
