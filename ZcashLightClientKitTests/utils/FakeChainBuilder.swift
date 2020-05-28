//
//  FakeChainBuilder.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 5/21/20.
//

import Foundation
@testable import ZcashLightClientKit

enum FakeChainBuilderError: Error {
    case fakeHexDataConversionFailed
}
class FakeChainBuilder {
    static let someOtherTxUrl = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/transactions/t-shielded-spend.txt"
    static let txMainnetBlockUrl = "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/basic-reorg/663150.txt"
    static func buildChain(darksideWallet: DarksideWalletService) throws {
        try darksideWallet.reset(saplingActivation: 663150)
        try darksideWallet.useDataset(from: txMainnetBlockUrl)
       
        try darksideWallet.stageBlocksCreate(from: 663151, count: 100)
        
        try darksideWallet.stageTransaction(from: txUrls[663174]!, at: 663174)
        
        try darksideWallet.stageTransaction(from: txUrls[663188]!, at: 663188)
        
    }
    
    static func buildTxUrl(for id: String) -> String {
        "https://raw.githubusercontent.com/zcash-hackworks/darksidewalletd-test-data/master/transactions/recv/\(id).txt"
    }
    
    static var txUrls = [
        663174 : buildTxUrl(for: "8f064d23c66dc36e32445e5f3b50e0f32ac3ddb78cff21fb521eb6c19c07c99a"),
        663188 : buildTxUrl(for: "15a677b6770c5505fb47439361d3d3a7c21238ee1a6874fdedad18ae96850590"),
        663202 : buildTxUrl(for: "d2e7be14bbb308f9d4d68de424d622cbf774226d01cd63cc6f155fafd5cd212c"),
        663218 : buildTxUrl(for: "e6566be3a4f9a80035dab8e1d97e40832a639e3ea938fb7972ea2f8482ff51ce"),
        663229 : buildTxUrl(for: "0821a89be7f2fc1311792c3fa1dd2171a8cdfb2effd98590cbd5ebcdcfcf491f"),
        663849 : buildTxUrl(for: "c9e35e6ff444b071d63bf9bab6480409d6361760445c8a28d24179adb35c2495"),
        663891 : buildTxUrl(for: "72a29d7db511025da969418880b749f7fc0fc910cdb06f52193b5fa5c0401d9d"),
        663922 : buildTxUrl(for: "ff6ea36765dc29793775c7aa71de19fca039c5b5b873a0497866e9c4bc48af01"),
        663938 : buildTxUrl(for: "34e507cab780546f980176f3ff2695cd404917508c7e5ee18cc1d2ff3858cb08"),
        663942 : buildTxUrl(for: "6edf869063eccff3345676b0fed9f1aa6988fb2524e3d9ca7420a13cfadcd76c"),
        663947 : buildTxUrl(for: "de97394ae220c28a33ba78b944e82dabec8cb404a4407650b134b3d5950358c0"),
        663949 : buildTxUrl(for: "4eaa902279f8380914baf5bcc470d8b7c11d84fda809f67f517a7cb48912b87b"),
        663953 : buildTxUrl(for: "e9527891b5d43d1ac72f2c0a3ac18a33dc5a0529aec04fa600616ed35f8123f8"),
        663956 : buildTxUrl(for: "73c5edf8ffba774d99155121ccf07e67fbcf14284458f7e732751fea60d3bcbc"),
        663974 : buildTxUrl(for: "4dcc95dd0a2f1f51bd64bb9f729b423c6de1690664a1b6614c75925e781662f7"),
        664003 : buildTxUrl(for: "d2e859e8ef8ab27355c7a6caf643065d2d7a720e334c4a84943f6d1ae3919b5d"),
        664012 : buildTxUrl(for: "547784f746eef2f164bbb1a56882723dde744157a21e4fdfeadee763f73fee84"),
        664022 : buildTxUrl(for: "981638bb7ac08e31ee6db5c70d98ad6b137a448716b19245f9454b450c07c911"),
        664037 : buildTxUrl(for: "36505ab3c78c62981c8111d143cd57dcfe6cafcb2c3cdc258b023ae5210d53f1"),
        664038 : buildTxUrl(for: "0ffc55af750bb10a9e6a7e425138cc5acb5f7ddca68bf9d0c4606437bd692622"),
        678828 : buildTxUrl(for: "cfd3bce9fdeeae12b99fdb977a997177e183c2312871f0454bdf61640cc03d93"),
        678836 : buildTxUrl(for: "5af3bc9818e5fabcc691f319d7354cc4194f17727f6303d59a94c3e5f0daf560"),
        682588 : buildTxUrl(for: "b1f566dec94048ff81306884b6ed92eb73cdb768b738d9c8cbd94babc1f0a9c9"),
        683689 : buildTxUrl(for: "3b568a1547832ac28bfcaf4c269f85fd68083735790f7949aa3a548ab53acf65"),
        683791 : buildTxUrl(for: "9e2eb538207ab47356a3723fd0e6f44b9349ea944d9c2d7be0d4e3a6a02c2c29"),
        683795 : buildTxUrl(for: "15d2f32494271f0a60f3928e4fc79c2cea337e06fbbbe7f6fb4a0d36002a0d42"),
        683809 : buildTxUrl(for: "76be7c244c37e1710bbb9f162baab265eebc8a379ad1843435ba5e7a2c21a600"),
        684374 : buildTxUrl(for: "3640a35c02cf4d9e0fa178380173b193873d8a0ef4bad57dd43e7d95db450c89"),
        685126 : buildTxUrl(for: "86f3457bdb8793a413c009a8a7e128b5a82723f41ebe557327bbe555fd47fbf3"),
        687746 : buildTxUrl(for: "edb32a55d5fa18fc5c6bf09f5f1de198b219b6780ca71bbc4fd321b655bbfe42"),
        687900 : buildTxUrl(for: "855af341c14b94fec67e5eb56bb801a59551df33e9d955982672f5f62e76f72e"),
        688059 : buildTxUrl(for: "57c226f77ad01ecf833515612e7cba7abe64500fa891144c2c89c59af8c36c22"),
        691540 : buildTxUrl(for: "9a74cd7f170f6c8cef04f3327fdcf63ec69dd1263f80c9bf0b3002c871950ddd"),
        691593 : buildTxUrl(for: "6b64134034ec282092501f85bf8955006894dbcac402fa5e6c85ee867334cd3d"),
        691632 : buildTxUrl(for: "75f2cdd2ff6a94535326abb5d9e663d53cbfa5f31ebb24b4d7e420e9440d41a2"),
        692981 : buildTxUrl(for: "f98f2c75785f110203930c7fd4115019ec70af6470db1be052985b469906fe98"),
        692984 : buildTxUrl(for: "67138ad7e5e97216124c2bbcda8edb7687c2cfbf5d644df2af2a86344437a661"),
        692992 : buildTxUrl(for: "6cf507ab4d3255fa51679c0256a1be1d668786bd3f558000f9e90ec442514212"),
        693248 : buildTxUrl(for: "d1278d74424807b830256ccbd4d7624dc9e68a50760f870a55c8e99715072ef1"),
        693268 : buildTxUrl(for: "e56c84718de5dee049b31c89832f4bf1694268e2664a04df182a8797cb00b52e"),
        693325 : buildTxUrl(for: "5635f48dc99adfebb0be105231b9383bd2d0df64e43a780d11620390640b8d3d"),
        693398 : buildTxUrl(for: "26c41d5dbbaaa3934b37109645b0aece9600248c5f51404d1f4ea7b711ac3312"),
        693460 : buildTxUrl(for: "8d381a3d993c8d424db0907bab3fef6000bc8de9efe7186846d44dd6d6a014b1"),
        693475 : buildTxUrl(for: "900f2a406c1546126e1dba0e4e6ca0e092ebe697a2f7b0abee4e9771e1038f0b"),
        693718 : buildTxUrl(for: "7690c8ec740c1be3c50e2aedae8bf907ac81141ae8b6a134c1811706c73f49a6"),
        693736 : buildTxUrl(for: "34a4d630f120e4c1e7d2b9844c69fd4d3be71532ade1aaf7147566f05162c316"),
        696005 : buildTxUrl(for: "076d30ca62082dda9a760e0d004393cd96830056c6dca643fccdbe500053e355"),
        696012 : buildTxUrl(for: "e2da49325057b2232e85b0228955234f4a3538df2ebf4cd121589bac9771f6f2"),
        696040 : buildTxUrl(for: "4f6ef63bd3be8338c902901daf77ab5aa23dd97c160ee91b00950accf7f0b194"),
        698361 : buildTxUrl(for: "d275a9e96e6c68dfb8fe6ec3fd39737ce5fa880f86552b3ed993048373d6e8ad"),
        710823 : buildTxUrl(for: "bac04ad7734628e70a57408c65403ec845bce575197e7984435976e1ac64ae4f"),
        710896 : buildTxUrl(for: "56c63ef496f633418f0576cc34a0730c74023d78003b95aff731e0448c8b9203"),
        711847 : buildTxUrl(for: "82439eade5d1deba7606f3db53bf33588677b1bd9765a5eb5f4d3f6980ecb3d4"),
        727486 : buildTxUrl(for: "b5877c7f7dd3856bae679f7ccb37ddf3fcd2fafe72a081878ee9069fc25934cd"),
        728159 : buildTxUrl(for: "5d6a0c4879a244d2c0a6e2d26c4d0d26dee5a5c1f3f13f42436253272d4b8a03"),
        736102 : buildTxUrl(for: "be3a3a3fe10b9a1976410e5aaf425b24695dcdd04df926a23d9f3f8ed43178c6"),
        736254 : buildTxUrl(for: "acc0685aee04f7b7c6a12c969c1646038ea4a3b940d00b28d1eaf7643602d49e"),
        736262 : buildTxUrl(for: "fed00ff5cb6ee057d00ec70f1f5f1b189d591903c1e1cbde654ad39c8477808c"),
        736301 : buildTxUrl(for: "f3ef9f3adedf2b66e438c9d7d878ed72886b62b70e68547bb47d5b6033519dcd"),
        736574 : buildTxUrl(for: "34574442629a2378eccd216385d8bc99859e214e79265941319599130de2c69a"),
        739582 : buildTxUrl(for: "71935e29127a7de0b96081f4c8a42a9c11584d83adedfaab414362a6f3d965cf"),
        741148 : buildTxUrl(for: "5eff7f15b39b9ab463767b768e23f90b4a23239ed873fdfbd4afa286027f7b57"),
        741154 : buildTxUrl(for: "b05c3df882ccff4f58acc1e3dbe2520213159d584bac01ff0199c37c25451430"),
        741156 : buildTxUrl(for: "1a3bb3d4fece0fcde1a47ef8271511cefcdb67f2698afc2c63297fbeab2003d8"),
        741158 : buildTxUrl(for: "a979dc83f55d9114dcab2eb5694bbf4fbb84602ceb27af6e287d6af8775d92c7"),
        741162 : buildTxUrl(for: "23278a3c1bf03f20f67299ed0b8dc4d577909d2344f1f02971c8890c6341d79d"),
        741170 : buildTxUrl(for: "db4101f3cccb1671dc1557670fa8b4e64c958008778b8ab1779a4a2969fe1153"),
        741171 : buildTxUrl(for: "74a94aceedb3a22eedb0b5d450487340b3783e1d22ef47af2359c45d0804d9ff"),
        741172 : buildTxUrl(for: "2899ccaea26e4c873a09965e0c268c96a86b1931d896b8622f36422d32c234c2"),
        741174 : buildTxUrl(for: "819009ec1d0cfb50d30c944a41bde545ee631663af39f8a17c31255ada12de13"),
        775018 : buildTxUrl(for: "85b3b64903b1873f5b7578eb2f167752b6a66ba64bb5c4cb8a4d75072219678b"),
        775021 : buildTxUrl(for: "6d69d23c8db7736efdd38090c3cd032f8e68431272964157c52a924315e1a3f5"),
        775267 : buildTxUrl(for: "daf24871749c8360028a19e4d82ddb0d573d7c765a894d601aa241f1e040ac5f"),
        776019 : buildTxUrl(for: "f64378feb08c30b28a90f31e8cd84a932ed064108fb17a3e0aee1585ff994138"),
        776158 : buildTxUrl(for: "9339a0a231f88b3067f3378c7ae70170fdf4246e0e70f442552a6e3961391b56"),
        776233 : buildTxUrl(for: "c9c33e44468c1fa0ee5f9d411b43748f8882915640b3b13c6e48c56e9cdde798"),
        776240 : buildTxUrl(for: "0e1c70fc67d3b9ae29a98996d4363b512d51d7b8422a6fa58f5803bebb247e7a"),
        820691 : buildTxUrl(for: "1948bc40226e53d2652f593ebe4f34c5d81550eeb16fe2ed797b7ef3c1083899"),
        822410 : buildTxUrl(for: "f3f8684be8d77367d099a38f30e3652410cdebe35c006d0599d86d8ec640867f"),
        828933 : buildTxUrl(for: "1fd394257d1c10c8a70fb760cf73f6d0e96e61edcf1ffca6da12d733a59221a4")
    ]
    
}
