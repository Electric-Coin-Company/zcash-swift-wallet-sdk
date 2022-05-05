// N.B This file is copied from the one that SPM generates to give a
// `Bundle.module` variable. Using the macro we include this only for non-SPM
// distribution methods, which we equate to "CocoaPods".
// We use CocoaPods' "Resource Bundles" to copy the resources that we need and
// we have called our main one "Resources" (see the podspec file), hence the hardcoded name.
#if !SWIFT_PACKAGE
import class Foundation.Bundle

private class BundleFinder {}

extension Foundation.Bundle {
  /// Returns the resource bundle associated with the current Swift module.
  static var module: Bundle = {
    let bundleName = "Resources"

    let candidates = [
      // Bundle should be present here when the package is linked into a framework.
      Bundle(for: BundleFinder.self).resourceURL
    ]

    for candidate in candidates {
      let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
      if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
        return bundle
      }
    }
    fatalError("unable to find bundle named Resources")
  }()
}
#endif
