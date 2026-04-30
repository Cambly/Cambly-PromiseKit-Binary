# Cambly-PromiseKit-Binary

Prebuilt `.xcframework` distribution of [PromiseKit](https://github.com/mxcl/PromiseKit) for Cambly's iOS apps. The wrapper exists because upstream PromiseKit does not ship official xcframeworks; we build them once per version and host as GitHub release assets so consuming apps avoid recompiling PromiseKit on every clean build.

Versions track upstream tags exactly (e.g. this repo's tag `6.22.1` corresponds to `mxcl/PromiseKit@6.22.1`).

## How it works

`Package.swift` declares a `binaryTarget` for the `PromiseKit` product, pointing at this repo's GitHub release assets, with a sha256 checksum. SwiftPM consumers add this repo as a dependency and use `PromiseKit` as if it were upstream.

Only the `PromiseKit` product is published — Cambly's iOS apps do not currently use `PMKFoundation`, `PMKUIKit`, or `CancelForPromiseKit`. If a future need arises, add them by following the "Edge cases" section below.

## Upgrading to a new PromiseKit version

The full upgrade involves **two repos**:

### Step 1: cut a new release here

Trigger the **Build and Release xcframeworks** workflow under the Actions tab (or via CLI), passing the new upstream version:

```bash
gh workflow run build-and-release.yml -f version=6.22.2 \
  --repo Cambly/Cambly-PromiseKit-Binary
gh run watch --repo Cambly/Cambly-PromiseKit-Binary
```

The workflow (~10-15 min):
- Clones `mxcl/PromiseKit` at the given tag
- Builds `PromiseKit` for iOS device + iOS simulator with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`
- Bundles into `PromiseKit.xcframework`, zips it
- Uploads the zip as a new GitHub release
- Patches `Package.swift` with new url + sha256, commits, pushes

### Step 2: bump the version pin in consuming app repo

In `Cambly/Cambly-Swift`, edit `project_files/swift_packages.yml`:

```diff
 PromiseKit:
   url: git@github.com:Cambly/Cambly-PromiseKit-Binary
-  version: 6.22.1
+  version: 6.22.2
```

Then regenerate + resolve + build to verify:

```bash
./update.sh --skip-resolve-packages
xcodebuild -resolvePackageDependencies -workspace Cambly.xcworkspace -scheme "Cambly Production"
xcodebuild -disableAutomaticPackageResolution -workspace Cambly.xcworkspace \
  -scheme "Cambly Production" -destination 'generic/platform=iOS Simulator' build
```

Open a normal PR — the only changes should be the one yml line + auto-updated `Package.resolved` files.

### Edge cases

| Situation | What to do |
|---|---|
| Need to add a new product (e.g. `PMKFoundation`) | Add a new `.binaryTarget` and `.library` in `Package.swift`; add the product name to Makefile `PRODUCTS`; add `<NAME>_SHA` env var in the workflow + `SHAS` dict in `patch_package_swift.py`; re-run the workflow |
| Upstream removes a product | Remove from `Package.swift`, Makefile `PRODUCTS`, workflow env vars, and `patch_package_swift.py` `SHAS`; remove any consumer references in Cambly-Swift |
| Major version (e.g. 7.x) with API/ABI changes | Application code in Cambly-Swift may need updates — same as a source-based upgrade |
| Upstream renames a scheme (rare) | Workflow will fail at `xcodebuild archive`; run `make all VERSION=X.Y.Z` locally and use `xcodebuild -list` to find the real scheme name; fix Makefile `PRODUCTS` |
| `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` fails to compile | Rare. Falls back to per-Xcode-version slicing (similar to MOB-185 Realm); requires restructuring this repo |

## Manual release fallback

If GitHub Actions is unavailable:

```bash
make all VERSION=6.22.2
# Outputs build/artifacts/PromiseKit.xcframework.zip
# Manually:
gh release create 6.22.2 build/artifacts/PromiseKit.xcframework.zip
# Read sha256 from `make checksums VERSION=6.22.2` output, edit Package.swift by hand,
# git commit, git push, git tag 6.22.2, git push --tags
```
