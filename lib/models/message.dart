class Message {
  final String id;
  final String senderId;
  final String message;
  final String type;
  final String imageUrl;
  final String audioUrl;
  final String videoUrl;
  final double audioDuration;
  final double videoDuration;
  final DateTime createdAt;
  final DateTime? seenAt;

  Message({
    required this.id,
    required this.senderId,
    required this.message,
    required this.type,
    required this.imageUrl,
    required this.audioUrl,
    required this.videoUrl,
    required this.audioDuration,
    required this.videoDuration,
    required this.createdAt,
    this.seenAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? '',
      senderId: json['sender'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'text',
      imageUrl: json['imageUrl'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      audioDuration: json['audioDuration']?.toDouble() ?? 0.0,
      videoDuration: json['videoDuration']?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      seenAt: json['seenAt'] != null 
          ? DateTime.parse(json['seenAt']) 
          : null,
    );
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? message,
    String? type,
    String? imageUrl,
    String? audioUrl,
    double? audioDuration,
    String? videoUrl,
    double? videoDuration,
    DateTime? createdAt,
    DateTime? seenAt,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      videoDuration: videoDuration ?? this.videoDuration,
      createdAt: createdAt ?? this.createdAt,
      seenAt: seenAt ?? this.seenAt,
    );
  }
}
