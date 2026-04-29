#!/usr/bin/env swift
//
// Generates LogWeight app icons (iOS + iPad + watch) into Asset Catalogs.
// Run from repo root:  swift Tools/GenerateAppIcons.swift
//
// Requires macOS + AppKit (no extra packages).

import AppKit
import Foundation

// MARK: - Drawing

private func drawIcon(pixelSize: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: pixelSize, height: pixelSize), flipped: false) { rect in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // Brighter teal gradient (still calm) so white artwork reads clearly.
        let c1 = NSColor(red: 0.16, green: 0.34, blue: 0.38, alpha: 1)
        let c2 = NSColor(red: 0.08, green: 0.20, blue: 0.24, alpha: 1)
        let colors = [c1.cgColor, c2.cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) else {
            return false
        }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: rect.height),
            end: CGPoint(x: rect.width, y: 0),
            options: []
        )

        let symbolPoint = max(10, pixelSize * 0.33)
        let sizeWeight = NSImage.SymbolConfiguration(pointSize: symbolPoint, weight: .bold)
        // Bake true white into the bitmap. Template rendering can be remapped by the system
        // (e.g. Home Screen “Tinted” / “Dark” styles), which reads as a black outline on device.
        let whiteMono = NSImage.SymbolConfiguration(hierarchicalColor: .white)
        let symbolCfg = sizeWeight.applying(whiteMono)
        guard let base = NSImage(systemSymbolName: "scalemass", accessibilityDescription: nil),
              let sym = base.withSymbolConfiguration(symbolCfg) else {
            return true
        }

        sym.isTemplate = false

        let imgSize = sym.size
        let origin = CGPoint(
            x: (rect.width - imgSize.width) / 2,
            y: (rect.height - imgSize.height) / 2
        )
        let symbolRect = NSRect(origin: origin, size: imgSize)

        sym.draw(
            in: symbolRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        return true
    }
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "GenerateAppIcons", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get bitmap representation"])
    }
    rep.size = image.size
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateAppIcons", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}

private func ensureDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

// MARK: - iOS + iPad (Flutter-style manifest; shared filenames by pixel size)

private func generateIOSIcons(into appIconDir: URL) throws {
    let sizes: [(name: String, px: Int)] = [
        ("Icon-20.png", 20),
        ("Icon-29.png", 29),
        ("Icon-40.png", 40),
        ("Icon-58.png", 58),
        ("Icon-60.png", 60),
        ("Icon-76.png", 76),
        ("Icon-80.png", 80),
        ("Icon-87.png", 87),
        ("Icon-120.png", 120),
        ("Icon-152.png", 152),
        ("Icon-167.png", 167),
        ("Icon-180.png", 180),
        ("Icon-1024.png", 1024)
    ]

    try ensureDir(appIconDir)

    for item in sizes {
        let url = appIconDir.appendingPathComponent(item.name, isDirectory: false)
        let img = drawIcon(pixelSize: CGFloat(item.px))
        try writePNG(img, to: url)
        print("Wrote iOS", item.name, item.px)
    }

    let contents: [String: Any] = [
        "images": [
            ["size": "20x20", "idiom": "iphone", "filename": "Icon-40.png", "scale": "2x"],
            ["size": "20x20", "idiom": "iphone", "filename": "Icon-60.png", "scale": "3x"],
            ["size": "29x29", "idiom": "iphone", "filename": "Icon-29.png", "scale": "1x"],
            ["size": "29x29", "idiom": "iphone", "filename": "Icon-58.png", "scale": "2x"],
            ["size": "29x29", "idiom": "iphone", "filename": "Icon-87.png", "scale": "3x"],
            ["size": "40x40", "idiom": "iphone", "filename": "Icon-80.png", "scale": "2x"],
            ["size": "40x40", "idiom": "iphone", "filename": "Icon-120.png", "scale": "3x"],
            ["size": "60x60", "idiom": "iphone", "filename": "Icon-120.png", "scale": "2x"],
            ["size": "60x60", "idiom": "iphone", "filename": "Icon-180.png", "scale": "3x"],
            ["size": "20x20", "idiom": "ipad", "filename": "Icon-20.png", "scale": "1x"],
            ["size": "20x20", "idiom": "ipad", "filename": "Icon-40.png", "scale": "2x"],
            ["size": "29x29", "idiom": "ipad", "filename": "Icon-29.png", "scale": "1x"],
            ["size": "29x29", "idiom": "ipad", "filename": "Icon-58.png", "scale": "2x"],
            ["size": "40x40", "idiom": "ipad", "filename": "Icon-40.png", "scale": "1x"],
            ["size": "40x40", "idiom": "ipad", "filename": "Icon-80.png", "scale": "2x"],
            ["size": "76x76", "idiom": "ipad", "filename": "Icon-76.png", "scale": "1x"],
            ["size": "76x76", "idiom": "ipad", "filename": "Icon-152.png", "scale": "2x"],
            ["size": "83.5x83.5", "idiom": "ipad", "filename": "Icon-167.png", "scale": "2x"],
            ["size": "1024x1024", "idiom": "ios-marketing", "filename": "Icon-1024.png", "scale": "1x"]
        ],
        "info": ["version": 1, "author": "xcode"]
    ]

    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: appIconDir.appendingPathComponent("Contents.json"), options: .atomic)
}

