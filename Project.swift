import ProjectDescription

let project = Project(
    name: "AirControl",
    targets: [
        .target(
            name: "AirControl",
            destinations: .macOS,
            product: .app,
            bundleId: "com.dltldn1234.AirControl",
            infoPlist: .extendingDefault(
                with: [
                    "LSApplicationCategoryType": .string("public.app-category.utilities"),
                    "NSCameraUsageDescription": .string(
                        "AirControl will use the camera to recognize hand gestures when tracking is available."
                    ),
                ]
            ),
            buildableFolders: [
                "Sources",
                "Resources",
            ],
            dependencies: [],
            settings: .settings(
                base: ["MACOSX_DEPLOYMENT_TARGET": "14.0"]
            )
        ),
        .target(
            name: "AirControlTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.dltldn1234.AirControlTests",
            infoPlist: .default,
            buildableFolders: ["Tests"],
            dependencies: [.target(name: "AirControl")],
            settings: .settings(
                base: ["MACOSX_DEPLOYMENT_TARGET": "14.0"]
            )
        ),
    ]
)
