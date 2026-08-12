final class ReleaseVersion implements Comparable<ReleaseVersion> {
  ReleaseVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.channel,
    required this.sequence,
  });

  static final RegExp _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-(alpha|beta|rc)\.(0|[1-9]\d*))?$',
  );

  factory ReleaseVersion.parseTag(String tag) {
    if (!tag.startsWith('v')) {
      throw FormatException('Release tag must begin with v: $tag');
    }
    return ReleaseVersion.parse(tag.substring(1));
  }

  factory ReleaseVersion.parse(String version) {
    final match = _pattern.firstMatch(version);
    if (match == null) {
      throw FormatException('Release version is malformed: $version');
    }

    final major = int.parse(match[1]!);
    final minor = int.parse(match[2]!);
    final patch = int.parse(match[3]!);
    final channel = match[4];
    final sequence = channel == null ? null : int.parse(match[5]!);
    if (major > 65535 || minor > 65535 || patch > 65535) {
      throw FormatException('Release version components must not exceed 65535.');
    }
    if (sequence != null && sequence > 9999) {
      throw FormatException('Release prerelease sequence must not exceed 9999.');
    }

    return ReleaseVersion._(
      major: major,
      minor: minor,
      patch: patch,
      channel: channel,
      sequence: sequence,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final String? channel;
  final int? sequence;

  String get coreVersion => '$major.$minor.$patch';

  String get semanticVersion => isPrerelease
      ? '$coreVersion-$channel.$sequence'
      : coreVersion;

  String get windowsVersion => '$coreVersion.${_windowsBuildNumber()}';

  String get debianVersion => isPrerelease
      ? '$coreVersion~$channel.$sequence'
      : coreVersion;

  bool get isPrerelease => channel != null;

  @override
  int compareTo(ReleaseVersion other) {
    final coreComparison = _compareCore(other);
    if (coreComparison != 0) {
      return coreComparison;
    }

    final channelComparison = _channelRank.compareTo(other._channelRank);
    if (channelComparison != 0) {
      return channelComparison;
    }
    if (!isPrerelease) {
      return 0;
    }
    return sequence!.compareTo(other.sequence!);
  }

  int get _channelRank => switch (channel) {
    'alpha' => 0,
    'beta' => 1,
    'rc' => 2,
    null => 3,
    _ => throw StateError('Unsupported prerelease channel: $channel'),
  };

  int _compareCore(ReleaseVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }
    return patch.compareTo(other.patch);
  }

  int _windowsBuildNumber() => switch (channel) {
    'alpha' => 10000 + sequence!,
    'beta' => 30000 + sequence!,
    'rc' => 50000 + sequence!,
    null => 65535,
    _ => throw StateError('Unsupported prerelease channel: $channel'),
  };
}
