# Documentation 

Source code is intended to be self-documented with inline comments complying to SwiftDoc.
A generated HTML version of the source code documentation can be found here in this [Jazzy Generated documentation](docs/rtd/index.html), although is not generated very often. Always rely in the documentation found on the source code.


[SDK Architecture documentation](docs/Architecture.md) can be found on `docs/Architecture.md`

Continuous Integration documentation can found in [docs/ci.md](docs/ci.md)

Our **development process** is simple and described in [docs/development_process.md](docs/development_process.md)


In the `/testing` folder you will find documentation related to manual and automated testing. 

## Updating HTML docs

In order to the update the generated HTML version of the source code documentation you first have to [install Jazzy Docs](https://github.com/realm/jazzy). Once installed


````bash
rm -rf docs/rtd # clear the existing docs

# the generate the new docs
jazzy \
--module ZcashLightClientKit \
--swift-build-tool spm \
--build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 --output docs/rtd

# commit your changes
````

