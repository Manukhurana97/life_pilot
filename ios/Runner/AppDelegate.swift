import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private let bgTaskId = "com.mk.life_pilot.reschedule";

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register BGTaskScheduler for daily notification reschedule
    if #available(iOS 13.0, *) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskId, using: nil) { task in
            self.handleBGTask(task: task as! BGProcessingTask)
        }
    }

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Schedule the first background task
    if #available(iOS 13.0, *) {
        scheduleBGTask()
    }

    // Set up platform channel for Dart to request scheduling
    if let controller = window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(name: "com.mk.life_pilot/bg_task", binaryMessenger: controller.binaryMessenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "scheduleBGTask" {
                if #available(iOS 13.0, *) {
                    self?.scheduleBGTask()
                    result(true)
                } else {
                    result(false)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Schedule a BGProcessingTask to run overnight (iOS picks the best time)
  @available(iOS 13.0, *)
  private func scheduleBGTask() {
    let request = BGProcessingTaskRequest(identifier: bgTaskId)
    // Ask iOS to run it no earlier then 4 hours from now
    request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false

    do {
        try BGTaskScheduler.shared.submit(request)
         NSLog("[DayPilot] BGTask scheduled for ~4h from now");
    } catch {
        NSLog("[DayPilot] BGTask schedule failed: \(error)")
    }
  }

  // Handle the background task: start Flutter engine and trigger rescheduling
  @available(iOS 13.0, *)
  private func handleBGTask(task: BGProcessingTask) {
    NSLog("[BayPilot] BGTask firing - rescheduling notifications")

    // Schedule the next occurrence before doing work
    scheduleBGTask()

    // Set expiration handler
    task.expirationHandler = {
        NSLog("[DayPilot] BGTask expired before completion")
        task.setTaskCompleted(success: false)
    }

    // Start the Flutter engine to trigger rescheduling
    // The flutter engine initialization will call loadTasks() -> reschedulingAllTask()
    if let engine = (UIApplication.shared.delegate as? FlutterAppDelegate)?.flutterEngine {
        let channel = FlutterMethodChannel(name: "com.mk.life_pilot/bg_task", binaryMessenger: engine.binaryMessenger)
        channel.invokeMethod("rescheduleFromBackground", argument: nil) { result in
            NSLog("[DayPilot] BGTask reschedule result: \(String(describing: result))")
             task.setTaskCompleted(success: true)
        }
    } else {
        NSLog("[DayPilot] BGTask: no Flutter engine available, completing")
        task.setTaskCompleted(success: true)
    }
  }
}
