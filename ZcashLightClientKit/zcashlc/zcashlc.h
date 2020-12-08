#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

int32_t zcashlc_branch_id_for_height(int32_t height);

/**
 * Clears the record of the last error message.
 */
void zcashlc_clear_last_error(void);

/**
 * Creates a transaction paying the specified address from the given account.
 *
 * Returns the row index of the newly-created transaction in the `transactions` table
 * within the data database. The caller can read the raw transaction bytes from the `raw`
 * column in order to broadcast the transaction to the network.
 *
 * Do not call this multiple times in parallel, or you will generate transactions that
 * double-spend the same notes.
 */
int64_t zcashlc_create_to_address(const uint8_t *db_data,
                                  uintptr_t db_data_len,
                                  int32_t account,
                                  const char *extsk,
                                  const char *to,
                                  int64_t value,
                                  const char *memo,
                                  const uint8_t *spend_params,
                                  uintptr_t spend_params_len,
                                  const uint8_t *output_params,
                                  uintptr_t output_params_len);

int32_t zcashlc_decrypt_and_store_transaction(const uint8_t *db_data,
                                              uintptr_t db_data_len,
                                              const uint8_t *tx,
                                              uintptr_t tx_len);

/**
 * derives a shielded address from the given extended full viewing key.
 * call zcashlc_string_free with the returned pointer when done using it
 */
char *zcashlc_derive_extended_full_viewing_key(const char *extsk);

/**
 * Derives Extended Full Viewing Keys from the given seed into 'accounts' number of accounts.
 * Returns the Extended Full Viewing Keys for the accounts. The caller should store these
 * securely
 *
 * Call `zcashlc_vec_string_free` on the returned pointer when you are finished with it.
 */
char **zcashlc_derive_extended_full_viewing_keys(const uint8_t *seed,
                                                 uintptr_t seed_len,
                                                 int32_t accounts,
                                                 uintptr_t *capacity_ret);

/**
 * Derives Extended Spending Keys from the given seed into 'accounts' number of accounts.
 * Returns the ExtendedSpendingKeys for the accounts. The caller should store these
 * securely for use while spending.
 *
 * Call `zcashlc_vec_string_free` on the returned pointer when you are finished with it.
 */
char **zcashlc_derive_extended_spending_keys(const uint8_t *seed,
                                             uintptr_t seed_len,
                                             int32_t accounts,
                                             uintptr_t *capacity_ret);

/**
 * derives a shielded address from the given seed.
 * call zcashlc_string_free with the returned pointer when done using it
 */
char *zcashlc_derive_shielded_address_from_seed(const uint8_t *seed,
                                                uintptr_t seed_len,
                                                int32_t account_index);

/**
 * derives a shielded address from the given viewing key.
 * call zcashlc_string_free with the returned pointer when done using it
 */
char *zcashlc_derive_shielded_address_from_viewing_key(const char *extfvk);

/**
 * TEST TEST 123 TEST
 * Derives a transparent address from the given seed
 */
char *zcashlc_derive_transparent_address_from_seed(const uint8_t *seed, uintptr_t seed_len);

/**
 * Copies the last error message into the provided allocated buffer.
 */
int32_t zcashlc_error_message_utf8(char *buf, int32_t length);

/**
 * Returns the address for the account.
 *
 * Call `zcashlc_string_free` on the returned pointer when you are finished with it.
 */
char *zcashlc_get_address(const uint8_t *db_data, uintptr_t db_data_len, int32_t account);

/**
 * Returns the balance for the account, including all unspent notes that we know about.
 */
int64_t zcashlc_get_balance(const uint8_t *db_data, uintptr_t db_data_len, int32_t account);

/**
 * Returns the memo for a received note, if it is known and a valid UTF-8 string.
 *
 * The note is identified by its row index in the `received_notes` table within the data
 * database.
 *
 * Call `zcashlc_string_free` on the returned pointer when you are finished with it.
 */
char *zcashlc_get_received_memo_as_utf8(const uint8_t *db_data,
                                        uintptr_t db_data_len,
                                        int64_t id_note);

/**
 * Returns the memo for a sent note, if it is known and a valid UTF-8 string.
 *
 * The note is identified by its row index in the `sent_notes` table within the data
 * database.
 *
 * Call `zcashlc_string_free` on the returned pointer when you are finished with it.
 */
char *zcashlc_get_sent_memo_as_utf8(const uint8_t *db_data, uintptr_t db_data_len, int64_t id_note);

