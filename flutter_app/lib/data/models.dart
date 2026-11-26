class AppUser {
  final int id;
  final String name;
  final String email;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  factory AppUser.fromRow(Map<String, Object?> r) => AppUser(
        id: r['id'] as int,
        name: r['name'] as String,
        email: r['email'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class HomeStats {
  final int shipments;
  final int savedPlans;
  final int reports;
  const HomeStats(this.shipments, this.savedPlans, this.reports);
  static const empty = HomeStats(0, 0, 0);
}
