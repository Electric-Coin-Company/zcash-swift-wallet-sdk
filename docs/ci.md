# Continuous Integration

The project is integrated the following CI platforms:
- Bitrise
  - Builds
  - Deployment to Cocoapods Trunk
- Travis CI
  - Builds


## When a PR is opened

- check that linting is successful (to be integrated)
- check that the code builds
- check that PR tests pass


## Manual Deployment

Prerequisites:
- Write permissions on the repo
- Push permission on CocoaPods Trunk

Steps:
- build the project
- run tests
- Create a new tag MAJOR.MIDDLE.MINOR{-betaX}
- update the ZcashLightClientKit.podspec file with the corresponding version.
- run `pod lib lint --skip-tests --allow-warnings && pod trunk push --skip-tests --allow-warnings` to create pod version