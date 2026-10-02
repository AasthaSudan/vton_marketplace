enum AuthStatus {
  initial,
  unauthenticated,
  authenticating,
  authenticated,
  guest,
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String memberTier;
  final bool isGuest;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.memberTier = 'Clothsy Member',
    this.isGuest = false,
  });

  static const guest = User(
    id: 'guest',
    name: 'Guest Shopper',
    email: '',
    phone: '',
    memberTier: 'Guest',
    isGuest: true,
  );

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? memberTier,
    bool? isGuest,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      memberTier: memberTier ?? this.memberTier,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
