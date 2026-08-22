class LabNote {
  const LabNote({
    required this.id,
    required this.title,
    required this.owner,
    this.isOptimistic = false,
  });

  final String id;
  final String title;
  final String owner;
  final bool isOptimistic;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'owner': owner,
    'isOptimistic': isOptimistic,
  };

  static LabNote fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final owner = json['owner'];
    final isOptimistic = json['isOptimistic'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.isEmpty ||
        owner is! String ||
        owner.isEmpty ||
        (isOptimistic != null && isOptimistic is! bool)) {
      throw const FormatException('Invalid persisted lab note');
    }
    return LabNote(
      id: id,
      title: title,
      owner: owner,
      isOptimistic: isOptimistic as bool? ?? false,
    );
  }
}
