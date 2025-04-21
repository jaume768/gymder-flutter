import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
// Importa el paquete record, que ahora expone la clase AudioRecorder en lugar de Record.
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../widgets/audio_bubble.dart';
import '../services/socket_service.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as p;
import 'package:chewie/chewie.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String matchedUserId;

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    required this.matchedUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  // Cambiado: se usa AudioRecorder (clase concreta) en lugar de Record (abstracta)
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  SocketService? _socketService;
  List<Message> messages = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreMessages = true;
  bool isTyping = false;
  bool isRecording = false;
  String recordingPath = '';
  Timer? typingTimer;
  Timer? typingIndicatorTimer;
  User? matchedUser;
  int currentPage = 0;
  int pageSize = 20;
  String? typingUserId;
  bool isOnline = false;
  String apiUrl = 'https://gymder-api-production.up.railway.app/api';

  Dio _dio = Dio();
  VideoPlayerController? _videoController;
  double videoUploadProgress = 0.0;
  bool isVideoUploading = false;

  // Format Duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSocket();
    _loadMatchedUserInfo();
    _loadMessages();

    // Agrega listener para paginación
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (!isLoadingMore && hasMoreMessages) {
          _loadMoreMessages();
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    // Desconectar socket al salir de la pantalla
    if (_socketService != null) {
      _socketService!.disconnect();
      _socketService = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconecta el socket si es necesario
      if (_socketService == null || _socketService!.isDisconnected) {
        _initSocket();
      }
      // Marca los mensajes como leídos al reanudar la app
      _markMessagesAsRead();
    }
  }

  void _initSocket() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await authProvider.getToken();

    _socketService = SocketService(
      'https://gymder-api-production.up.railway.app',
      token!,
      widget.currentUserId,
      widget.matchedUserId,
    );

    _socketService!.connect();

    _socketService!.onConnect(() {
      print('Connected to socket server');
    });

    _socketService!.onReceiveMessage((data) {
      final newMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: data['senderId'],
        message: data['message'] ?? '',
        type: data['type'] ?? 'text',
        imageUrl: data['imageUrl'] ?? '',
        audioUrl: data['audioUrl'] ?? '',
        audioDuration: data['audioDuration'] != null
          ? (data['audioDuration'] is int
              ? data['audioDuration'].toDouble()
              : data['audioDuration']) 
          : 0.0,
        videoUrl: data['videoUrl'] ?? '',
        videoDuration: data['videoDuration'] != null
          ? (data['videoDuration'] is int
              ? data['videoDuration'].toDouble()
              : data['videoDuration'])
          : 0.0,
        createdAt: DateTime.parse(data['timestamp']),
        seenAt: null,
      );

      if (mounted) {
        setState(() {
          messages.insert(0, newMessage);
        });

        // Marca el mensaje como leído si es del usuario emparejado
        if (newMessage.senderId == widget.matchedUserId) {
          _markMessagesAsRead();
        }
      }
    });

    _socketService!.onMessagesMarkedAsRead((data) {
      if (data['userId'] == widget.matchedUserId && mounted) {
        setState(() {
          for (var i = 0; i < messages.length; i++) {
            if (messages[i].senderId == widget.currentUserId &&
                messages[i].seenAt == null) {
              messages[i] = messages[i].copyWith(seenAt: DateTime.now());
            }
          }
        });
      }
    });

    _socketService!.onUserTyping((data) {
      if (data['userId'] == widget.matchedUserId && mounted) {
        setState(() {
          isTyping = true;
        });
      }
    });

    _socketService!.onUserStoppedTyping((data) {
      if (data['userId'] == widget.matchedUserId && mounted) {
        setState(() {
          isTyping = false;
        });
      }
    });

    _socketService!.onUserOnline((data) {
      if (data['userId'] == widget.matchedUserId && mounted) {
        setState(() { isOnline = true; });
      }
    });

    _socketService!.onUserOffline((data) {
      if (data['userId'] == widget.matchedUserId && mounted) {
        setState(() { isOnline = false; });
      }
    });

    _socketService!
        .onDisconnect(() => print('Disconnected from socket server'));
    _socketService!.onError((error) => print('Socket error: $error'));
  }

  Future<void> _loadMatchedUserInfo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      // Use the getUserProfile endpoint instead of the generic users endpoint
      final response = await http.get(
        Uri.parse('$apiUrl/users/profile/${widget.matchedUserId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token!}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Response: ${response.body}');
        
        if (data['user'] != null) {
          setState(() {
            matchedUser = User.fromJson(data['user']);
          });
          print('Matched user loaded: ${matchedUser?.username}');
          print('Profile picture URL: ${matchedUser?.profilePicture?.url}');
        } else {
          print('Error: User data not found in response');
          print('Response data: $data');
        }
      } else {
        print('Error loading matched user: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error loading matched user info: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      final response = await http.get(
        Uri.parse(
            '$apiUrl/messages/conversation?user1=${widget.currentUserId}&user2=${widget.matchedUserId}&limit=$pageSize&skip=${currentPage * pageSize}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token!}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List<dynamic> messageData = data['messages'];
          final List<Message> loadedMessages =
              messageData.map((msg) => Message.fromJson(msg)).toList();

          setState(() {
            messages = loadedMessages;
            isLoading = false;
            hasMoreMessages = loadedMessages.length >= pageSize;
          });

          // Marca los mensajes como leídos
          _markMessagesAsRead();
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading messages: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (isLoadingMore || !hasMoreMessages) return;

    try {
      setState(() {
        isLoadingMore = true;
        currentPage++;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();

      final response = await http.get(
        Uri.parse(
            '$apiUrl/messages/conversation?user1=${widget.currentUserId}&user2=${widget.matchedUserId}&limit=$pageSize&skip=${currentPage * pageSize}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token!}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List<dynamic> messageData = data['messages'];
          final List<Message> loadedMessages =
              messageData.map((msg) => Message.fromJson(msg)).toList();

          setState(() {
            messages.addAll(loadedMessages);
            isLoadingMore = false;
            hasMoreMessages = loadedMessages.length >= pageSize;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoadingMore = false;
      });
      print('Error loading more messages: $e');
    }
  }

  void _markMessagesAsRead() {
    final hasUnreadMessages = messages.any(
      (msg) => msg.senderId == widget.matchedUserId && msg.seenAt == null,
    );

    if (hasUnreadMessages &&
        _socketService != null &&
        _socketService!.isConnected) {
      _socketService!.markAsRead();
    }
  }

  void _sendMessage(String message,
      {String type = 'text',
      String? imageUrl,
      String? audioUrl,
      double? audioDuration,
      String? videoUrl,
      double? videoDuration}) {
    if ((type == 'text' && message.trim().isEmpty) ||
        (type == 'image' && (imageUrl == null || imageUrl.isEmpty)) ||
        (type == 'audio' && (audioUrl == null || audioUrl.isEmpty)) ||
        (type == 'video' && (videoUrl == null || videoUrl.isEmpty))) {
      return;
    }

    if (_socketService != null && _socketService!.isConnected) {
      _socketService!.sendMessage(
        message,
        type: type,
        imageUrl: imageUrl ?? '',
        audioUrl: audioUrl ?? '',
        audioDuration: audioDuration ?? 0,
        videoUrl: videoUrl ?? '',
        videoDuration: videoDuration ?? 0,
      );
    }

    if (type == 'text') {
      _messageController.clear();
    }
  }

  void _onTyping() {
    typingTimer?.cancel();

    if (_socketService != null && _socketService!.isConnected) {
      _socketService!.userTyping();
    }

    typingTimer = Timer(const Duration(seconds: 2), () {
      if (_socketService != null && _socketService!.isConnected) {
        _socketService!.userStoppedTyping();
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Vista previa', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(File(image.path), height: 200),
                  const SizedBox(height: 20),
                  const Text('¿Enviar esta imagen?', style: TextStyle(color: Colors.white70)),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancelar', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: Text('Enviar', style: TextStyle(color: Colors.blue)),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    try {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final token = await authProvider.getToken();
                      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/messages/upload'));
                      request.headers.addAll({'Authorization': 'Bearer ${token!}'});
                      final mimeType = 'image/${image.path.split('.').last.toLowerCase()}';
                      request.files.add(await http.MultipartFile.fromPath(
                        'chatImage',
                        image.path,
                        contentType: MediaType.parse(mimeType),
                      ));
                      var response = await request.send();
                      var responseData = await response.stream.bytesToString();
                      var data = jsonDecode(responseData);
                      if (data['success'] == true) {
                        _sendMessage('', type: 'image', imageUrl: data['url']);
                      } else {
                        throw Exception('Error en la respuesta del servidor: ${data['message'] ?? 'Error desconocido'}');
                      }
                    } catch (e) {
                      print('Error uploading image: ${e}');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar la imagen: ${e}')));
                    }
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error picking image: ${e}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar la imagen: ${e}')));
    }
  }

  Future<void> _pickVideo() async {
    final BuildContext rootScaffoldContext = context;
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (video == null) return;
      final file = File(video.path);
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      final double durationSec = _videoController!.value.duration.inSeconds.toDouble();
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Text('Vista previa de video', style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _videoController!,
                      builder: (context, value, child) {
                        final position = value.position;
                        final duration = value.duration;
                        return Column(
                          children: [
                            VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                Text('-${_formatDuration(duration - position)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    if (isVideoUploading)
                      LinearProgressIndicator(value: videoUploadProgress)
                    else
                      const Text('¿Enviar este video?', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  TextButton(
                    child: const Text('Enviar', style: TextStyle(color: Colors.blue)),
                    onPressed: () async {
                      setState(() { isVideoUploading = true; });
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final token = await authProvider.getToken();
                      final fileName = p.basename(video.path);
                      final fileExt = fileName.split('.').last.toLowerCase();
                      // Set correct contentType for video file
                      FormData formData = FormData.fromMap({
                        'chatVideo': await MultipartFile.fromFile(
                          video.path,
                          filename: fileName,
                          contentType: MediaType('video', fileExt),
                        ),
                        'duration': durationSec.toString(),
                      });
                      _dio.options.headers['Authorization'] = 'Bearer $token';
                      try {
                        final resp = await _dio.post(
                          '$apiUrl/messages/upload-video',
                          data: formData,
                          onSendProgress: (count, total) {
                            if (dialogContext.mounted) setDialogState(() { videoUploadProgress = count/total; });
                          },
                        );
                        final data = resp.data;
                        if (data['success']) {
                          _sendMessage(
                            '',
                            type: 'video',
                            videoUrl: data['url'],
                            videoDuration: (data['duration'] is num ? (data['duration'] as num).toDouble() : double.tryParse(data['duration'].toString()) ?? 0.0),
                          );
                          Navigator.of(dialogContext).pop();
                        } else {
                          throw Exception(data['message']);
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(rootScaffoldContext).showSnackBar(SnackBar(content: Text('Error al enviar video: $e')));
                        Navigator.of(dialogContext).pop();
                      } finally {
                        setState(() { isVideoUploading = false; videoUploadProgress = 0.0; });
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(rootScaffoldContext).showSnackBar(SnackBar(content: Text('Error al seleccionar el video: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug information for profile picture
    if (matchedUser != null) {
      print('Building chat screen with matched user: ${matchedUser!.username}');
      print('Has profile picture: ${matchedUser!.profilePicture != null}');
      if (matchedUser!.profilePicture != null) {
        print('Profile picture URL: ${matchedUser!.profilePicture!.url}');
        print('URL is empty: ${matchedUser!.profilePicture!.url.isEmpty}');
      }
    } else {
      print('Matched user is null in build method');
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[800],
              backgroundImage: (matchedUser?.profilePicture != null &&
                      matchedUser!.profilePicture!.url.isNotEmpty)
                  ? CachedNetworkImageProvider(
                      matchedUser!.profilePicture!.url,
                    ) as ImageProvider
                  : null,
              child: (matchedUser?.profilePicture == null ||
                      matchedUser!.profilePicture!.url.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  matchedUser?.username ?? tr("loading"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (typingUserId == widget.matchedUserId)
                  Text(
                    tr("typing"),
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  )
                else if (isOnline)
                  Text(
                    'Online',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: messages.length +
                            (isLoadingMore ? 1 : 0) +
                            (hasMoreMessages ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && isLoadingMore) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (index == messages.length &&
                              hasMoreMessages &&
                              !isLoadingMore) {
                            return Center(
                              child: TextButton(
                                onPressed: _loadMoreMessages,
                                child: Text(tr("load_more_messages")),
                              ),
                            );
                          }

                          final message = messages[index];
                          final isMe = message.senderId == widget.currentUserId;

                          return _buildMessageBubble(message, isMe);
                        },
                      ),
                      if (isLoading && messages.isNotEmpty)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              backgroundImage: (matchedUser?.profilePicture != null &&
                      matchedUser!.profilePicture!.url.isNotEmpty)
                  ? CachedNetworkImageProvider(
                      matchedUser!.profilePicture!.url,
                    ) as ImageProvider
                  : null,
              child: (matchedUser?.profilePicture == null ||
                      matchedUser!.profilePicture!.url.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[700] : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == 'text')
                    Text(
                      message.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  else if (message.type == 'image')
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme:
                                    const IconThemeData(color: Colors.white),
                              ),
                              body: Center(
                                child: InteractiveViewer(
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  child: CachedNetworkImage(
                                    imageUrl: message.imageUrl,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                      Icons.error,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: message.imageUrl,
                          placeholder: (context, url) => const SizedBox(
                            height: 150,
                            width: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => const SizedBox(
                            height: 150,
                            width: 200,
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                          height: 150,
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (message.type == 'audio')
                    AudioBubble(
                      audioUrl: message.audioUrl,
                      duration: message.audioDuration,
                      isMe: isMe,
                    )
                  else if (message.type == 'video')
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme:
                                    const IconThemeData(color: Colors.white),
                              ),
                              body: Center(
                                child: VideoViewer(url: message.videoUrl),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 150,
                          width: 200,
                          color: Colors.black54,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 64,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.seenAt != null ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.seenAt != null
                              ? Colors.blue[300]
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.white),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: _pickVideo,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _onTyping(),
              decoration: InputDecoration(
                hintText: tr("type_a_message"),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoViewer extends StatefulWidget {
  final String url;
  const VideoViewer({Key? key, required this.url}) : super(key: key);
  @override
  _VideoViewerState createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late VideoPlayerController _controller;
  late ChewieController _chewieController;
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url);
    _controller.initialize().then((_) {
      // After initialization, setup Chewie
      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        showControls: true,
      );
      setState(() {});
    });
  }
  @override
  void dispose() {
    _chewieController.dispose();
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // Use Chewie for playback when ready
    return (_controller.value.isInitialized && _chewieController != null)
      ? Chewie(controller: _chewieController)
      : const Center(child: CircularProgressIndicator());
  }
}
