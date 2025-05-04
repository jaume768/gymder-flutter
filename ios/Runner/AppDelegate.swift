import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  
  var window: UIWindow?
  var flutterEngine: FlutterEngine!

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1️⃣ Configura Firebase
    FirebaseApp.configure()

    // 2️⃣ Configura delegado de notificaciones
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // 3️⃣ Solicita permisos y registra APNs
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      if let error = error {
        print("Error solicitando permisos de notificaciones: \(error)")
      }
    }
    application.registerForRemoteNotifications()

    // 4️⃣ Crea y arranca tu propio FlutterEngine
    flutterEngine = FlutterEngine(name: "my_engine")
    flutterEngine.run()

    // 5️⃣ Monta un FlutterViewController con ese engine
    let flutterViewController = FlutterViewController(
      engine: flutterEngine,
      nibName: nil,
      bundle: nil
    )

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = flutterViewController
    window?.makeKeyAndVisible()

    // 6️⃣ Registra todos los plugins contra tu engine
    GeneratedPluginRegistrant.register(with: flutterEngine)

    return true
  }

  // MARK: – APNs token → FCM
  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }

  // MARK: – Mostrar notificación en foreground (iOS 10+)
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }

  // MARK: – Tap en notificación
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Si necesitas procesar payload:
    // let userInfo = response.notification.request.content.userInfo
    completionHandler()
  }
}
