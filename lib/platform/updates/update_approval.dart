final class UpdateApproval {
  const UpdateApproval._({required this.isApproved, this.artifactDigest});

  static const denied = UpdateApproval._(isApproved: false);

  factory UpdateApproval.approved(String artifactDigest) {
    return UpdateApproval._(
      isApproved: true,
      artifactDigest: artifactDigest.toLowerCase(),
    );
  }

  final bool isApproved;
  final String? artifactDigest;
}
