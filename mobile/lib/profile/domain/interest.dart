class Interest {
  const Interest({required this.id, required this.name, required this.category});

  factory Interest.fromJson(Map<String, dynamic> json) => Interest(
    id: json['id'] as int,
    name: json['name'] as String,
    category: json['category'] as String?,
  );

  final int id;
  final String name;
  final String? category;
}
