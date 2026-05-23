// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "LRBReader",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "LRBReader",
            targets: ["AppModule"],
            bundleIdentifier: "com.sk.lrbreader",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [
                .pad,
                .phone,
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
