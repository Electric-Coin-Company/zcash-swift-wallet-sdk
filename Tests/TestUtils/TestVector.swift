//
//  File.swift
//  
//
//  Created by Francisco Gindre on 9/26/22.
//

import Foundation
@testable import ZcashLightClientKit

/// Test vectors for unified addresses
/// Original file can be found here https://github.com/zcash-hackworks/zcash-test-vectors/blob/master/test-vectors/json/unified_address.json
/// Note: These vectors can't be used as-is since we are missing derivation functions that take a DiversifiedIndex
struct TestVector {
    enum Indices: Int, CaseIterable {
        case p2pkh_bytes = 0
        case p2sh_bytes
        case sapling_raw_addr
        case orchard_raw_addr
        case unknown_typecode
        case unknown_bytes
        case unified_addr
        case root_seed
        case account
        case diversifier_index
    }

    var p2pkh_bytes: [UInt8]?
    var p2sh_bytes: [UInt8]?
    var sapling_raw_addr: [UInt8]?
    var orchard_raw_addr: [UInt8]?
    var unknown_typecode: UInt32?
    var unknown_bytes: [UInt8]?
    var unified_addr: String?
    var root_seed: [UInt8]?
    var account: UInt32 = 0
    var diversifier_index: UInt32 = 0

    static func optionalByteArrayKeyPath(from index: Indices) -> WritableKeyPath<TestVector, [UInt8]?>? {
        switch index {
        case .p2pkh_bytes:
            return \Self.p2pkh_bytes
        case .p2sh_bytes:
            return \Self.p2sh_bytes
        case .sapling_raw_addr:
            return \Self.sapling_raw_addr
        case .orchard_raw_addr:
            return \Self.orchard_raw_addr
        case .unknown_bytes:
            return \Self.unknown_bytes
        case .root_seed:
            return \Self.root_seed
        default:
            return nil
        }
    }

    static func stringKeyPath(from index: Indices) -> WritableKeyPath<TestVector, String?>? {
        switch index {
        case .unified_addr:
            return \Self.unified_addr
        default:
            return nil
        }
    }

    static func uintKeyPath(from index: Indices) -> WritableKeyPath<TestVector, UInt32>? {
        switch index {
        case .account:
            return \Self.account
        case .diversifier_index:
            return \Self.diversifier_index
        default:
            return nil
        }
    }

    static var testVectors: [TestVector]? {
        var vectors = [TestVector]()
        for rawVector in testVector.dropFirst(2) {
            guard let vector = TestVector(from: rawVector) else {
                return nil
            }
            vectors.append(vector)
        }

        return vectors
    }

    init?(from rawVector: [Any?]) {
        guard rawVector.count == Indices.diversifier_index.rawValue + 1 else { return nil }

        for varIndex in Indices.allCases {
            switch varIndex {
            case .p2pkh_bytes,
                    .p2sh_bytes,
                    .sapling_raw_addr,
                    .orchard_raw_addr,
                    .unknown_bytes,
                    .root_seed:

                guard let keyPath = Self.optionalByteArrayKeyPath(from: varIndex) else {
                    return nil
                }

                if rawVector[varIndex.rawValue] == nil {
                    self[keyPath: keyPath] = nil
                    break
                }

                guard let hexString = rawVector[varIndex.rawValue] as? String,
                      let data = hexString.hexadecimal else {
                    return nil
                }

                self[keyPath: keyPath] = data.bytes

            case .account,
                 .diversifier_index:

                guard rawVector[varIndex.rawValue] != nil else { return nil }

                guard let keyPath = Self.uintKeyPath(from: varIndex) else { return nil }

                guard let optionalValue = rawVector[varIndex.rawValue],
                      let intValue = optionalValue as? Int,
                      let uintValue = UInt32(exactly: intValue) else {
                    return nil
                }

                self[keyPath: keyPath] = uintValue
            case .unified_addr:
                guard rawVector[varIndex.rawValue] != nil else { return nil }

                guard let keyPath = Self.stringKeyPath(from: varIndex) else { return nil }

                guard let optionalValue = rawVector[varIndex.rawValue],
                      let stringValue = optionalValue as? String else {
                    return nil
                }

                self[keyPath: keyPath] = stringValue
            case .unknown_typecode:
                self.unknown_typecode = rawVector[varIndex.rawValue] as? UInt32
            }

        }
    }
}

extension String {

    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    ///
    /// source: https://stackoverflow.com/questions/26501276/converting-hex-string-to-nsdata-in-swift
    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard data.count > 0 else { return nil }

        return data
    }
}

