//
//  RecipientTests.swift
//  OfflineTests
//
//  Created by Francisco Gindre on 8/31/22.
//

import XCTest
@testable import ZcashLightClientKit
final class RecipientTests: XCTestCase {
    let uaString = "u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj"

    let saplingString = "zs1vp7kvlqr4n9gpehztr76lcn6skkss9p8keqs3nv8avkdtjrcctrvmk9a7u494kluv756jeee5k0"

    let transparentString = "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz"

    func testUnifiedRecipient() throws {
        let expectedUnifiedAddress = UnifiedAddress(validatedEncoding: uaString)

        XCTAssertEqual(try Recipient(uaString, network: .mainnet), .unified(expectedUnifiedAddress))
    }

    func testSaplingRecipient() throws {
        let expectedSaplingAddress = SaplingAddress(validatedEncoding: saplingString)

        XCTAssertEqual(try Recipient(saplingString, network: .mainnet), .sapling(expectedSaplingAddress))
    }

    func testTransparentRecipient() throws {
        let expectedTransparentAddress = TransparentAddress(validatedEncoding: transparentString)

        XCTAssertEqual(try Recipient(transparentString, network: .mainnet), .transparent(expectedTransparentAddress))
    }

    func testRecipentFromEncoding() throws {
        let address = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"

        let recipient = Recipient.forEncodedAddress(
            encoded: address
        )

        XCTAssertEqual(recipient?.0, .sapling(SaplingAddress(validatedEncoding: address)))
        XCTAssertEqual(recipient?.1, .mainnet)

    }
}
