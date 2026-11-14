class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    this.memberNumber = '',
    this.memberSince = 2026,
  });

  final String name;
  final String email;
  final String phone;

  /// A media reference: `asset:people/x.png` for a bundled picture,
  /// `file:media/x.jpg` for one the person chose, or empty for none (the
  /// initial shows instead). Never image bytes.
  final String avatar;

  /// The number on the supporter card.
  final String memberNumber;
  final int memberSince;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatar,
  }) => UserProfile(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    avatar: avatar ?? this.avatar,
    memberNumber: memberNumber,
    memberSince: memberSince,
  );

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String,
    email: j['email'] as String,
    phone: j['phone'] as String? ?? '',
    avatar: j['avatar'] as String? ?? '',
    memberNumber: j['memberNumber'] as String? ?? '',
    memberSince: j['memberSince'] as int? ?? 2026,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'avatar': avatar,
    'memberNumber': memberNumber,
    'memberSince': memberSince,
  };
}