let testVector: [[Any?]] =
[
    ["From https://github.com/zcash-hackworks/zcash-test-vectors/blob/master/unified_address.py"],
    ["p2pkh_bytes, p2sh_bytes, sapling_raw_addr, orchard_raw_addr, unknown_typecode, unknown_bytes, unified_addr, root_seed, account, diversifier_index"],
    ["e6cabf813929132d772d04b03ae85223d03b9be8", nil, "d8ef8293d26de832e7193f296ba1922d90f122c6135bc231eebd91efdb03b1a8606771cd4fd6480574d43e", "d4714ee761d1ae823b6972152e20957fefa3f6e3129ea4dfb0a9e98703a63dab929589d6dc51c970f935b3", nil, nil, "u1jttnjvd97hja2fvajcgfmu6w2mcffuzlgfmvepjy8qdhkjmv4pf90dqgzcse23t95yvxaaysh8fu0d6wwjw2x7pxvzgx5zhxfn2j33mgspxlxysdhqafush2awsz4huts5mqz7mffzl09697my7dgl7c48eggfe072aj2u8jd7ktl0vzf36j65cye9ff0erc5n2mgqkjygwnq004a3y", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 0, 0],
    ["314f9bb5a18af9c9f6eeb035cfee3acb111facd9", nil, "435b0bbc95b5b7d52531a3944f2b85603ee22aaf850963bc156eb561edf2cbe7cf0e770e393ae5d7049026", "a9e372a4c8950cf34ae29ccc664564b56cc3030025065fc24da4c00f785e8d1b9531e3ef83a66a4edc3816", nil, nil, "u1ee82x2telrxdw72p4ke636wu2c2p09qrq7mhzm5kccjymh2033avaeh3ttt5s89ez0a3yrgwaec7glvgkyn7xl8x962dza5s6c4q9aspe655d4c3er883dleqdhgxnaxhex2j3z265mly7pf0kuv69mhyh30pm5vnsnq2lwn8hga24a0y52l9ydvg6hda5w23fes6hyasknhumwd8nu", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 0, 3],
    ["3ca74c80ef1d1853423ae2891cd5d0ecbcfde137", nil, "69a25a38699708e5f6e76e54e6a7a2ab84dcf288df0d1f2563670168d6c44ace0ef11155c60d5c225e9dec", "7e243f6141643f81e1e93fda73cf2f64f68de487785370f3021d1940f34bc3ed13a9d9a03baa78e4a43b97", nil, nil, "u1uqlu50zy5q6dtkqjfq92a8fxt3yg9gv6yrj48rt9l0jlxpgdxvddgefct6femf73yv05umnxcf848jr4r8ue37g036h64vk5cwel6sml50w0jeah8fg6awcuj0q7f9udr6agq9j76dza8j3urh6zq7p8t4gppgxsqr2nv3fgrrqv4dhx6hye7h2fz5ppq9m4v332x7767jzg75qe0kp", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 0, 4],
    [nil, nil, "9f6e0bf90a18fc0b9b83ae9f23ad4358648638482b5def8975635b66fd8a708335f9235a3186ec0f033f84", nil, nil, nil, "u1z9vyk0d0h2k2jwuuk2gfvh5p65qsagkwcgqm6lvh8ratkzjau7stq5snlnkl0eutr687f3wcyn8a0m3n3462c0e4t4cs7m3lvumj2ddm", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 1, 3],
    [nil, nil, "e1adf156a07d56bcac91bdb2f7bb3ea7c44569dcfee54273c09e8065807b6823faa94a77219554d0f6e017", nil, nil, nil, "u188xrtf88khrjcd8d4487qvjk3getm6xmex0pvjket5qen35tlzhpmgadkcyccz8q0kp3sxzy4ldgn5n0cnll34s47ymvw9cqfunh53wq", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 1, 7],
    [nil, nil, "60ba572f8e379312d86897025decdd64b4b95e2c4afa9d13726b8cc393edb4988c51b976028f890f108bd2", nil, nil, nil, "u1jn6752r2s080uhf8grhdnnkfzrgfcyv3tu45f03rzcgheqpmxj5wuvf0v274l0k5ehvc763epv6qxnsv6t04vcn66h0sa2c8nsnyy2f3", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 1, 8],
    ["aa6d43480fd9d91375ce6c4a020706361bd296de", nil, nil, "953f3c78d103c32b60559299462ebb27348964b892acad10482fe502c99f0d524959ba7be4f188e3a27138", 65532, "cd8dbf69b8250c18ef41294ca97993db546c1fe01f7e9c8e36d6a5e29d4e30a73594bf5098421c69378af1e40f64e125946f62c2fa7b2fecbcb64b6968912a6381ce3dc166d56a1d62f5a8d7551db5fd9313e8c7203d996af7d477083756d59af80d06a745f44ab023752cb5b406ed8985e18130ab33362697b0e4e4c763ccb8f676495c222f7fba1e31defa3d5a57efc2e1e9b01a035587d5fb1a38e01d94903d3c3e0ad3360c1d3710acd20b183e31d49f25c9a138f49b1a537edcf04be34a9851a7af9db6990ed83dd64af3597c04323ea51b0052ad8084a8b9da948d320dadd64f5431e61ddf658d24ae67c22c8d1309131fc00fe7f2357342", "u1uwdt59245hh0y324zds9s4knmw3q450qgm4rhmyzq6x62uxerpwtsnmqlp25w7w79c9y9qez6j072krjvlvg9805a4hj5mya9k8h35kauj7cmdg3hqnmvqeaa0sfgg95qpd6k7mrnfxpp2zl0kq7z90wyr8ptmgdnq3swem4wken5pwr0vdgkvylzfzwcr2mesef9j9pd9frudzgdm392uvlh3nhe3vvlwkd4nu3tm03gzllae9dn0n0csupewz95z96xnauljwyc3crw34d2zftcumd0uadz0rlj24ax4svvm6y5ga9j363k4a996dh3h8dz769gekf3jadx5kwwf4eckfvkwn7lf04rctx7kql08956xz036jyrl2pphlwjn9xyprfs04ug3p0z92znkv7yf53hn0w63elnkwjl5u934lck6f5q8l7wnrlcly62utckyew808judy8lnuzrzfmd9r952v64p6g0g88s8n5w2wgshp4l58vssndy3rltlhw9y4r9agykflzrw0dp0w2yajnucnx2rd", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 2, 0],
    ["707aae9a13445677cf7d7cb394b9a883f4104018", nil, nil, "88391e4e038ca9e15cc38624a64552a99f07be0715ae2db4474234e946e1b6c6b6676e5cf7b25d90593e8c", 65532, "76d38d47f1e191e00c7a1d48af046827591e9733a97fa6b679f3dc601d008285edcbdae69ce8fc1be4aac00ff2711ebd931de518856878f73476f21a482ec9378365c8f7393c94e2885315eb4671098b79535e790fe53e29fef2b3766697ac32b4f473f468a008e72389fc03880d780cb07fcfaabe3f1a84b27db59a4a153d882d2b2103596555ed9494c6ac893c49723833ec8926c1039586a7afcf4a0d9c731e985d99589c8bb838e8aaf745533ed9e8ae3a1cd074a51a20da8aba18d1dbebbc862ded42435e92476930d069896cff30eb414f727b89e001afa2fb8dc3436d75a4a6f26572504b192232ecb9f0c02411e52596bc5e90457e7459", "u1c8qg4struvf8gm0gulzg25z30uxjxxcj2cmcdl5jyamqjmgdk85flag2lw7kjdptzaqkv04kjypyvga4vdmedw7y298h7e8qhp7qkdc53qmnt4k77cym7gnyhsz5e82cgkvfnl3sghndsnjcfnrj2w2n9x7p949x5mmxjkhpvs92zyyvf0zx28d093t629sl332aqgpv4qp9m6ytaqr6av6wy6l0le2n20z6ck6akd7276ql8cv7thzqd8nc2uyz9pedqywj90nmlymhkqk8pzjvauqfmnly2h6ezgwwv4utu4njj66y85ysamkm3g35wjrqkytad343uysst406pyr6y2asa6t9pzznpzf363hqxv8u34sccaafrrqpklrq7ejpv6nawvm425hxt0np3x7nwq4cdvjwcqghrq5c7pc4lddxlgdgv3ujlm5s5d6ss8f98hk99vkqw27jl2clnpz382htyccncdhp40c4xvm48glm3sr2nakfqm0twckzcuwenq96768yu04wprp3w6ayhsf8k9cshpj", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 2, 1],
    ["21e2c228dd8bad8816a407c18ad7987d1a4f0336", nil, nil, "251dcb7e5a988146d9cb52db9d7f81de1eb8ef58ee08eb4ec4810a23be8f4337790a99bfba8e364aa25b8d", 65532, "39ffedbd12863ce71a02af117d417adb3d15cc54dcb1fce467500c6b8fb86b12b56da9c382857deecc40a98d5f2935395ee4762dd21afdbb5d47fa9a6dd984d567db2857b927b7fae2db587105415d4642789d38f50b8dbcc129cab3d17d19f3355bcf73cecb8cb8a5da01307152f13936a270572670dc82d39026c6cb4cd4b0f7f5aa2a4f5a5341ec5dd715406f2fdd2afa733f5f641c8c21862a1bafce2609d9eecfa158cfb5cd79f88008e315dc7d8388e76c1782fd2795d18a763624c25fa959cc97489ce75745824b77868c53239cfbdf73caec65604037314faaceb56218c6bd30f8374ac13386793f21a9fb80ad03bc0cda4a44946c00e1", "u1q3vrqfexveqh2772en0ynkwstt62sqlyvkqzn8kr2w4hnpqy07d7l6qxzwwuuv3k040c5t6haqkak60km9l3c7hzd6y5ycednjep3c7puknhtlmp24adyduh02zq8kw3mqm4vhzkzc84tmsv9h2rpp6jf4xqpw2md4jrmrmuklw3zv50ajr2gxkgk6hxq2szymsmykvzpvwz8rt7zekzqakurrmrvnezmvu6h5c6gupp275qc6lrl57rg9pwvg7dza37c3ft569gnzhjz7f9ujvm8799nrc7nr2udgzcaphyxmrpzrzhzqpdqy28cqzdsay467fjtexyn24mqlzjdqwsylj3sqaylfy0hu8ezpt3q4xlssq7m6c0c0706w3mf7ed9nd20209q0rmxj75rya62gxcu5r2nss8vtdq8kuk93t4dvrte9r587zy37ty998njtmwk7s5vzeg4ugq07ea0ffdzjpf2zy84ccwauzkrq36z5vm72qwptvn3k47kurxxs0ltvrq262d0hfrmfp9ecpys7eewqy", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 2, 2],
    ["235fd68bee8f799114c9e7cb8ce3c01f5e442a58", nil, "52fd6aedefbf401633c2e4532515ebcf95bcc2b4b8e4d676dfad7e17925c6dfb8671e52544dc2ca075e261", nil, 65532, "8cc3d14d2cf6556df6ed4b4ddd3d9a69f53357d7767f4f5ccbdbc596631277f8fecd08cb056b95e3025b9792fff7f244fc716269b926d62e9596fa825c6bf21aff9e68625a192440ea06828123", "u1v8dtwgkrza584fj3jv7xvwm0paf3fqelt972s9kr3t808tj35gfa7lsnfpzjqgedkcc7kefrtek5nhpv6q6ekykua0eusve549crkm9yhjzrq3yqqk5wve684sjwazkztk4v4nupwgl4y6xyakysdy2p68msjm5tla8hsadaw4tmjrjzmwlm6u4c8z0fjaxew6l52qfl4dt5hqwz0wx82maek5wys7k7a0rjmh03ykgjsaphmz8qz62dpgvwl4t7pfzk4xqlvy6pk", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 3, 0],
    ["cd7c11d41e1f9db7c3fac7b01fac2d81a20a0fb0", nil, "78ba60804b822cc7e970b11a96b5bccbda556a7c26f0b082cfcd9a68e2690017771c4bdcf8f8bad3c8591f", nil, 65532, "d97884806f15fa08da52754a1095e3ff1abd5ce4fddfccfc3a6128aef784a64610a89d1a7099216d0814d3a2d452431c32d411ac1cce82ad0229407bbc48985675e3f874a4533f1d63a84dfa3e", "u1n6trq9cqde5vywu6zl4u6ydhg4k39nh3ymtvecnvzlv0crt906t97uxmxdqjxcf8uqratws4l0g6q4mjr34u77pmcle4224n35tq9ge7hjra8j2e88ggveqfmw9mdrrgcftu0p5hjmjf89fzehug6hng3zyktmmk0y9jyespq76s2l3sh539vk2v8h8aykqa2k6mmpmkza4ngpds7l9h2vf9nhfkhmjlysc0nsrq3y0qvfma8g3ad8efxwy8hjsgjyy2lts6muf3a", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 3, 3],
    ["a257c2f326ba0eccee803c2867e91779cf93ef19", nil, "508942b74eac2ab8e9868b06c95b30a6b5a56c35478b3b05460fc9e63217c22259ef84c23c0f29f877be4f", nil, 65532, "0f460fe2f57e34fbc75423c3737f5b2a0615f5722db041a3ef66fa483afd3c2e19e59444a64add6df1d963f5dd5b5010d3d025f0287c4cf19c75f33d51ddddba5d657b43ee8da645443814cc73", "u1q26wd9e3vgsepgw9748tvsktlq0jqvfr59ul4fya0tn56sss7yv5emkq348yr7hawdazngph0elatc56t6gz72lhjh8dcfrfkt6kamsf664w7h354rksgar90xt5h7axypgej6rudw8c4t0nchklst05hamddf67r5gkzcsqqz6a8ugjtl0ur0rlywfe8pmqju97s42tslaaygj0mnyu3xk3g2x6e2jezyjfwpqxfysjf0q8a5xcex26qpdwzsyc3smpw5cahgjc3", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 3, 5],
    ["7ae2a0db6781b6db28ebeccbac16f39ed3e5e4cb", nil, nil, "165082de84f2ad7204426ffafd6b6c7de9cab6d25c13846a1786715268c415948db788f4a5e0daa03d699e", 65530, "86a2658e0a07a05ac5b950051cd24c47a88d13d659ba2a46ca1830816d09cd7646f76f716abec5de07fe9b523410806ea6f288f8736c23357c85f45791e1708029d9824d90704607f387a03e49bf9836574431345a7877efaa8a08e73081ef8d62cb780ab6883a50a0d470190dfba10a857f82842d3825b3d6da0573d316eb160dc0b716c48fbd467f75b780149ae8808f4e68f50c0536acddf6f1aeab016b6bc1ec144b4e553acfd670f77e755fc88e0677e31ba459b44e307768958fe3789d41c2b1ff434cb30e15914f01bc6bc2307b488d2556d7b7380ea4ffd712f6b02fe806b94569cd4059f396bf29b99d0a40e5e1711ca944f72d43", "u1qtww2cneawwdu5v9rqt4dm9kwn80s2nztcwcpeqz8jagey04qnate7r8j6zu9thm97ldtn4qdl36vlpn8lvy3ljk8s37kr9pgkpqlmlla9vhh9j6wucqwham9zddrzu5jl9g8jav3rdx560ft6cr5c7j2p4gqp88z6y4zmrhszssnss839zfzkn34h5ttrtg6tuw4qdf272lhqns2faylkykz2yed239tehndaruw4v93rw04yc435eke3m7lczed935zhtasdptyjw0rd5ulhdg02rnqhltk43s3d2jgd30xla8qda550tlkmtg2d5kz3amvtldmzl7w778we2zq8ynfny4v6g6us6exvdcc4qsgq3esw3fvev5tycpyhk4srvj4u2haw4m3z37hpaan5y2k4pl53hdnd2je8ejcv5ka3a34c5xu7zxd3nydf4as5wsl7dpzn6zjqkl4dcs6l3cyzl5n6z77pn7d043d5egu4tcrg2suh9l0rwwz8enrqqw2c70q50n3lt3rgl2m3cqevdj0srv", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 4, 0],
    ["f45861cfbb22c49f51c40a3cde5c66c0d95bc413", nil, nil, "c906109b51e2b37bf8b67761bfa917dc5059c357b7dc8107672b66189a0d15bc496d84ef9114c68c99c911", 65530, "6a102fca4b97693da0b086fe9d2e7162470d02e0f05d4bec9512bfb3f38327296efaa74328b118c27402c70c3a90b49ad4bbc68e37c0aa7d9b3fe17799d73b841e751713a02943905aae0803fd69442eb7681ec2a05600054e92eed555028f21b6a155268a2dd6640a69301a52a38d4d9f9f957ae35af7167118141ce4c9be0a6a492fe79f1581a155fa3a2b9dafd82e650b386ad3a08cb6b83131ac300b0846354a7eef9c410e4b62c47c5426907dfc6685c5c99b7141ac626ab4761fd3f41e728e1a28f89db89ffdeca364dd2f0f0739f0534556483199c71f189341ac9b78a269164206a0ea1ce73bfb2a942e7370b247c046f8e75ef8e3", "u1qxhqghcyrv0vunc0qgdqlm45ftmahunlu8jwstmqmrptgam2ddw7nz3dcwmc93pzjqn3vk24acxtzdvytpnr4hlukkmnmhe063342u24wr0l2td6zdgwe06cfun4u2sa0ml00pmzdz3fhv079yz3jwdzq26hj8dywv0ml90xv74mljuvdc3apv8vkp03xlskc2rcrrfz4c6jazjjschses08xpxd088yl8e2aw0gg7arlfwletk4ruwam5qvmwz5drhe70kmwd38637y0zh2q7ayl6hunrgvqyyc42x28ewk7tt23lul4wjkl5g0w2aqz8p3jy62zk2e5vemd5sxeyudcfq3u3a5lhahl230adlx00z00tnx5kuwmgk7mf6ylylep76q9j6642fqg3y2svckg0nwxgadmtyyp8pwgltd7rdv9wefzwd2rywpu9h33gwq4s07txgjwwadmgs27n8m93ndr8vljxr74xr4n8ghveumzh3wnya7etkx8a49dyuzm0xvugsh5ejk8qggm63xv5jc0le5", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 4, 1],
    ["2456cac075428d24707af7de2fc610c833831bdb", nil, nil, "7cd065b0ab297fb7fd701291d03589031fe3aadf1177902e5bcb65b5ba0aa2a0b73f09734f0b867b29763d", 65530, "f8bd821cf577491864e20e6d08fd2e32b555c92c661f19588b72a89599710a88061253ca285b6304b37da2b5294f5cb354a894322848ccbdc7c2545b7da568afac87ffa005c312241c2d57f4b45d6419f0d2e2c5af33ae243785b325cdab95404fc7aed70525cddb41872cfcc214b13232edc78609753dbff930eb0dc156612b9cb434bc4b693392deb87c530435312edcedc6a961133338d786c4a3e103f60110a16b1337129704bf4754ff6ba9fbe65951e610620f71cda8fc877625f2c5bb04cbe1228b1e886f4050afd8fe94e97d2e9e85c6bb748c0042d3249abb1342bb0eebf62058bf3de080d94611a3750915b5dc6c0b3899d41222", "u15g2qv6nj2h46z9wkqxvj584lqejspg8rv4a4djpzdll9mz3fh36c54qhwgpgdrh03s6ehzdpx87pfqvcd7hwl2m5clfl9n6fcfj07pztsdttdxy5sfxx0dnrug38yders826wh5x64fq2sac2q40g6sk65a22wt0fmg8pvjhrel98f4jtxf4yg2l2jkr0aw0lng2hhwwzme7yzm5k5sxeys83hwwxmlum04z374za20zr2ghhty5ada5qpv5ry9ht6amrg2mfn8vf8emr84ng66zf2e48ymdfc7hxdcvmaly7j7kg5g27a42vgrvs5w7m996xmx4vtv924nlzcekpjgkfskn677muv6u0t8uqmv0q2hzdgvk6p0j39zm2u6vyct2sf6vnq24crgy3zfdg5v2tmwv5vtyuq8sdu7xjn9yuae4gtfs0ug3ryhujq43azve9t9zmm6pccxswxkwfexvzpmn8xrfltdfmgex68y6wrd3qwd0sgp0p8wxf6eyup2ydff2ytxq4ehngt35zeh6vv5u4t3r", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 4, 2],
    [nil, nil, nil, "ea9df83fbee07d6f7895ebb2ea41ec7c4ba682b863e069b4a438e31c9571c83126c305d75456412aeaef1b", nil, nil, "u12xugd90flrkdkeu3nlnn3uesky53pqu5m24y6apxm88m48v7374cls56zp93naylaxdchf0qayfxtrge047m953qz3v2gr4ltsr2sk3r", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 5, 0],
    [nil, nil, nil, "fd3e7eccdb1a91f2c4498bb7eb61cba83eca499cfde9c5ce3e3241873bad2e423abe91dece0a6930e8901d", nil, nil, "u1kffwpljstudp6rmdmdtfc8h408yf983qyrnl2pfsymapqsrsgznp2qnh57mzlzdcmecdgd82repec6zfjw874w5frxrw73na6sj3m90t", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 5, 1],
    [nil, nil, nil, "5ef3c8b2bf2a8b0e60a6254f312229b4124d4787e7dada5d81e16b51211707871bede32811a35f4094ae8b", nil, nil, "u178uk6ed50uezamsthlls26qxwpj0hlv2nd7l4wl586x7y9zpzvmnjgwrx7f9j260ny5f3ewxxasun8zklw4schlmh6aw0c5epuuc75tg", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 5, 2],
    ["7ddfe9c9b7d08ed6bda0bbc2be4030e04679d59a", nil, "1cc9bcb1a50880e4efb08e6e5a49305d358d575a746a51fe0db5a96b7eb39bd20744dae185061819fb7967", nil, nil, nil, "u16u53z44ydps7d5kmx7wyt3cf67z8rpllvmfgcsj3ra0uaxwqm033s3xfczfl3l78h9d6th6p2de8t0dqkad4u50k3gsalvwlwrwkvf3px7eyzgsvz83sfdhg79pfgxhgnl0hz03vx36", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 6, 0],
    ["150a17d8f88608900ae24ca27046fbfa082940b1", nil, "ac093a82a7f4a5ab66bcc994bbfc5b3f5f945f4499c5d8987f6404ceb4a91c46320b3618c318d80281b285", nil, nil, nil, "u1vl86hhk6wtueylzh72tksuh5pscamttzzkq7f3vnq6stg4u63zwmwndjul9jfu8g8ns8hu075f09cvc48j456048rtcwueka866v7dx3088sth7c59wd3jvh0pfc22s9vtkjyknhtgv", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 6, 1],
    ["133341e730a55e80e5f7a0bbf468663835f7e0c8", nil, "7198a7b9bf9099809a63bccbd56af56744ea2857ac8d12892ad58d82fd5b0cce71ea7a25816007c34491ec", nil, nil, nil, "u1uhuw9lsxpw72ejrsgeh8rrztu7cm7h3qjyawyrgcekgn0f277msnlyqgysu5986ew3z8a2g0lmvcf36dqq7wguy7gvnteprz4qn8qkwwfq2pxeyukyn3v4tl65ptkjzul8lpv32lxly", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 6, 2],
    [nil, nil, nil, "cc099cc214e56b1192c7b5b17e958c3413e27fefd553380700aca81b24b2918cac951a1a68017fac525a18", 65530, "942bfc9f4fd6ebb6b4cdd4da2bca26fac4578e9f543405acc7d86ff59158bd0cba3aef6f4a8472d144d99f8b8d1dedaa9077d4f01d4bb27bbe31d88fbefac3dcd4797563a26b1d61fcd9a464ab21ed550fe6fa09695ba0b2f10eea6468cc6e20a66f826e3d14c5006f0563887f5e1289be1b2004caca8d3f34d6e84bf59c1e04619a7c23a996941d889e4622a9b9b1d59d5e319094318cd4", "u1643kh4y642rxtsqa2pvmjnkch8ex0z3u5j8upczd4vgl8wqh0whpyu5cssjuyp4pf2g8mvz7phpuaj8zakha7qtzw6ec9hpczwa5n5zu88ylfxhysq3xpxtfemprkw2j4w78n6q3x4h2ty35cfgyzk7aduzazav4rg4y08du34kr5kdtg22plumma5c2xz3tzksr9et8wax0g647xrrmqqq29ryx29fet7xhrj44zz2qwfvmth0hcrvwrynd7m73tdf9sq9fkfm8g850y4l37ycw7eet48y0p03vwhzdmhrcnag670ctvfehsfs4kjtpssr6ayrvjuje2ftmgzyhgpgwgn2q6m9uv0", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 7, 0],
    [nil, nil, nil, "3c025e3e717e185a77c29ef372b6e7c3b17c459256074fef6e6cbe321cf9e0886a82598867b979de1a7da1", 65530, "05ba27b7e2c084762d31453ec4549a4d97729d033460fcf89d6494f2ffd789e98082ea5ce9534b3acd60fe49e37e4f666931677319ed89f85588741b3128901a93bd78e4be0225a9e2692c77c969ed0176bdf9555948cbd5a332d045de6ba6bf4490adfe7444cd467a09075417fcc0062e49f008c51ad4227439c1b4476ccd8e97862dab7be1e8d399c05ef27c6e22ee273e15786e394c8f", "u12h7pa43zagukq40ndvujxsw2t3ekgzt8xfk4tkdn0u5mckfgg8nuxxwjf8xlwehgsg2zy2hesc5dm2mm2xy20rxkcw89fm37wz73xgp5amm9ccpczasmq4qhp2gnjgj4yxxpxsxtrjpgvssguau0tc7pdyjm6hh0843zk9cmmu60c5ckuaj7p585q330pd4dukpmseu9havskyhda6zcd58kc4dfpkpl24gd4y86z88kgmka6nx3y5d8ndmvwyw2sl3gcedrfrwphxm56q5dkg2amccs84egjrhnlfz2sanvydpn2y808u4m2mrh3vu4xcccg6v6y2uv957ja3r060cewkjs25ydd5", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 7, 1],
    [nil, nil, nil, "cb1c888234bd7f9e6bdbc2178bd32c2fb0451384027975e83f71a98871a290f3bf43c94be686c77b12edb3", 65530, "1be31682a30147963ac8da8d41d804258426a3f70289b8ad19d8de13be4eebe3bd4c8a6f55d6e0c373d456851879f5fbc282db9e134806bff71e11bc33ab75dd6ca067fb73a043b646a7cf39cab4928386786d2f24141ee120fdc34d6764eafc66880ee0204f53cc1167ed20b43a52dea3ca7cff8ef35cd8e6d7c111a68ef44bcd0c1513ad47ca61c659cc5d325b440f6b9f59aff66879bb", "u1xsvuwuzm254u2rycpckqsv8hv592jktdf9cgadxp4j82mvhvh2w6k4d9lrdp260gm7lkspekskgakujyunywqv3g0kzd72e0pwmdg28ykfhjnfvr2j066cd92yjk5xjka00dmsf0kax5zdcgyknu2j7s84x7aeue2x97705ydq7s00cuntwft5cv3ejzd4whp4awcr9vsuhfjrqlnkjyk9v6n89jg57umf57fnace7z2ysdjqudcfwwjwp2999h3jpypa0c5da4hh9t48p7gxd6a5cm4xkwmddmspmxazm89s7p4fa425n0wrlu6gnf9xy4v89wt03wwtcs7jmz3zfz9nk3s9ldymk", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 7, 2],
    [nil, nil, nil, "5f09a9807a56323b263b05df368dc28391b21a64a0e1b40f9a6803b7e68f3905923f35cb01f119b223f493", nil, nil, "u1cxccyemm08tydwmt9hp2s5nf8wjvluuu6l2e8a9jflldxasnzkd8fverqpcj0xnvraczqg255cw5nvy6x9wruffmp9uezrzr7gcx559k", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 8, 0],
    [nil, nil, nil, "21006cfbb3db4f4bb63111ef63f7f80056f31b344d06aca5b7fa0740c660c8b2dc3bd234f4c18ae9eaf811", nil, nil, "u1e38h9rl45mryslydy7g4sjh4wqfql54ay6mk0hj78pay5p3esnz3kmk7sqfyjgpla5yrwa9h6tqy9y6earefuhq69n92sgq8que6mlvk", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 8, 1],
    [nil, nil, nil, "04915d2bebce11111ce195226cde8440263c50204b2272ac8a96b38dbd70db8969ec9b6c87cd15d9d76512", nil, nil, "u1clspfaz7dswwrkl0vlp4gfjmprmsvdjyq0xewwldt8rfw5yy0meqqscczn74j3n6rpgucpk99mpf7gfr87yw99tum7pz796kpyjk97ml", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 8, 2],
    ["6b94c815d9cd2ac0cca4ff8bee0cd5175afb0d72", nil, nil, "e340636542ece1c81285ed4eab448adbb5a8c0f4d386eeff337e88e6915f6c3ec1b6ea835a88d56612d2bd", nil, nil, "u153s0peymew62a299k3nw437h57nyqgw28art0q7z5wa7lfp62w3czu2njsc4lma48kqlp889fh854nmhlpjyzwffmrdc0guj082jqef9knsvuwjc4mkypf0nqgydqsu5wzcy77255ev", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 9, 0],
    ["53a89cd8e8b635cd4c4b39d4df0a035d045c50d4", nil, nil, "3fadf8edb20a3301e8260aa311f4cbd54d7d6a76baac88c244b0b121c6dc22a8bcce15898e267829fc1e01", nil, nil, "u1fdsfklmddxv2uq6ypsz09vf28vyldv4qen2spj0lrzdl0jv38pdk7a6ju3806zdaghwaway62nvuhv98mwrfd4tdn7tu22eq4ma7emq5gajn7tuy7dxradjkzeeust0x7h7pvcfyhus", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 9, 1],
    ["972085f9e6a02aabb3c420f0e4e7c8c3267a00cb", nil, nil, "987fd74a2256c596a66f83eaff7bb026286e972be56d3b50e3459747dfba53ffa0f24732b4aa6cd437a317", nil, nil, "u1uh2cdr9mqewwzujfwnnf49mczesvmprjnqrk6yjqfvwshlquq07p73y43tpdha04fjdz6x6plneqz5rj3ka2tfr83768kglsn5a53u278sm9nfjx42ev2feht0e2tsczedw2z49m8uh", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 9, 2],
    [nil, nil, nil, "cdf7fed0d0822fd849cffb20a4d5ee701ad8141e66d81ddfabf87875117c05092240603c546b8dc187cd8c", nil, nil, "u1sj55qey22hefwyz6mnc3ldz7fcnkg9536uk5e98rwznvvald27r2vzmeupya5u696l5j0w6f5fdxkf54yvyhy0xze2u2wa2zdv2g67u2", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 10, 0],
    [nil, nil, nil, "a6aa4fd8937382812c9e5b333f95bb440e290f2e2dc6b9978298d88c277b85f7dbb4ab9d9788479b75ce04", nil, nil, "u16d6remztx7ezmgfdvcglv3w44cjdmjapf0jz6wgldj49p2a7269gf5gzpun597mv50d3h4pgetgznawjdjvaeuhqgx6qzxk09qq48qqf", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 10, 1],
    [nil, nil, nil, "e4e01051b99c08506834971f80dadec44a4da13ecdcba617f77fc48d25324f57cb1d4d7424705d573cd682", nil, nil, "u1wyge9pna2zs3qwc27uvu6l0cf8sxtrsr2lpfkdz8g6gxhxlvy48xalk5xapwawrwer8vc4weha25cxd5vumzj9yyhxrhzuzkz5nw5u5d", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 10, 2],
    [nil, nil, "0ba97e749afc9322db91f262fd8d2872f05f09de246b1f9068abfd25f5165da1a05115c6f4784d2b922a3d", nil, nil, nil, "u1e25fvhxh3hcqd9424am3pf20fvvvzjt4445lpk03f40d3xxjc6ppj5wn9lt0ru3zvnpt5q5fkhw0npgnu9z2en9l65xe4fqdxq7t4x5r", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 11, 0],
    [nil, nil, "4f9e8b832971ce3bd99a2a1bd545fc258921fb51abcf8d2c00fcca7e9d2888fd60ffa31716786f1bcd4226", nil, nil, nil, "u1cnzmjsp3nl542nj73ezrvtll9ss7gmegjyuz65q7dn8wlyj99lxxzvy807t9700pesc5554a2egnx2pet6s99gllt2dzcsqn8sxvdwcr", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 11, 6],
    [nil, nil, "314da30f32e4899d14d64212f70a10cfb60f541da1bdf72323654eefb75f1bdf4fccced2a4aae90e54e7e5", nil, nil, nil, "u1l9d7naej4k7pkm6f89rqvy9uc5q5rv70e78nyjtyt7st4hgyn9rj9we49amdjmg44s0uxmvyc6tq407phcexvwayc5jhts4trvs5uzpe", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 11, 7],
    [nil, "4686e569d58d99c1383597fad81193c4c1b16e6a", nil, "6ed96d65379d5ece656901f5cb20cf554ce18600d4a1edcf6812f4459d7ff73cf2b88cd8476b75e8c08d28", nil, nil, "u149cwhzqdfvattu3dj40anwhge8z4slczq3wyf8m7qqp5uvwdsd5c3d3m55jltnzp0twl34p20mcxkuygvkwdnffuq7vlvl0l2mwlc502czdcfzwndznkqev2p703es0t82aujtdzcgk", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 12, 0],
    [nil, "4686e569d58d99c1383597fad81193c4c1b16e6a", nil, "b6f481042a780462ffa96f81e1288978e5f05c791587de7e957729bcac6eb95892532b0fe13e9c7eef6a24", nil, nil, "u103cga223qevwyyq9wcdj34ngg2dmh30r7cwcgykjtyuu4kvm6gdye0dh2rkj8g7evq5pauzl8z68jrwn3wqjhcn6tkh058587u92tr6ufh8l4sfpzdmde32x0q28rty6e3pa2fkz5cv", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 12, 1],
    [nil, "4686e569d58d99c1383597fad81193c4c1b16e6a", nil, "a8e557a58a1908eb8a1bb078b77a95c032fe0a0069ce8c89d3e7705a48d2c08f7b604e5af0218d8cc9c8b8", nil, nil, "u1encagheqh9gl7n7862g0z73fr2nsxzh75zjyyqsuynm03s7pat5se3e0xfpxy8mye9hknymfylzr03mm2h9z4wdpu37fzf4cfmprq6gs2x6xnzwjqtswh39tv0xt9953pam76jh7jxw", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 12, 2],
    ["33a6dd87b4d872a4895d345761e4ec423b77928d", nil, nil, "5178924f7067eac261044ca27ba3cf52f798486973af0795e61587aa1b1ecad333dc520497edc61df88980", 65535, "952fbfee76af61668190bd52ed490e677b515d014384af07219c7c0ee7fc7bfc79f325644e4df4c0d7db08e9f0bd024943c705abff8994bfa605cf", "u105s6j4gpnqtcwpnxl328kea8gf5jrvfw6s4vkjqz0pxnv4963d6l670hhyw5ugl3ydcsm9c3jzhdpn8v23j5p7n9uhn0sp774azjvzx69z9r2s0axl2pflhqdavtwcdrk3jzps9q35j720exual42phm3qyw5kxvdk77p8ug68w5dmuvr5lueu9dk02u84z96ecnc0ztax5atv9qcsedtafa4lex8jrdv5y77v5gtuk5p2pa", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 13, 0],
    ["eb1f66b5cd522c4f6a8e4bb81f3687c95c3939ec", nil, nil, "907639193311a847366c1a43ebaadd935a53180fd3e1219c07c8205f45077bc1768abdcf2425a4a13c4aba", 65535, "bc7ed746a7d3f7c37d9e8bdc433b7d79e08a12f738a8f0dbddfef2f2657ef3e47d1b0fd11e6a13311fb799c79c641d9da43b33e7ad012e28255398", "u1g50gam98jf3xvc8k0d7tcp2wkaxsz9qcmrn6nh3sjqypqcj0mjemdq7mcu5j0mjqduvxj37apk339zh7u3s8ckpkjvqalajeju4ht2w7xnsgy3max0n52dk4nknfvkxy9de9h37fa5rvljm7t0t5033x4pwhklkhgjradmknuvpe0e0z3urxh7cuj8l49tccc3760f8q9nsdv0ezp22vpvldqz9tu4rqjv62thc0ssrqxakn", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 13, 1],
    ["a9e21d18d3b8abaebcc89e7b6ab02def8ee7954e", nil, nil, "2809ddfc7db70c660a6c3fc7560c7add1c7889d9b277cb92d14cb40d2de00aae31670b753a42bdcdc3c220", 65535, "789262275f1175be8462c01491c4d842406d0ec4282c9526174a09878fe8fdde33a29604e5e5e7b2a025d6650b97dbb52befb59b1d30a57433b0a3", "u1285z7wyv8apqxky4hmagy9pu467t0qjhn8tsffjkwu0cduhzmwukwg5702j0mrmgepmekcj5tzd9e6dcyw79xeuhu3jxlaq5p7smeerugn8xddw5l32qstklpvw8f94mapx3hge6tcyukpxa9sdd2at85sftn5097snusewkcs2hz0m3m4chneym59k4krrmaer3wchlwzfvdxw87tsahdv5xjppks5dlm7m3f4ppykud0uy", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 13, 2],
    ["a56c057ef71dab58aa90e47025695c5faaea5123", nil, nil, "b208c9235c8d40e49b76100b2d010f3783f12c66e7d3beb117b2c96321b7f6562adb4efc144e39d909e728", nil, nil, "u1m83339wch8a7z0u78cnz37hcmc98q2lv8nmgmppnanvay5u59m4qym30fyphvnq36evezky5j9fa0eg9gxgfv5nr230uuggvltp6y59t5jxcdlq9q873j35n06zphugwchgwgeaq884", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 14, 0],
    ["d1dbe863479e28f55ad9dd1817d57f253886f310", nil, nil, "332f451dc6f7da17fe5ff4077d3d5db79a036e712df558853d4a854ac4f6e51474cf75f38fa97c22b4cf09", nil, nil, "u1w4qq0ycdlcnat2nkhqcq30wa4shnat0avgcf487t7etge34x8dxqah35drfsh5cmynqumnhdn3h0hhv0d738mskln0hlehph924l83wcju8qjk79pn4q29dp6kgcfvka0mcw6a4vm4k", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 14, 1],
    ["0c2af13bc82480607ea4e52412029bbbce6bb060", nil, nil, "3b68c29b4a138b289fea8b6795e64759a7cd7c0aaf4bb98ed3079959b0bba9b761704b6cfc1465ad74bb05", nil, nil, "u1aujw5lwjlajnysfmjyewn0c2qeann0x4l34axhxg0nd8pvlzglzg00c32jq0urgdc7cam05fte554lqn8wsecpc4pgm8nk5c546egpjwuw262mhgck5dxfrfwevpga2m66u9qskynum", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 14, 2],
    ["228e677b0b428bdbfa4fcaee0714c81963760585", nil, "eee19641bc6b802f353eb793f728b17a277ef0358696a24a7122bc56537b229647f3810d27ce45227c6f39", nil, 65535, "c447586f69173446d8e48bf84cbc000a807899973eb93c5e819aad669413f8387933ad1584aa35e43f4ecd1e2d0407c0b1b89920ffdfdb9bea51ac95b557af71b89f903f5d9848f14fcbeb1837570f544d6359eb23faf38a0822da36ce426c4a2fbeffeb0a8a2e297a9d19ba15024590e332", "u1u5kkc8lggdf4dgg9t7qg8vfpd06zvpcetq34rw55yg329kqrclj99atez0hn7jtg0cw5qh7jxewees0ynpv2hlkhtcpgsjjm22zrh8hn8j7uddvrwt07dwqfwh7mqkft326ft4y038s9y77dentqeynw2g6smh7s0ceuah6lylvxj07ex474u2lsh44m59gep2wywskwt54wx299jsr0h7rn9z6vhp59sxf5ey8qczv5ck6d0czkupvua6kcl6h6n3ssqvcfueh46xwr07clhexdjax9l45turlwxd9s8xc5c3nczmd2uyseut2zrra3kg6sucdj", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 15, 0],
    ["55a6349abd9eadcdbbcd337c71f09723b241beee", nil, "50ca46f825f7f423007aa4147169b529f07f1c8ed634fafc8145a4813177dd1257ee8d8fc5f44e9b564f6a", nil, 65535, "9d9fa9261f9938a4032dd34606c9cf9f3dd33e576f05cd1dd6811c6298757d77d9e810abdb226afcaa4346a6560f8932b3181fd355d5d391976183f8d99388839632d6354f666d09d3e5629ea19737388613d38a34fd0f6e50ee5a0cc9677177f50028c141378187bd2819403fc534f80076", "u1pcqreshyawlmmskegkjvulf8xk6h97nxckx88aj6m88qu2zeucf4kywfsz43fjrce6w4w5jv5e28n430z2jlj9vfv5yrs5cudx3qv8p7d9jmx5vhayk9a8gyl49yfjp46t6c7d8vh5jhuu7llfkzt2gswkvt2368cpjc0u8u2sgawtgzu07y55raunrx5n48v3tuzpwv8273tnrunh40yu3gk98zhg0pmjcjg8c3tf3qmnfr8zm93eynplk4jx7ypev84pl0yxhk5ckq8zr5gv267skrmcpqgngpnrn43hl9awe7qwvzhds7zg6qtfp9fggpnmvc", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 15, 2],
    ["f7b2c94ce3ca21526b6b472d3d5611fa98bec498", nil, "c412c8ff78f28d9b3391f4ab15d06acf46ac052821ee096a51524813f2adf9a4065cc6c45feba2c052df9e", nil, 65535, "e9380cb4964d3b6b45819d3b8e9caf54f051852d671bf8c1ffde2d1510756418cb4810936aa57e6965d6fb656a760b7f19adf96c173488552193b147ee58858033dac7cd0eb204c06490bbdedf5f7571acb2ebe76acef3f2a01ee987486dfe6c3f0a5e234c127258f97a28fb5d164a8176be", "u1dffmg4dp98h39xcvv4ghgaz76fmu50pezp8uf7xpyysj3ye8j9e07r8sdhge4yjk6ssl94qna5lwc6sjpdzk43tvf2gpxlzkymktqy9az77rjavvawy57xu5tyaevekq3esd5g23ew6gpt9srj9fqxusx4u5qnvwl4f3y39v2ryld8plc34x9l2y73m6wzk72gjepe536wf92q4065taed6cmcgkvr65rzv268qwhmwk5z77fkcseac3ewsmuxa4suzkzv0383yaykyj9a6v2xxg24p7e5k8paxadd59xs330t9nm6geuu2jps6ejh69asqak3x0", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 15, 3],
    [nil, nil, nil, "2598d84dffb34f5908b90732490f3881399150d4c694fce9bf30d1560b2c56f09829fe123b9add20e5d71c", nil, nil, "u12jl7f8zw52z4lqvy6rdfc5q4zlz0gr50uq87zgwr6nvcu8pfkpnajx8uyj8utlsyekj7uafehuxn3tg8ufczgk8xwzj2fz0fjvh9fr8p", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 16, 0],
    [nil, nil, nil, "c1150ae8529e667015c462f91fb26e9124095aebd6e72fca95a2fe17ae53e8cb101eda84d9fb4d336ee103", nil, nil, "u1xxndf9jxq3k60r2walgtza0e67nqvuwuhc3va3trhhgkkgynnwzjrwthktt68w2es9vwehgx2rx0sqt65ru087vutdh2v52ypcu8ylkh", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 16, 1],
    [nil, nil, nil, "e961944a708a15c9c62734c34510bb5e2cd740abdeb488e4142b5d402b0295bec67922f1e71ab7fbd0a2ae", nil, nil, "u14ke36gmjx6xj370ntw3h3ruyl2ad57d8ma5zvwd22ygjfsycmgr6ft4pjm7l2gw3xzglz4lrh9v9mzgaj08vsghqaw062j5uvvxlwc54", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 16, 2],
    [nil, nil, "d3a803803feee7a032a24adfaa8f6a94cecb9671c1333d0d5d1a3d79d82bc310727c665364d71022559c50", "7c98b8f613f9ff02746bea2a167cfd1bd3a1862af9631bf61d9d604e0824e2cb8467a1e549db87a76e7a8a", nil, nil, "u1a64l09qrsxulfjznm6k2g535usyhtaf8ed60v4jrjmkwvkux4t7pdyc3nkzrefdgtnw8420lj8shm05ja9fxxgnhra92nhsq56gx8c2puz3fkkgnrkqf5yuqfdtf7t6ran47gdcf5vvdfaczwf3uuy4fysh3mzu8hd5tkl05mvrge9n8", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 17, 0],
    [nil, nil, "25c25d58c50533dfb55d29f9a8864f58f02ea4fed44369352c43538cdf9545b905bb2ef0961bd2daf25883", "8a1bff2a9d921e1153b3cb264bc05185a9811de911d53467935434d6537d306752d02054fe5a170464259d", nil, nil, "u1f2mk4p04nnn9rmxqs4elkmqd42l0gxzfeurrn2zdedrjutx6fh0hgxz8avdlq45uv5achkjguvpyay329sk2raxkswspfy9z4m9a2yn8mkla3qpjpe3d9slczyj3ulf3pdvf2yrswayxj9ausn7d2zze850ctvkrltfjvvsjwgnkues4", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 17, 1],
    [nil, nil, "54b7fc0c85d378f375be48218a85424bb9e7a304830e9eb7255a12a09c961cca1f629b867e13242ed90d92", "14adca6f616abcbe5bc850cc617dcf999517a9a790292fec6bc0761eaa790333e7d06d016de05bca7c6712", nil, nil, "u1cha4ke52axxa37d3y5yjcdkpxjtgqvckww9zaecaq96c59y2hzm3hqsu5pktakkjhcl2r28ltdx95lfvq7y9wd5w4w0hfdrhgy0tkczephu30py7qyp7ftth92e68hhkjepj32xm2fp538p37nssx867g8t5apu84unc39ywxyltjhyq", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 17, 2],
    ["26c061d67beb8bad48c6b4774a156551e30e4fe2", nil, "bd51d90654e25613b5a4839dda2b9524ef4b12e7dbdccf3d4af150b06d95758afeb029227396094faf914a", nil, nil, nil, "u1p2nrze8u4geddlwn0dnppywuux58u4f24uqkfy6qns2hx2x3rm670q40ksp84ke2j3dfk0jn04gr3w4jp6yl69w48mxy795p98xfp5mvw7tkdp2utzm8fxjwm0u7fm79sx0c5h78ghx", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 18, 0],
    ["42874a6933bef7334702243232380781df8a71c5", nil, "4cea9549426d764dbd1b80c229e230a3bf3ca821b97c9847488afe37341634df27c3a634c2253436d98612", nil, nil, nil, "u1ufx6z3ck7ylkuph78pjpjgjflxh6dvvjx5aq7v8mwt4r3dlk4eyxqnk9tenck573vngsq555afelws0t5gm2rtuvswagsasff4naa4pkwnflcaxctxcvgy3m558mh7cgcgn26gq9a69", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 18, 5],
    ["c7ce0d050e10a82486bfab0a16537829dc6cf018", nil, "02221bc1820ca2b1940e532f00042367ee96acfe9f83476661a1ca4131e5d7485f4a49e0992a8917380f8b", nil, nil, nil, "u15quy62m78qxdl4yw5dzvt89vs0d6euwsa4mj4csxhyp0t7q40tggrlfyl3vt85caa53mg3xyz64xutxuzg7mmkyqydqypta2c6g2g9kgk3nu75jrnk6xj7eprpu5l36v2esykxfz0wh", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 18, 7],
    [nil, nil, "8660070e3757ff6507060791fd694f6a631b8495a2b74ffa39236cf653caea5575b86af3200b010e513bab", "63b7b706d991169986aee56133f0a50b2a0c8225fba6dae95176007b1f023a1e97c1aa366e99bf970fda82", nil, nil, "u1vg62mgjddnlv5w6ldky2xe0c8tetmc82tu9vlzzkuynx49fnuqjvxjt5dgn3cm8t5n85zcq5ljrtg7zmwhk70h6rdmclf7scxxnguk5flvf2app76xu907cmjylxvsen25xe9v7v3krsxa9uy0v2jjq37kh4ymlafn8pevqalqa4dm67", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 19, 5],
    [nil, nil, "6d75a1a948a4e730db3b4b816dbc7d80b4eb1bc68de9ac87b0cd1f1b3e6068e677888e105ac727c0d14b49", "52692e9402a8c14a225ec9dcf75a5588392e4da69e416f124e32168ff483144973d7ac8c23e4277fde5cb0", nil, nil, "u1z8m2p8pzzsxdek3x784l5xkd56u68wvv708pn475tkvultp7h6u66r8kxf9kttyahqnpdhvg9rfrmudxsf5le0c9mjmk942jm0yr78epqnwptzjuawgdhgy60zus2l62403hk5nlzhqlet85atyg88xxrwwj8dmvx98cy47g7s7qdsq7", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 19, 11],
    [nil, nil, "38b14b44ed6f4a3ae8c5c3923e5770b786f9b41d46c65a149b13910f4a0a64e83bb9bc98e80d9576fbf76e", "4b42498b76509868e9e74d75357ba19be8e9d55d024adf4e06c756c830e74a46df5bceeaeee595a6ed333e", nil, nil, "u1yuv2ls5k0xaym2lc4je6mf3djvmkyqdrxhcue25d4243udr0e97pyzhs9u3yl9q5de24tzxxdl2wfy4vvdw3wmu78sggdjq8xrshdztxnk3p6lqe4hk952fnq7qxggyxmnvtlkl3pns09zysunxu288jme6qlvjlhh5ry0fqyg5rs00y", "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", 19, 15]
]
