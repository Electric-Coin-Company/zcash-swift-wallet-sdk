# iOS demo app 
This is a demo app that exercises code in https://github.com/zcash/ZcashLightClientKit, which has all the iOS-related functionalities necessary to build a mobile Zcash shielded wallet. 

It relies on [Lightwalletd](https://github.com/zcash/lightwalletd), a backend service that provides a bandwidth-efficient interface to the Zcash blockchain. There is an equivalent [Android demo app](https://github.com/zcash/zcash-android-wallet-sdk/). 


## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Exploring the demo app](#exploring-the-demo-app)
  - [Demos](#demos)
- [Getting started](#getting-started)
- [Resources](#resources)

## Requirements
Demo app requires a target device running iOS 12+. The demo directly links source code so building it also requires Rust, Sourcery, and Xcode. 

[Back to contents](#contents)

## Installation
Refer to [build instructions](https://github.com/zcash/ZcashLightClientKit) in the readme of the android-wallet-sdk repository for detailed instructions. In short, you will need to: 

1. Install rust: https://www.rust-lang.org/learn/get-started 
1. Install sourcery: https://github.com/krzysztofzablocki/Sourcery
1. Clone this repo, https://github.com/zcash/ZcashLightClientKit
1. Launch from Xcode, https://developer.apple.com/xcode/

[Back to contents](#contents)

## Exploring the demo app
After building the app, the emulator should launch with a basic app that exercises the SDK (see picture below). 
To explore the app, click on each menu item, in order, and also look at the associated code. 

![The android demo app, running in Android Studio](assets/ios-demo-app.png?raw=true "Demo app built with Xcode")

The demo app is not trying to show what's possible, but to present how to accomplish the building blocks of wallet functionality in a simple way in code. It is comprised of the following self-contained demos. All data is reset between demos in order to keep the behavior repeatable and independent of state.

### Demos

Menu Item|Related Code|Description
:-----|:-----|:-----
Get address | [GetAddressViewController.swift]() | Given a seed, display its z-addr
Latest block height | [LatestHeightViewController.swift]() | Given a lightwalletd server, retrieve the latest block height
Sync blocks | [SyncBlocksViewController.swift]() | Download compact blocks from the lightwalletd server. 
Get balance | [GetBalanceViewController.swift]() | Calculates the balance of the current wallet address.
Send funds | [SendViewController.swift]()| Send a transaction, the most complex demo. 
Transaction details | [TransactionDetailViewController.swift]() | See status of a transaction: pending or confirmed, sent or received. 
All transactions |  [TransactionsTableViewController.swift](), [TransactionsDataSource.swift]() | Displays as much available transaction information  on the wallet. 
Paginated transactions |  [PaginatedTransactionsViewController.swift]() | Demonstrates how to paginate transactions. 

[Back to contents](#contents)

## Getting started
We’re assuming you already have a brilliant app idea, a vision for the app’s UI, and know the ins and outs of the Android lifecycle. We’ll just stick to the Zcash app part of “getting started.” 

Similarly, the best way to build a functioning Zcash shielded app is to implement the functionalities that are listed in the demo app, in roughly that order: 

1. Generate and safely store your private key. 
1. Get the associated address, and display it to the user on a receive screen. You may also want to generate a QR code from this address. 
1. Make sure your app can talk to the lightwalletd server and check by asking for the latest height, and verify that it’s current with the Zcash network. 
1. Try interacting with lightwalletd by fetching a block and processing it. Then try fetching a range of blocks, which is much more efficient. 
1. Now that you have the blocks process them and list transactions that send to or are from that wallet, to calculate your balance. 
1. With a current balance (and funds, of course), send a transaction and monitor its transaction status and update the UI with the results. 

[Back to contents](#contents)

## Resources
You don’t need to do it all on your own. 
* Chat with the team who built the kit: [Zcash discord community channel, wallet](https://discord.gg/efFG7UJ)
* Discuss ideas with other community members: [Zcash forum](https://forum.zcashcommunity.com/) 
* Get funded to build a Zcash app: [Zcash foundation grants program](https://grants.zfnd.org/)
* Follow Zcash-specific best practices: [Zcash wallet developer checklist](https://zcash.readthedocs.io/en/latest/rtd_pages/ux_wallet_checklist.html)
* Get more information and see FAQs about the wallet: [Shielded resources documentation](https://zcash.readthedocs.io/en/latest/rtd_pages/shielded_support.html)

[Back to contents](#contents)
