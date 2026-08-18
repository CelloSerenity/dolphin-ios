// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

@objc class GameLaunchLinkManager: NSObject {
  @objc static let shared = GameLaunchLinkManager()
  @objc static let launchRequestedNotification = "DOLGameLaunchRequestedNotification"

  @objc private(set) var pendingGamePath: String?

  @objc func launchURL(forGamePath gamePath: String) -> URL? {
    let softwareURL = URL(fileURLWithPath: UserFolderUtil.getSoftwareFolder(), isDirectory: true).standardizedFileURL
    let gameURL = URL(fileURLWithPath: gamePath).standardizedFileURL
    let softwarePrefix = softwareURL.path.hasSuffix("/") ? softwareURL.path : softwareURL.path + "/"

    guard gameURL.path.hasPrefix(softwarePrefix) else { return nil }

    let relativePath = String(gameURL.path.dropFirst(softwarePrefix.count))
    guard !relativePath.isEmpty else { return nil }

    var components = URLComponents()
    components.scheme = "dolphinios"
    components.host = "launch"
    components.queryItems = [URLQueryItem(name: "path", value: relativePath)]
    guard let launchURL = components.url else { return nil }

    guard StikJITManager.shared.isRunningInLiveContainer else { return launchURL }

    var liveContainerComponents = URLComponents()
    liveContainerComponents.scheme = "livecontainer"
    liveContainerComponents.host = "open-web-page"
    let encodedLaunchURL = Data(launchURL.absoluteString.utf8).base64EncodedString()
    liveContainerComponents.percentEncodedQuery = "url=\(encodedLaunchURL)"
    return liveContainerComponents.url
  }

  func handle(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "dolphinios",
          url.host?.lowercased() == "launch",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let relativePath = components.queryItems?.first(where: { $0.name == "path" })?.value,
          !relativePath.isEmpty else {
      return false
    }

    let softwareURL = URL(fileURLWithPath: UserFolderUtil.getSoftwareFolder(), isDirectory: true).standardizedFileURL
    let gameURL = softwareURL.appendingPathComponent(relativePath).standardizedFileURL
    let softwarePrefix = softwareURL.path.hasSuffix("/") ? softwareURL.path : softwareURL.path + "/"

    guard gameURL.path.hasPrefix(softwarePrefix) else { return false }

    pendingGamePath = gameURL.path

    DispatchQueue.main.async {
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
      let window = windowScene?.windows.first(where: \.isKeyWindow) ?? windowScene?.windows.first
      (window?.rootViewController as? UITabBarController)?.selectedIndex = 0
      NotificationCenter.default.post(name: Notification.Name(Self.launchRequestedNotification), object: nil)
    }

    return true
  }

  @objc func clearPendingGamePath(_ gamePath: String) {
    if pendingGamePath == gamePath {
      pendingGamePath = nil
    }
  }
}

class AppDelegate : UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    ServiceManager.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func applicationWillTerminate(_ application: UIApplication) {
    ServiceManager.shared.applicationWillTerminate()
  }
  
  func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    ServiceManager.shared.applicationDidReceiveMemoryWarning()
  }
  
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if GameLaunchLinkManager.shared.handle(url) {
      return true
    }
    return ServiceManager.shared.open(url: url, options: options)
  }
  
  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
  
  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    //
  }
}
