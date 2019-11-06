SDK Threat Model
=================

This threat model is intended for developers making use of the SDK. See the
[Invariant-Centric Threat Modeling](https://github.com/defuse/ictm) for
a complete explanation of the threat modeling methodology we use; the short
summary is:

- The SDK should currently satisfy the security invariants listed here, with
  more to be added in the future.
- Developers *shouldn't rely on any security or privacy properties that are not
  listed here*. If you would like to be able to rely on a property you don't see
  here, please raise an issue on GitHub.

If you are a security auditor, please try to break one of the security
invariants! Please also think about important security invariants that might be
missing from this list!

In order to state the security invariants, we first define some scenarios in
which the SDK might be used, along with some adversaries that the end-user may
be concerned about being attacked by.

## Usage Scenarios

- HONEST: There is a trust relationship between the end-user and the
  `lightwalletd` service the user connects to. The `lightwalletd` service only
  ever provides valid information coming from a consistent Zcash blockchain
  state. The information is not guaranteed to be recent, and part of it may
  change (e.g. after a reorg). The connection to `lightwalletd` is protected by
  TLS.
- UNTRUSTED: The `lightwalletd` service the user connects to could be malicious.

## Adversaries

In the HONEST scenario:

- UNPRIVUSR is an unprivileged user on the same system the SDK is running on. We
  additionally assume they know one of the z-addresses managed by the SDK.
- MITM can intercept and modify all of the SDK's Internet traffic. We
  additionally assume they know one of the z-addresses managed by the SDK.
- LWD-READONLY has read-only access to the memory and storage of the
  `lightwalletd` server the SDK connects to.

Most end-users won't know or care about the distinction between these
adversaries, so it makes sense to define a class containing all of them:

- TYPICAL: {UNPRIVUSR, MITM, LWD-READONLY, APP + LWD-READONLY + MITM}

Here, the `+` sum of two adversaries is another adversary with the combination
of their capabilities.

In the UNTRUSTED scenario:

- EVIL-LWD is the adversary in control of the `lightwalletd` server.

## Security Invariants

Given these scenarios and adversaries, we can now state the security invariants
we stive to satisfy. While we pride ourselves on building high-quality software,
all software contains bugs, and so this threat model must not be construed as
any kind of warranty that our software satisfies these properties.

**This SDK has not yet received security review. There are no security
invariants to be stated yet.**

## Known Weaknesses

Some of the TYPICAL adversaries, and possibly others, can:

- Detect that the SDK is in use, by looking for its distinctive network usage
  patterns.
- Detect when the SDK sends/receives transactions, by observing how much data is
  sent to `lightwalletd` and when.
- Prevent the SDK from functioning temporarily, by blocking the connection to
  `lightwalletd`.

In an UNTRUSTED scenario, a number of attacks may be possible. These include but
are not limited to:

- Attacks that DoS the SDK, including some that potentially prevent the SDK
    from working until it is reinstalled and the keys reimported.
- Other attacks. At this point we don't aim to provide any security invariants
  in an untrustworthy-lightwalletd scenario.

This threat model is missing important details, e.g. about:

- Adversaries that have physical access to the device the SDK is running on.
- Secure usability of the SDK's API.
- Implicit assumptions about how the SDK is being used.

These shortcomings will be addressed in future updates to the threat model.
