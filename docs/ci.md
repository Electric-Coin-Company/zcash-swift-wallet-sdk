# Continuous Integration

The project is integrated the following CI platforms:
- Bitrise
  - Builds
- Travis CI
  - Builds


## When a PR is opened

- check that linting is successful (to be integrated)
- check that the code builds
- check that PR tests pass


## Manual Deployment

Prerequisites:
- Write permissions on the repo

Steps:
- build the project
- run tests
- Create a new tag MAJOR.MIDDLE.MINOR{-betaX}
