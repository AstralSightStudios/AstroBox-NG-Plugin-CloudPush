import Foundation
import ObjectiveC.runtime
import Tauri
import UIKit
import UserNotifications
import WebKit

private struct CloudPushRegistrationResult: Encodable, Sendable {
    let platform: String
    let status: String
    let token: String?
    let environment: String?
    let deviceId: String
    let bundleId: String?
    let error: String?
}

private final class InvokeResponder: @unchecked Sendable {
    private let invoke: Invoke

    init(_ invoke: Invoke) {
        self.invoke = invoke
    }

    @MainActor
    func resolve(_ data: CloudPushRegistrationResult) {
        invoke.resolve(data)
    }

    @MainActor
    func reject(_ message: String) {
        invoke.reject(message)
    }
}

private final class ApnsRegistrationBridge: NSObject, @unchecked Sendable {
    static let shared = ApnsRegistrationBridge()

    nonisolated(unsafe) private static var originalDidRegisterIMP: IMP?
    nonisolated(unsafe) private static var originalDidFailIMP: IMP?

    private let tokenKey = "astrobox.apns.deviceToken"
    private let legacyDeviceIdKey = "astrobox.apns.deviceId"
    private let deviceIdKey = "astrobox.cloudPush.deviceId"
    private var delegateHookInstalled = false
    private var pendingResponders: [InvokeResponder] = []

    func requestRegistration(_ responder: InvokeResponder) {
        DispatchQueue.main.async { [weak self] in
            self?.requestRegistrationOnMain(responder)
        }
    }

    private func requestRegistrationOnMain(_ responder: InvokeResponder) {
        guard installDelegateHook() else {
            resolve(
                responder,
                status: "error",
                token: nil,
                error: "UIApplication delegate is not available"
            )
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            if settings.authorizationStatus == .denied {
                self.resolve(responder, status: "denied", token: nil, error: nil)
                return
            }

            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error {
                        self.resolve(
                            responder,
                            status: "error",
                            token: nil,
                            error: error.localizedDescription
                        )
                        return
                    }
                    guard granted else {
                        self.resolve(responder, status: "denied", token: nil, error: nil)
                        return
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.registerForRemoteNotifications(responder)
                    }
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.registerForRemoteNotifications(responder)
            }
        }
    }

    private func registerForRemoteNotifications(_ responder: InvokeResponder) {
        pendingResponders.append(responder)
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func installDelegateHook() -> Bool {
        if delegateHookInstalled {
            return true
        }

        guard let delegate = UIApplication.shared.delegate else {
            return false
        }

        let delegateClass: AnyClass = object_getClass(delegate) ?? type(of: delegate)
        let didRegisterSelector = #selector(
            UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
        )
        let didRegisterBlock: @convention(block) (AnyObject, UIApplication, Data) -> Void = {
            delegate,
            application,
            deviceToken in
            ApnsRegistrationBridge.shared.handleRegisteredDeviceToken(deviceToken)
            if let originalIMP = ApnsRegistrationBridge.originalDidRegisterIMP {
                typealias Original = @convention(c) (AnyObject, Selector, UIApplication, Data) -> Void
                let original = unsafeBitCast(originalIMP, to: Original.self)
                original(delegate, didRegisterSelector, application, deviceToken)
            }
        }
        let didRegisterIMP = imp_implementationWithBlock(didRegisterBlock)
        if let existing = class_getInstanceMethod(delegateClass, didRegisterSelector) {
            ApnsRegistrationBridge.originalDidRegisterIMP = class_replaceMethod(
                delegateClass,
                didRegisterSelector,
                didRegisterIMP,
                method_getTypeEncoding(existing)
            )
        } else {
            class_addMethod(delegateClass, didRegisterSelector, didRegisterIMP, "v@:@@")
        }

        let didFailSelector = #selector(
            UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)
        )
        let didFailBlock: @convention(block) (AnyObject, UIApplication, NSError) -> Void = {
            delegate,
            application,
            error in
            ApnsRegistrationBridge.shared.handleRegistrationFailure(error)
            if let originalIMP = ApnsRegistrationBridge.originalDidFailIMP {
                typealias Original = @convention(c) (AnyObject, Selector, UIApplication, NSError) -> Void
                let original = unsafeBitCast(originalIMP, to: Original.self)
                original(delegate, didFailSelector, application, error)
            }
        }
        let didFailIMP = imp_implementationWithBlock(didFailBlock)
        if let existing = class_getInstanceMethod(delegateClass, didFailSelector) {
            ApnsRegistrationBridge.originalDidFailIMP = class_replaceMethod(
                delegateClass,
                didFailSelector,
                didFailIMP,
                method_getTypeEncoding(existing)
            )
        } else {
            class_addMethod(delegateClass, didFailSelector, didFailIMP, "v@:@@")
        }

        delegateHookInstalled = true
        return true
    }

    private func handleRegisteredDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)

        let responders = pendingResponders
        pendingResponders.removeAll()
        for responder in responders {
            resolve(responder, status: "success", token: token, error: nil)
        }
    }

    private func handleRegistrationFailure(_ error: NSError) {
        let responders = pendingResponders
        pendingResponders.removeAll()
        for responder in responders {
            resolve(responder, status: "error", token: nil, error: error.localizedDescription)
        }
    }

    private func stableDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey),
           !existing.isEmpty
        {
            return existing
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyDeviceIdKey),
           !legacy.isEmpty
        {
            UserDefaults.standard.set(legacy, forKey: deviceIdKey)
            return legacy
        }

        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceIdKey)
        return generated
    }

    private var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private func resolve(
        _ responder: InvokeResponder,
        status: String,
        token: String?,
        error: String?
    ) {
        let result = CloudPushRegistrationResult(
            platform: "ios",
            status: status,
            token: token,
            environment: token == nil ? nil : apnsEnvironment,
            deviceId: stableDeviceId(),
            bundleId: Bundle.main.bundleIdentifier,
            error: error
        )
        Task { @MainActor in
            responder.resolve(result)
        }
    }
}

class CloudPushPlugin: Plugin {
    @objc public func requestRegistration(_ invoke: Invoke) throws {
        ApnsRegistrationBridge.shared.requestRegistration(InvokeResponder(invoke))
    }
}

@_cdecl("init_plugin_cloud_push")
func initPlugin() -> Plugin {
    return CloudPushPlugin()
}
