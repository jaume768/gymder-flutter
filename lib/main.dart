// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'package:app/providers/auth_provider.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/screens/chat_screen.dart';

// 1) Define los canales (deben coincidir con AndroidManifest)
const AndroidNotificationChannel likesChannel = AndroidNotificationChannel(
  'likes_channel', // id
  'Notificaciones de Likes', // titulo
  description: 'Canal para nuevos likes',
  importance: Importance.high,
);

const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
  'chat_channel', // id
  'Notificaciones de Chat', // titulo
  description: 'Canal para nuevos mensajes de chat',
  importance: Importance.high,
);

// 2) Plugin de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 3) Handler para mensajes en background / terminated
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🛰️ FCM en background: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase
  await Firebase.initializeApp();

  // Inicializa easy_localization
  await EasyLocalization.ensureInitialized();

  // Crea los canales Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(likesChannel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(chatChannel);

  // Presentación en foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Registra handler para background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('es'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 4) Mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final data = msg.data;
      // Si es un mensaje de chat, no disparamos nada en foreground:
      if (data['type'] == 'new_message') return;

      final notification = msg.notification;
      final android = msg.notification?.android;
      if (notification != null && android != null) {
        // resto de tu código para mostrar likes u otros tipos
        final isChat = data['type'] == 'new_message';
        final channel = isChat ? chatChannel : likesChannel;
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    // 5) Taps sobre la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      final data = msg.data;
      if (data['type'] == 'new_like') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUserId: data['toUserId'],
            matchedUserId: data['fromUserId'],
          ),
        ));
      } else if (data['type'] == 'new_message') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUserId: data['toUserId'],
            matchedUserId: data['senderId'] ?? data['fromUserId'],
          ),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gymder',
      theme: ThemeData.dark(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
    );
  }
}
