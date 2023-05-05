# Development Process

the `main` branch is considered a Development-Stable branch. This means that every PR merged to it compiles, tests pass and is considered to be _deployable_. However, SDK clients **MUST NOT** import the SDK as a dependency by pointing to `main` unless they are purposely doing so for development or feature previewing. 

Even though the SDK is currently in **beta** and developers should always use the dependencies released through published tags. 

## alpha versions
This type of version is intended for developer preview. Clients importing `alpha` versions of the SDK should expect APIs breaking and known (and unknown) issues. 