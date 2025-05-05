import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  var flutterEngine: FlutterEngine!

  // MARK: – UIApplicationDelegate
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1️⃣ Configura Firebase
    FirebaseApp.configure()

    // 2️⃣ Configura notificaciones y FCM delegate
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter
      .current()
      .requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
          print("❌ Error solicitando permisos de notificaciones:", error)
        } else {
          print("✅ Permisos de notificaciones:", granted)
        }
      }
    application.registerForRemoteNotifications()
    Messaging.messaging().delegate = self

    // 3️⃣ Arranca tu FlutterEngine
    flutterEngine = FlutterEngine(name: "my_engine")
    flutterEngine.run()

    // 4️⃣ Registra todos los plugins con ese engine
    GeneratedPluginRegistrant.register(with: flutterEngine)

    // 5️⃣ Monta un FlutterViewController
    window = UIWindow(frame: UIScreen.main.bounds)
    let flutterVC = FlutterViewController(
      engine: flutterEngine,
      nibName: nil,
      bundle: nil
    )
    window?.rootViewController = flutterVC
    window?.makeKeyAndVisible()

    return true
  }

  // MARK: – APNs token → FCM
  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }

}

// MARK: – MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("✨ [FirebaseMessaging] FCM registration token: \(fcmToken ?? "nil")")
    // Aquí puedes enviar el token a tu servidor si lo necesitas.
  }
}

// MARK: – UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
  
  // Mostrar notificación en foreground (iOS 10+)
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }

  // Tap en notificación (foreground, background & closed)
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
