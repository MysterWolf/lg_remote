class SavedTv {
  final String ip;
  final String name;
  final DateTime lastSeen;

  const SavedTv({
    required this.ip,
    required this.name,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'name': name,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory SavedTv.fromJson(Map<String, dynamic> json) => SavedTv(
        ip: json['ip'] as String,
        name: json['name'] as String,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
      );

  SavedTv copyWith({String? name, DateTime? lastSeen}) => SavedTv(
        ip: ip,
        name: name ?? this.name,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
