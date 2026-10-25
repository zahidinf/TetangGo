class AnnouncementModel {
  final int id;
  final String title;
  final String content;
  final String category; // 'biasa', 'penting', 'darurat'
  final String? imageUrl;
  final bool isPinned;
  final int? authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.imageUrl,
    required this.isPinned,
    this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUrgent => category == 'darurat';
  bool get isImportant => category == 'penting';

  String get categoryDisplay {
    switch (category) {
      case 'darurat':
        return 'Darurat / Mendesak';
      case 'penting':
        return 'Penting';
      case 'biasa':
      default:
        return 'Pengumuman';
    }
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'biasa',
      imageUrl: json['image_url'],
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      authorId: json['author_id'] is int
          ? json['author_id']
          : int.tryParse(json['author_id']?.toString() ?? ''),
      authorName: json['author_name'] ?? 'Pengurus Cluster',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
