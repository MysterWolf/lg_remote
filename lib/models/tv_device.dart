class TvDevice {
  final String name;
  final String ip;

  const TvDevice({required this.name, required this.ip});

  @override
  bool operator ==(Object other) => other is TvDevice && other.ip == ip;

  @override
  int get hashCode => ip.hashCode;

  @override
  String toString() => 'TvDevice($name, $ip)';
}
