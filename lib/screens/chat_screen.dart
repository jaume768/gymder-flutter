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
  String apiUrl = 'https://gymder-api-production.up.railway.app/api';

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
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _socketService?.disconnect();
    typingTimer?.cancel();
    typingIndicatorTimer?.cancel();
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
        createdAt: DateTime.parse(data['timestamp']),
        seenAt: null,
      );

      setState(() {
        messages.insert(0, newMessage);
      });

      // Marca el mensaje como leído si es del usuario emparejado
      if (newMessage.senderId == widget.matchedUserId) {
        _markMessagesAsRead();
      }
    });

    _socketService!.onMessagesMarkedAsRead((data) {
      if (data['userId'] == widget.matchedUserId) {
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
      if (data['userId'] == widget.matchedUserId) {
        setState(() {
          typingUserId = data['userId'];
        });

        // Limpia el indicador de "escribiendo" después de 3 segundos
        typingIndicatorTimer?.cancel();
        typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              typingUserId = null;
            });
          }
        });
      }
    });

    _socketService!.onUserStoppedTyping((data) {
      if (data['userId'] == widget.matchedUserId) {
        setState(() {
          typingUserId = null;
        });
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
      double? audioDuration}) {
    if ((type == 'text' && message.trim().isEmpty) ||
        (type == 'image' && (imageUrl == null || imageUrl.isEmpty)) ||
        (type == 'audio' && (audioUrl == null || audioUrl.isEmpty))) {
      return;
    }

    if (_socketService != null && _socketService!.isConnected) {
      _socketService!.sendMessage(
        message,
        type: type,
        imageUrl: imageUrl ?? '',
        audioUrl: audioUrl ?? '',
        audioDuration: audioDuration ?? 0,
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
        imageQuality: 70, // Comprimir la imagen
      );

      if (image != null) {
        setState(() {
          isLoading = true;
        });

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final token = await authProvider.getToken();

        // Obtener la extensión del archivo
        final String extension = image.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          setState(() {
            isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Solo se permiten archivos JPG, JPEG y PNG')),
            );
          }
          return;
        }

        // Mostrar una vista previa de la imagen seleccionada
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
                    SizedBox(height: 20),
                    isLoading 
                      ? CircularProgressIndicator() 
                      : Text('¿Enviar esta imagen?', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('Cancelar', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      setState(() {
                        isLoading = false;
                      });
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  TextButton(
                    child: Text('Enviar', style: TextStyle(color: Colors.blue)),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      
                      try {
                        var request = http.MultipartRequest(
                            'POST', Uri.parse('$apiUrl/messages/upload'));

                        request.headers.addAll({
                          'Authorization': 'Bearer ${token!}',
                        });

                        // Asegurarse de que el tipo MIME sea correcto
                        final mimeType = 'image/${extension == 'jpg' ? 'jpeg' : extension}';
                        
                        request.files.add(await http.MultipartFile.fromPath(
                          'chatImage',
                          image.path,
                          contentType: MediaType.parse(mimeType),
                        ));

                        var response = await request.send();
                        var responseData = await response.stream.bytesToString();
                        var data = jsonDecode(responseData);

                        setState(() {
                          isLoading = false;
                        });

                        if (data['success'] == true) {
                          _sendMessage('', type: 'image', imageUrl: data['url']);
                        } else {
                          throw Exception('Error en la respuesta del servidor: ${data['message'] ?? 'Error desconocido'}');
                        }
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                        });
                        print('Error uploading image: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al enviar la imagen: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar la imagen: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      // Solicitar permiso de micrófono
      if (await Permission.microphone.request().isGranted) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Inicia la grabación utilizando el nuevo RecordConfig
        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          isRecording = true;
          recordingPath = path;
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar la grabación: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!isRecording) return;

      // Detiene la grabación y obtiene la ruta del archivo
      final path = await _audioRecorder.stop();

      setState(() {
        isRecording = false;
      });

      if (path != null) {
        // Mostrar una vista previa del audio grabado
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  bool isPreviewPlaying = false;
                  bool isPreviewLoading = true;
                  double audioDuration = 0.0;
                  
                  // Obtener la duración del audio
                  _getAudioDuration(path).then((duration) {
                    setDialogState(() {
                      audioDuration = duration;
                      isPreviewLoading = false;
                    });
                  });
                  
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: Text('Vista previa de audio', style: TextStyle(color: Colors.white)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isPreviewLoading 
                          ? CircularProgressIndicator() 
                          : Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isPreviewPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {
                                    if (isPreviewPlaying) {
                                      await _audioPlayer.pause();
                                    } else {
                                      await _audioPlayer.play(DeviceFileSource(path));
                                    }
                                    setDialogState(() {
                                      isPreviewPlaying = !isPreviewPlaying;
                                    });
                                  },
                                ),
                                Text(
                                  '${(audioDuration / 1000).toStringAsFixed(1)}s', 
                                  style: TextStyle(color: Colors.white)
                                ),
                              ],
                            ),
                        SizedBox(height: 20),
                        Text('¿Enviar este audio?', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        child: Text('Cancelar', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          _audioPlayer.stop();
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                      TextButton(
                        child: Text('Enviar', style: TextStyle(color: Colors.blue)),
                        onPressed: () async {
                          _audioPlayer.stop();
                          Navigator.of(dialogContext).pop();
                          
                          setState(() {
                            isLoading = true;
                          });
                          
                          try {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final token = await authProvider.getToken();

                            final file = File(path);
                            final fileExists = await file.exists();
                            if (!fileExists) {
                              setState(() {
                                isLoading = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('El archivo de audio no existe')),
                                );
                              }
                              return;
                            }

                            var request = http.MultipartRequest(
                                'POST', Uri.parse('$apiUrl/messages/upload-audio'));

                            request.headers.addAll({
                              'Authorization': 'Bearer ${token!}',
                            });

                            // Asegurarse de que el tipo MIME sea correcto
                            request.files.add(await http.MultipartFile.fromPath(
                              'chatAudio',
                              path,
                              contentType: MediaType.parse('audio/aac'),
                            ));

                            request.fields['duration'] = audioDuration.toString();

                            var response = await request.send();
                            var responseData = await response.stream.bytesToString();
                            var data = jsonDecode(responseData);

                            setState(() {
                              isLoading = false;
                            });

                            if (data['success'] == true) {
                              _sendMessage('',
                                  type: 'audio',
                                  audioUrl: data['url'],
                                  audioDuration: double.parse(data['duration'].toString()));
                            } else {
                              throw Exception('Error en la respuesta del servidor: ${data['message'] ?? 'Error desconocido'}');
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                            });
                            print('Error uploading audio: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al enviar el audio: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isRecording = false;
      });
      print('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al detener la grabación: $e')),
        );
      }
    }
  }

  Future<double> _getAudioDuration(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return 0.0;
      }
      
      final FlutterSoundPlayer player = FlutterSoundPlayer();
      await player.openPlayer();
      await player.setSubscriptionDuration(const Duration(milliseconds: 100));

      final duration = await player.startPlayer(fromURI: path);
      await player.stopPlayer();
      await player.closePlayer();

      return duration?.inMilliseconds.toDouble() ?? 0.0;
    } catch (e) {
      print('Error getting audio duration: $e');
      return 0.0;
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
            onLongPress: _startRecording,
            onLongPressEnd: (_) => _stopRecording(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isRecording ? Colors.red : Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
