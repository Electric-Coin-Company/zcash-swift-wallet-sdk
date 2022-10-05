import ZcashLightClientKit
import Foundation

/**
 let expected_views = vec![
            "CREATE VIEW v_transactions AS
            SELECT id_tx,
                   mined_height,
                   tx_index,
                   txid,
                   expiry_height,
                   raw,
                   SUM(value) + MAX(fee) AS net_value,
                   SUM(is_change) > 0 AS has_change,
                   SUM(memo_present) AS memo_count
            FROM (
                SELECT transactions.id_tx            AS id_tx,
                       transactions.block            AS mined_height,
                       transactions.tx_index         AS tx_index,
                       transactions.txid             AS txid,
                       transactions.expiry_height    AS expiry_height,
                       transactions.raw              AS raw,
                       0                             AS fee,
                       CASE
                            WHEN received_notes.is_change THEN 0
                            ELSE value
                       END AS value,
                       received_notes.is_change      AS is_change,
                       CASE
                           WHEN received_notes.memo IS NULL THEN 0
                           ELSE 1
                       END AS memo_present
                FROM   transactions
                       JOIN received_notes ON transactions.id_tx = received_notes.tx
                UNION
                SELECT transactions.id_tx            AS id_tx,
                       transactions.block            AS mined_height,
                       transactions.tx_index         AS tx_index,
                       transactions.txid             AS txid,
                       transactions.expiry_height    AS expiry_height,
                       transactions.raw              AS raw,
                       transactions.fee              AS fee,
                       -sent_notes.value             AS value,
                       false                         AS is_change,
                       CASE
                           WHEN sent_notes.memo IS NULL THEN 0
                           ELSE 1
                       END AS memo_present
                FROM   transactions
                       JOIN sent_notes ON transactions.id_tx = sent_notes.tx
            )
            GROUP BY id_tx",

 */


struct TransactionOverview {
    // MISSING: transaction kind. Is it outbound or inbound?
    var id: Int
    var minedHeight: BlockHeight
    var tx_index: Int
    var txid: Data
    var expiryHeight: BlockHeight
    var raw: Data
    var netValue: Zatoshi
    var hasChange: Bool
    var memoCount: Int
}

/**
            "CREATE VIEW v_tx_received AS
            SELECT transactions.id_tx            AS id_tx,
                   transactions.block            AS mined_height,
                   transactions.tx_index         AS tx_index,
                   transactions.txid             AS txid,
                   SUM(received_notes.value)     AS received_total,
                   COUNT(received_notes.id_note) AS received_note_count,
                   SUM(
                       CASE
                           WHEN received_notes.memo IS NULL THEN 0
                           ELSE 1
                       END
                   ) AS memo_count,
                   blocks.time                   AS block_time
            FROM   transactions
                   JOIN received_notes
                          ON transactions.id_tx = received_notes.tx
                   LEFT JOIN blocks
                          ON transactions.block = blocks.height
            GROUP BY received_notes.tx",

 */

struct ReceivedTransaction {
    var id: Int
    var minedHeight: BlockHeight
    var txIndex: Int
    var txId: Data
    var value: Zatoshi // received_total is weird
    var notes: Int // why is this needed?
    var memoCount: Int
    var blocktime: TimeInterval
}

/**
            "CREATE VIEW v_tx_sent AS
            SELECT transactions.id_tx         AS id_tx,
                   transactions.block         AS mined_height,
                   transactions.tx_index      AS tx_index,
                   transactions.txid          AS txid,
                   transactions.expiry_height AS expiry_height,
                   transactions.raw           AS raw,
                   SUM(sent_notes.value)      AS sent_total,
                   COUNT(sent_notes.id_note)  AS sent_note_count,
                   SUM(
                       CASE
                           WHEN sent_notes.memo IS NULL THEN 0
                           ELSE 1
                       END
                   ) AS memo_count,
                   blocks.time                AS block_time
            FROM   transactions
                   JOIN sent_notes
                          ON transactions.id_tx = sent_notes.tx
                   LEFT JOIN blocks
                          ON transactions.block = blocks.height
            GROUP BY sent_notes.tx",
        ];
 */

struct SentTransaction {
    var id: Int
    var minedHeight: BlockHeight?
    var txIndex: Int
    var txId: Data
    var expiryHeight: BlockHeight
    var raw: Data
    var value: Zatoshi // sent_total does not make sense if there's no other value that's subtotal
    var fee: Zatoshi // MISSING VALUE: FEE
    var recipient: Recipient // MISSING VALUE: recipient, who is this transaction for?
    var memoCount: Int
    var blocktime: TimeInterval
}



/**
 FOR REFERENCE: This is the detail model ECC Wallet uses
 */
struct DetailModel: Identifiable {

    enum Status {
        case paid(success: Bool)
        case received
    }
    var id: String
    var zAddress: String?
    var date: Date
    var amount: Zatoshi
    var status: Status
    var shielded: Bool = true
    var memo: String? = nil
    var minedHeight: Int = -1
    var expirationHeight: Int = -1
//    var title: String {
//
//        switch status {
//        case .paid(let success):
//            return success ? "You paid \(zAddress?.shortZaddress ?? "Unknown")" : "Unsent Transaction"
//        case .received:
//            return "\(zAddress?.shortZaddress ?? "Unknown") paid you"
//        }
//    }
//    
//    var subtitle: String

}
