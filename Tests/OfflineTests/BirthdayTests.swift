import XCTest
@testable import ZcashLightClientKit

class BirthdayTests: XCTestCase {
    func test_BirthdayGetsMostRecentCheckpointBelowIt_Testnet() throws {
        let birthday = Checkpoint.birthday(
            with: 1530003,
            network: ZcashNetworkBuilder.network(for: .testnet)
        )

        let expected = Checkpoint(
            height: 1530000,
            hash: "0011f78082f26747e02f0ab3525dc34d8df8f69dde273f462fcbf08fe2aa14d6",
            time: 1629030383,
            saplingTree: "0103ac57cbe96a0f86b78527aa69b21db02318e7e7a6995cbe497a107707825655001001623311941fc8cfac849331dca1ba89a60552eb9dbadd0019f8dfcb5f6ac6c90601b9a73d583be12b8e9c8a7616fe78a65469a2b91bdf02d411951fa261c9e1e64001e64e2365c8064f711643681da68b4fd626b28e5624abb9fb19d13208818b4d6001330c2415a69eddb56d7a0846f03f4c98936607d5c0e7f580748224bd2117e51200000149f61a12a3f8407f4f7bd3e4f619937fa1a09e984a5f7334fcd7734c4ba3e36900000001bab80e68a5c63460d1e5c94ef540940792fa4703fa488b09fdfded97f8ec8a3d00013d2fd009bf8a22d68f720eac19c411c99014ed9c5f85d5942e15d1fc039e28680001f08f39275112dd8905b854170b7f247cf2df18454d4fa94e6e4f9320cca05f24011f8322ef806eb2430dc4a7a41c1b344bea5be946efc7b4349c1c9edb14ff9d39"
        )

        XCTAssertEqual(birthday, expected)
    }

    func test_BirthdayGetsMostRecentCheckpointBelowIt_Mainnet() throws {
        let birthday = Checkpoint.birthday(
            with: 1340004,
            network: ZcashNetworkBuilder.network(for: .mainnet)
        )

        let expected = Checkpoint(
            height: 1340000,
            hash: "00000000031bc547da975ebd77d9113b178053f88fb6a1d8511b4f8962c21c4b",
            time: 1627846248,
            saplingTree: "01ef55e131bf5e7d6737a6e353fe0ff246ba8938a264335457452db2c4023241590113f4e2a1f043d0a303c769d9aac5eeb8b6854d1a64d71b6b86cda2e0eeee07621301206a8d77952d4143cc5ba4d7943261e7145f0f138a81fe37c10e50a487487966012fb54cf3a70cccf01479fefc42e539c92a8215aead4179278cf1e8a302cb4868014574313eb9fd9ee592346fdf27752f698c1f629b044437853972e266e95b56020001be3f0fa5b20bbfa445293d588073dc27a856c92e9903831c6de4455f03d57a0401bb534b0af17c990f836204115aa17d4c2504fa0a675353ec7ae8a7d67510cc46012e2edeb7e5acb0d440dd5b500bec4a6efd6f53ba02c10e3883e23e53d7f91369000183c334e455aeeeb82cceddbe832919324d7011418749fc9dea759cfa6c2cc21501f4a3504117d35efa15f57d5fdd19515b7fb1dd14c3b98b8a91685f0f788db330000000018846ec9170ad4e40a093cfb53162e5211d55377d8d22f826cde7783d30c1dd5f01b35fe4a943a47404f68db220c77b0573e13c3378a65c6f2396f93be7609d8f2a000125911f4524469c00ccb1ba69e64f0ee7380c8d17bbfc76ecd238421b86eb6e09000118f64df255c9c43db708255e7bf6bffd481e5c2f38fe9ed8f3d189f7f9cf2644"
        )

        XCTAssertEqual(birthday, expected)
    }

    func test_startBirthdayIsGivenIfTooLow_Testnet() throws {
        let birthday = Checkpoint.birthday(
            with: 4,
            network: ZcashNetworkBuilder.network(for: .testnet)
        )

        let expected = Checkpoint(
            height: 280000,
            hash: "000420e7fcc3a49d729479fb0b560dd7b8617b178a08e9e389620a9d1dd6361a",
            time: 1535262293,
            saplingTree: "000000"
        )

        XCTAssertEqual(birthday, expected)
    }

    func test_startBirthdayIsGivenIfTooLow_Mainnet() throws {
        let birthday = Checkpoint.birthday(
            with: 4,
            network: ZcashNetworkBuilder.network(for: .mainnet)
        )

        let expected = Checkpoint(
            height: 419200,
            hash: "00000000025a57200d898ac7f21e26bf29028bbe96ec46e05b2c17cc9db9e4f3",
            time: 1540779337,
            saplingTree: "000000"
        )

        XCTAssertEqual(birthday, expected)
    }

