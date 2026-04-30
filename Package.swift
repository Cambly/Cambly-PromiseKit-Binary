// swift-tools-version: 5.9
// AUTO-GENERATED parts (urls + checksums) are updated by .github/workflows/build-and-release.yml
// when a new release is cut. Manual edits to checksums will be overwritten.
import PackageDescription

let package = Package(
  name: "PromiseKit",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "PromiseKit", targets: ["PromiseKit"]),
  ],
  targets: [
    .binaryTarget(
      name: "PromiseKit",
      url: "https://github.com/Cambly/Cambly-PromiseKit-Binary/releases/download/6.22.1/PromiseKit.xcframework.zip",
      checksum: "0688c821b598ea0b35e80f735a1aaa3f1b5618070e7006de068423ae3c191931"
    ),
  ]
)
