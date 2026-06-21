//
//  Constants.swift
//  iMonet
//
//  Created by 李旭 on 2024/9/11.
//

import Foundation

enum Constants {
    /// The marketing version (e.g. "1.1.1").
    static let appVersion = Bundle.main.versionString!

    /// The build version (e.g. "20260606.1841").
    static let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

    /// The bundle identifier of the app.
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    // swiftlint:enable force_unwrapping

    /// The identifier for the settings window.
    static let settingsWindowID = "SettingsWindow"

    /// The identifier for the permissions window.
    static let permissionsWindowID = "PermissionsWindow"

    static let dirBookmarkDataKey = "PICASA_DIRS"

    /// Supported image file extensions.
    static let supportedImageExtensions = ["png", "jpg", "jpeg", "gif", "webp"]
}
