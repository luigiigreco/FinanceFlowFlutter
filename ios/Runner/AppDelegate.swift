import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Registra i plugin generati automaticamente
    GeneratedPluginRegistrant.register(with: self)

    // Richiedi autorizzazioni per le notifiche
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        if granted {
            print("Notifiche autorizzate")
        } else {
            print("Notifiche non autorizzate: \(String(describing: error))")
        }
    }

    // Registra le notifiche remote
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Metodo chiamato quando viene ricevuta una notifica in primo piano
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Verifica la versione di iOS
    if #available(iOS 14.0, *) {
      // Mostra la notifica anche in primo piano con il banner
      completionHandler([.banner, .sound])
    } else {
      // Fallback per versioni di iOS precedenti
      completionHandler([.alert, .sound])
    }
  }
}