// MARK: - watchOS (classic roles + marketing; covers grid / notification / launcher)

private func generateWatchIcons(into appIconDir: URL) throws {
    struct WatchSlot {
        let filename: String
        let px: Int
        let sizePt: String
        let scale: String
        let role: String?
        let subtype: String?
    }

    let slots: [WatchSlot] = [
        // Notification center
        WatchSlot(filename: "Watch-48.png", px: 48, sizePt: "24x24", scale: "2x", role: "notificationCenter", subtype: "38mm"),
        WatchSlot(filename: "Watch-55.png", px: 55, sizePt: "27.5x27.5", scale: "2x", role: "notificationCenter", subtype: "42mm"),
        WatchSlot(filename: "Watch-66.png", px: 66, sizePt: "33x33", scale: "2x", role: "notificationCenter", subtype: "45mm"),
        WatchSlot(filename: "Watch-70.png", px: 70, sizePt: "35x35", scale: "2x", role: "notificationCenter", subtype: "49mm"),
        // Companion / settings strip
        WatchSlot(filename: "Watch-58.png", px: 58, sizePt: "29x29", scale: "2x", role: "companionSettings", subtype: nil),
        WatchSlot(filename: "Watch-87.png", px: 87, sizePt: "29x29", scale: "3x", role: "companionSettings", subtype: nil),
        // App launcher sizes expected by current Xcode watchOS catalogs.
        WatchSlot(filename: "Watch-80.png", px: 80, sizePt: "40x40", scale: "2x", role: "appLauncher", subtype: "38mm"),
        WatchSlot(filename: "Watch-88.png", px: 88, sizePt: "44x44", scale: "2x", role: "appLauncher", subtype: "40mm"),
        WatchSlot(filename: "Watch-92.png", px: 92, sizePt: "46x46", scale: "2x", role: "appLauncher", subtype: "41mm"),
        WatchSlot(filename: "Watch-100.png", px: 100, sizePt: "50x50", scale: "2x", role: "appLauncher", subtype: "44mm"),
        WatchSlot(filename: "Watch-102.png", px: 102, sizePt: "51x51", scale: "2x", role: "appLauncher", subtype: "45mm"),
        WatchSlot(filename: "Watch-108.png", px: 108, sizePt: "54x54", scale: "2x", role: "appLauncher", subtype: "49mm"),
        // Quick Look (long-look notification)
        WatchSlot(filename: "Watch-172.png", px: 172, sizePt: "86x86", scale: "2x", role: "quickLook", subtype: "38mm"),
        WatchSlot(filename: "Watch-196.png", px: 196, sizePt: "98x98", scale: "2x", role: "quickLook", subtype: "42mm"),
        WatchSlot(filename: "Watch-234.png", px: 234, sizePt: "108x108", scale: "2x", role: "quickLook", subtype: "45mm"),
        WatchSlot(filename: "Watch-258.png", px: 258, sizePt: "117x117", scale: "2x", role: "quickLook", subtype: "49mm"),
        // App Store
        WatchSlot(filename: "Watch-1024.png", px: 1024, sizePt: "1024x1024", scale: "1x", role: nil, subtype: nil)
    ]

    try ensureDir(appIconDir)
    // Remove stale PNGs so old filenames do not stay as unassigned children.
    let existing = try FileManager.default.contentsOfDirectory(at: appIconDir, includingPropertiesForKeys: nil)
    for file in existing where file.pathExtension.lowercased() == "png" {
        try FileManager.default.removeItem(at: file)
    }

    var images: [[String: Any]] = []

    for slot in slots {
        let url = appIconDir.appendingPathComponent(slot.filename, isDirectory: false)
        let img = drawIcon(pixelSize: CGFloat(slot.px))
        try writePNG(img, to: url)
        print("Wrote watch", slot.filename, slot.px)

        if slot.role == nil {
            images.append([
                "size": slot.sizePt,
                "idiom": "watch-marketing",
                "filename": slot.filename,
                "scale": slot.scale
            ])
        } else {
            var dict: [String: Any] = [
                "size": slot.sizePt,
                "idiom": "watch",
                "filename": slot.filename,
                "scale": slot.scale,
                "role": slot.role!
            ]
            if let subtype = slot.subtype {
                dict["subtype"] = subtype
            }
            images.append(dict)
        }
    }

    let contents: [String: Any] = [
        "images": images,
        "info": ["version": 1, "author": "xcode"]
    ]

    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: appIconDir.appendingPathComponent("Contents.json"), options: .atomic)
}