/**
 * Returns the verified balance for the account, which ignores notes that have been
 * received too recently and are not yet deemed spendable.
 */
int64_t zcashlc_get_verified_balance(const uint8_t *db_data,
                                     uintptr_t db_data_len,
                                     int32_t account);

/**
 * Initialises the data database with the given number of accounts using the given seed.
 *
 * Returns the ExtendedSpendingKeys for the accounts. The caller should store these
 * securely for use while spending.
 *
 * Call `zcashlc_vec_string_free` on the returned pointer when you are finished with it.
 */
char **zcashlc_init_accounts_table(const uint8_t *db_data,
                                   uintptr_t db_data_len,
                                   const uint8_t *seed,
                                   uintptr_t seed_len,
                                   int32_t accounts,
                                   uintptr_t *capacity_ret);

/**
 * Initialises the data database with the given extended full viewing keys
 * Call `zcashlc_vec_string_free` on the returned pointer when you are finished with it.
 */
bool zcashlc_init_accounts_table_with_keys(const uint8_t *db_data,
                                           uintptr_t db_data_len,
                                           const char *const *extfvks,
                                           uintptr_t extfvks_len);

/**
 * Initialises the data database with the given block.
 *
 * This enables a newly-created database to be immediately-usable, without needing to
 * synchronise historic blocks.
 */
int32_t zcashlc_init_blocks_table(const uint8_t *db_data,
                                  uintptr_t db_data_len,
                                  int32_t height,
                                  const char *hash_hex,
                                  uint32_t time,
                                  const char *sapling_tree_hex);

/**
 * Sets up the internal structure of the data database.
 */
int32_t zcashlc_init_data_database(const uint8_t *db_data, uintptr_t db_data_len);

/**
 * Returns true when the address is valid and shielded.
 * Returns false in any other case
 * Errors when the provided address belongs to another network
 */
bool zcashlc_is_valid_shielded_address(const char *address);

/**
 * Returns true when the address is valid and transparent.
 * Returns false in any other case
 */
bool zcashlc_is_valid_transparent_address(const char *address);

/**
 * Returns the length of the last error message to be logged.
 */
int32_t zcashlc_last_error_length(void);

/**
 * Rewinds the data database to the given height.
 *
 * If the requested height is greater than or equal to the height of the last scanned
 * block, this function does nothing.
 */
int32_t zcashlc_rewind_to_height(const uint8_t *db_data, uintptr_t db_data_len, int32_t height);

/**
 * Scans new blocks added to the cache for any transactions received by the tracked
 * accounts.
 *
 * This function pays attention only to cached blocks with heights greater than the
 * highest scanned block in `db_data`. Cached blocks with lower heights are not verified
 * against previously-scanned blocks. In particular, this function **assumes** that the
 * caller is handling rollbacks.
 *
 * For brand-new light client databases, this function starts scanning from the Sapling
 * activation height. This height can be fast-forwarded to a more recent block by calling
 * [`zcashlc_init_blocks_table`] before this function.
 *
 * Scanned blocks are required to be height-sequential. If a block is missing from the
 * cache, an error will be signalled.
 */
int32_t zcashlc_scan_blocks(const uint8_t *db_cache,
                            uintptr_t db_cache_len,
                            const uint8_t *db_data,
                            uintptr_t db_data_len);

/**
 * Frees strings returned by other zcashlc functions.
 */
void zcashlc_string_free(char *s);

/**
 * Checks that the scanned blocks in the data database, when combined with the recent
 * `CompactBlock`s in the cache database, form a valid chain.
 *
 * This function is built on the core assumption that the information provided in the
 * cache database is more likely to be accurate than the previously-scanned information.
 * This follows from the design (and trust) assumption that the `lightwalletd` server
 * provides accurate block information as of the time it was requested.
 *
 * Returns:
 * - `-1` if the combined chain is valid.
 * - `upper_bound` if the combined chain is invalid.
 *   `upper_bound` is the height of the highest invalid block (on the assumption that the
 *   highest block in the cache database is correct).
 * - `0` if there was an error during validation unrelated to chain validity.
 *
 * This function does not mutate either of the databases.
 */
int32_t zcashlc_validate_combined_chain(const uint8_t *db_cache,
                                        uintptr_t db_cache_len,
                                        const uint8_t *db_data,
                                        uintptr_t db_data_len);

/**
 * Frees vectors of strings returned by other zcashlc functions.
 */
void zcashlc_vec_string_free(char **v, uintptr_t len, uintptr_t capacity);