    func test_orchardTreeIsNotNilOnActivation_Mainnet() throws {
        let activationHeight = 1687104

        let birthday = Checkpoint.birthday(
            with: activationHeight,
            network: ZcashNetworkBuilder.network(for: .mainnet)
        )

        XCTAssertEqual(birthday.height, activationHeight)
        XCTAssertEqual(birthday.orchardTree, "000000")
    }

    func test_orchardTreeIsNilBeforeActivation_Mainnet() throws {
        let activationHeight = 1_687_104

        let birthday = Checkpoint.birthday(
            with: activationHeight - 1,
            network: ZcashNetworkBuilder.network(for: .mainnet)
        )

        XCTAssertNil(birthday.orchardTree)
    }

    func test_orchardTreeIsNotNilOnActivation_Testnet() throws {
        let activationHeight = 1_842_420

        let birthday = Checkpoint.birthday(
            with: activationHeight,
            network: ZcashNetworkBuilder.network(for: .testnet)
        )

        XCTAssertEqual(birthday.height, activationHeight)
        XCTAssertEqual(birthday.orchardTree, "000000")
    }

    func test_orchardTreeIsNilBeforeActivation_Testnet() throws {
        let activationHeight = 1687104

        let birthday = Checkpoint.birthday(
            with: activationHeight - 1,
            network: ZcashNetworkBuilder.network(for: .testnet)
        )

        XCTAssertNil(birthday.orchardTree)
    }

    func test_CheckpointParsingFailsIfIntegerOverflows() throws {
        let jsonData = Self.integerOverflowJSON.data(using: .utf8)!
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(Checkpoint.self, from: jsonData))
    }

    /// this has height with `Int64.max + 1`
    static let integerOverflowJSON: String =
    """
    {
      "network": "main",
      "height": "9223372036854775808",
      "hash": "0000000000aefe1d3aaa6908bd9fe99d476afd72ec49be60090d6ee48f9272bf",
      "time": 1656499365,
      "saplingTree": "0175848b81090fee135ed81677520ee555e72814ec47d77107779f1d958f72903001a5f61227d13a351d6b9744e572fbddfa60de77650f3b355838771ded6e929a401400000000016a6c28ea8d49d0b32f9c8fad56f239fd6f1dabd0eb2771d7877d4b3d714aee6b0001e4cf1a347436f1b700976cfa387833d3dd53eb3e9e7201d68d1fa15735db411e0140e3461535e2391a82f6cc29221432f53cdc62c697f36cd1077bc5c40bed2d230138cbb3e580d3292e0c783e8e37077be9a1e2c7c95cbc6a4a58cf6f51af755170012896f2157ea42af3ce58fa133917712564a148708702ba3dc5235e49ae36be15000001b9db8a4ba52f5cdea9d142ce71601c2890e9dc306018b4a730a9c8c0a7e258260000000134e093f073973de750e85daff57c07a102dbc7bbc77436e99b0074f36f1cbf130000015ec9e9b1295908beed437df4126032ca57ada8e3ebb67067cd22a73c79a84009",
      "orchardTree": "01492e49f873e033c8baf296de1a78f34618d2ac1a64eca3769b93918da66e3f37001f000000018d8f2180ce6978074be7b5bec41e993232ac73797ca80ae32f062a5d83ee363c00000114764dc108e86dc2c6d7c20a6e1759027d87029b5dc7e1e6b5be970ecbed913a01186d95ac66b184f8844e57fece62a4d64cfeb73e7ed6e99146e79aacae7f5e00012f9cd86767aea1f11147f65c588f94dce188315c40b22c0fa8751365ba453c280001130cfb41380fdd7836985e2c4c488fdc3d1d1bd4390f350f0e1b8a448f47ac1c012bcbdd308beca04006b18928c4418aad2b3650677289b1b45ea5a21095c5310301100ed4d0a8a440b03f1254ce1efb2d82a94cf001cffa0e7fd6ada813a2688b240130a69de998b87aebcd4c556503a45e559a422ecfbdf2f0e6318a8427e41a7b09017676cfe97afff13797f82f8d631bd29edde424854139c64ab8241e2a2331551401da371f0d3294843fd8f645019a04c07607342c70cf4cc793068355eaccdd671601bc79f0119f97113775379bf58f3f5d9d122766909b797947127b28248ff0720501c1eb3aa1717c2a696ce0aba6c5b5bda44c4eda5cf69ae376cc8b334a2c23fb2b0001374feb2041bfd423c6cc3e064ee2b4705748a082836d39dd723515357fb06e300000000000000000000000"
    }
    """
}