// MARK: - macOS (App Store / Xcode catalog slots)

private func generateMacIcons(into appIconDir: URL) throws {
    struct MacSlot {
        let filename: String
        let px: Int
        let sizePt: String
        let scale: String
    }

    let slots: [MacSlot] = [
        MacSlot(filename: "Mac-16.png", px: 16, sizePt: "16x16", scale: "1x"),
        MacSlot(filename: "Mac-32.png", px: 32, sizePt: "16x16", scale: "2x"),
        MacSlot(filename: "Mac-32.png", px: 32, sizePt: "32x32", scale: "1x"),
        MacSlot(filename: "Mac-64.png", px: 64, sizePt: "32x32", scale: "2x"),
        MacSlot(filename: "Mac-128.png", px: 128, sizePt: "128x128", scale: "1x"),
        MacSlot(filename: "Mac-256.png", px: 256, sizePt: "128x128", scale: "2x"),
        MacSlot(filename: "Mac-256.png", px: 256, sizePt: "256x256", scale: "1x"),
        MacSlot(filename: "Mac-512.png", px: 512, sizePt: "256x256", scale: "2x"),
        MacSlot(filename: "Mac-512.png", px: 512, sizePt: "512x512", scale: "1x"),
        MacSlot(filename: "Mac-1024.png", px: 1024, sizePt: "512x512", scale: "2x")
    ]

    try ensureDir(appIconDir)

    var images: [[String: Any]] = []
    var written = Set<String>()

    for slot in slots {
        let url = appIconDir.appendingPathComponent(slot.filename, isDirectory: false)
        if !written.contains(slot.filename) {
            let img = drawIcon(pixelSize: CGFloat(slot.px))
            try writePNG(img, to: url)
            written.insert(slot.filename)
            print("Wrote mac", slot.filename, slot.px)
        }
        images.append([
            "size": slot.sizePt,
            "idiom": "mac",
            "filename": slot.filename,
            "scale": slot.scale
        ])
    }

    let contents: [String: Any] = [
        "images": images,
        "info": ["version": 1, "author": "xcode"]
    ]

    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: appIconDir.appendingPathComponent("Contents.json"), options: .atomic)
}

// MARK: - Root asset catalogs

private func writeRootContents(_ assetsRoot: URL) throws {
    let contents: [String: Any] = [
        "info": ["version": 1, "author": "xcode"]
    ]
    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: assetsRoot.appendingPathComponent("Contents.json"), options: .atomic)
}

// MARK: - main

do {
    let fm = FileManager.default
    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)

    let iosAssets = cwd.appendingPathComponent("App/iOS/Resources/Assets.xcassets", isDirectory: true)
    let watchAssets = cwd.appendingPathComponent("App/Watch/Resources/Assets.xcassets", isDirectory: true)
    let macAssets = cwd.appendingPathComponent("App/macOS/Resources/Assets.xcassets", isDirectory: true)

    try ensureDir(iosAssets)
    try ensureDir(watchAssets)
    try ensureDir(macAssets)
    try writeRootContents(iosAssets)
    try writeRootContents(watchAssets)
    try writeRootContents(macAssets)

    try generateIOSIcons(into: iosAssets.appendingPathComponent("AppIcon.appiconset", isDirectory: true))
    try generateWatchIcons(into: watchAssets.appendingPathComponent("AppIcon.appiconset", isDirectory: true))
    try generateMacIcons(into: macAssets.appendingPathComponent("AppIcon.appiconset", isDirectory: true))

    print("\nDone. Asset catalogs updated under App/iOS, App/Watch, and App/macOS Resources/Assets.xcassets")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
