class DirectoryItem {
  const DirectoryItem({
    required this.id,
    required this.name,
    required this.description,
    this.departmentId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String description;
  final String? departmentId;
  final bool isActive;

  factory DirectoryItem.fromMap(String id, Map<String, dynamic> map) {
    return DirectoryItem(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      departmentId: map['departmentId'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (departmentId != null) 'departmentId': departmentId,
      'isActive': isActive,
    };
  }
}
