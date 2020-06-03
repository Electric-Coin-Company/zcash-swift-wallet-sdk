# Continuous Integration

In order to ensure code changes comply with the target integrations, the following policies should be observed.

## Changes to the GitHub project

The `master` branch is the git repositories default branch.

Pull Request actions are determined by the author's association to the GitHub project. Levels are defined https://developer.github.com/v4/enum/commentauthorassociation/.

### When a PR is opened by COLLABORATOR

- check that linting is successful
- check that the code builds
- check that PR tests pass

### When a PR is opened by NONE

- check that linting is successful
- check that the code builds

### Code changes to the master branch

These changes are identified by modifications to files under the following directories 
| Directory     | files         |
| ------------- | ------------- |
| Scripts       | `*.sh`        |
| `rust/src`    | `*.rs`        |
| ZcashLightClientKit   | `*.swift | *.stencil` |
| root  |   `*.xcworkspace/** | *.xcodeproj | *.toml` |
| ZcashLightClientKitTests | `*.swift` |
| `Example/ZcashLightClientSample/ZcashLightClientSample` | `*.swift`   |


- build the project
- update code documentation via `jazzy --podspec ZcashLightClientKit.podspec`

### New tag MAJOR.MIDDLE.MINOR{-betaX} is created

- build the project
- run tests
- run `pod lib lint --skip-tests --allow-warnings && pod trunk push --skip-tests --allow-warnings` to create pod version

## Time based changes

Periodic continous integration tasks

### Nightly

- run integration tests
- send notifications for failed builds or failed nightly integrations

## Targets

- **ZcashLightClientSample** : build and run example demo app
- **ZcashLightClientKit-Unit-Tests** : build and test unit and integration tests (darksidewalletd required)
