import UIKit
import Flutter
import Firebase
import UserNotifications
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  // Plugin de notificaciones locales (para mostrar cuando la app está en foreground)
  private let flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1️⃣ Inicializa Firebase
    FirebaseApp.configure()

    // 2️⃣ Registra el delegate de UNUserNotificationCenter
    UNUserNotificationCenter.current().delegate = self

    // 3️⃣ Solicita permisos de notificación (alert, badge, sound)
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions
    ) { granted, error in
      if let error = error {
        print("Error pidiendo permiso de notificaciones: \(error)")
      }
    }

    // 4️⃣ Registra las notificaciones remotas
    application.registerForRemoteNotifications()

    // 5️⃣ Inicializa el plugin de Flutter
    GeneratedPluginRegistrant.register(with: self)

    // 6️⃣ Opcional: configura el canal local para mostrar notificaciones en foreground
    let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
    UIApplication.shared.registerUserNotificationSettings(settings)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 7️⃣ Captura el device token de APNs y pásalo a FCM
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // 8️⃣ Mostrar la notificación incluso cuando la app está en foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }

  // 9️⃣ Manejar tap sobre la notificación
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    // Procesa aquí tu payload si necesitas navegar o reaccionar
    if let type = userInfo["type"] as? String, type == "new_message" {
      // p.ej. mandar al Flutter side a través de FirebaseMessaging.onMessageOpenedApp
    }

    completionHandler()
  }
}
