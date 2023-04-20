import XCTest
@testable import TestUtils
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
            saplingTree: """
            0103ac57cbe96a0f86b78527aa69b21db02318e7e7a6995cbe497a107707825655001001623311941fc8cfac849331dca1ba89a60552eb9dbadd0019f8dfcb5f6ac6c906\
            01b9a73d583be12b8e9c8a7616fe78a65469a2b91bdf02d411951fa261c9e1e64001e64e2365c8064f711643681da68b4fd626b28e5624abb9fb19d13208818b4d600133\
            0c2415a69eddb56d7a0846f03f4c98936607d5c0e7f580748224bd2117e51200000149f61a12a3f8407f4f7bd3e4f619937fa1a09e984a5f7334fcd7734c4ba3e3690000\
            0001bab80e68a5c63460d1e5c94ef540940792fa4703fa488b09fdfded97f8ec8a3d00013d2fd009bf8a22d68f720eac19c411c99014ed9c5f85d5942e15d1fc039e2868\
            0001f08f39275112dd8905b854170b7f247cf2df18454d4fa94e6e4f9320cca05f24011f8322ef806eb2430dc4a7a41c1b344bea5be946efc7b4349c1c9edb14ff9d39
            """,
            orchardTree: nil
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
            saplingTree: """
            01ef55e131bf5e7d6737a6e353fe0ff246ba8938a264335457452db2c4023241590113f4e2a1f043d0a303c769d9aac5eeb8b6854d1a64d71b6b86cda2e0eeee07621301\
            206a8d77952d4143cc5ba4d7943261e7145f0f138a81fe37c10e50a487487966012fb54cf3a70cccf01479fefc42e539c92a8215aead4179278cf1e8a302cb4868014574\
            313eb9fd9ee592346fdf27752f698c1f629b044437853972e266e95b56020001be3f0fa5b20bbfa445293d588073dc27a856c92e9903831c6de4455f03d57a0401bb534b\
            0af17c990f836204115aa17d4c2504fa0a675353ec7ae8a7d67510cc46012e2edeb7e5acb0d440dd5b500bec4a6efd6f53ba02c10e3883e23e53d7f91369000183c334e4\
            55aeeeb82cceddbe832919324d7011418749fc9dea759cfa6c2cc21501f4a3504117d35efa15f57d5fdd19515b7fb1dd14c3b98b8a91685f0f788db330000000018846ec\
            9170ad4e40a093cfb53162e5211d55377d8d22f826cde7783d30c1dd5f01b35fe4a943a47404f68db220c77b0573e13c3378a65c6f2396f93be7609d8f2a000125911f45\
            24469c00ccb1ba69e64f0ee7380c8d17bbfc76ecd238421b86eb6e09000118f64df255c9c43db708255e7bf6bffd481e5c2f38fe9ed8f3d189f7f9cf2644
            """,
            orchardTree: nil
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
            saplingTree: "000000",
            orchardTree: nil
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
            saplingTree: "000000",
            orchardTree: nil
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
    static let integerOverflowJSON = String(
        bytes: TestCoordinator.loadResource(name: "integerOverflowJSON", extension: "json"),
        encoding: .utf8
    )!
}
