class MainNumberModel {
  final String id;
  final String userId;
  final String name;
  final String number;
  final int order;
  final bool isDefault;
  final DateTime createdAt;
  
  MainNumberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.number,
    required this.order,
    this.isDefault = false,
    required this.createdAt,
  });
  
  factory MainNumberModel.fromMap(Map<String, dynamic> map, String id) {
    return MainNumberModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      number: map['number'] as String? ?? '',
      order: map['order'] as int? ?? 0,
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'number': number,
      'order': order,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  MainNumberModel copyWith({
    String? userId,
    String? name,
    String? number,
    int? order,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return MainNumberModel(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      number: number ?? this.number,
      order: order ?? this.order,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
