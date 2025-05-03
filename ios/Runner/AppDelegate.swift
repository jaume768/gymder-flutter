import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1️⃣ Configura Firebase
    FirebaseApp.configure()
    
    // 2️⃣ Delegado de notificaciones (iOS 10+)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // 3️⃣ Pide permiso de notificaciones (alert, badge, sound)
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      if let error = error {
        print("Error al solicitar permisos de notificaciones: \(error)")
      }
    }
    
    // 4️⃣ Registra APNs para notificaciones remotas
    application.registerForRemoteNotifications()
    
    // 5️⃣ Registra todos los plugins de Flutter
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // 6️⃣ APNs device token → FCM
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // 7️⃣ Mostrar notificación en foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }
  
  // 8️⃣ Responder al tap en notificación
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    // Aquí puedes procesar userInfo["type"], etc., y comunicarte con Flutter si lo necesitas.
    
    completionHandler()
  }
}
