use failure::format_err;
use ffi_helpers::panic::catch_panic;
use std::ffi::{CString, OsStr};
use std::os::raw::c_char;
use std::os::unix::ffi::OsStrExt;
use std::path::Path;
use std::slice;
use zcash_client_backend::{
    constants::testnet::HRP_SAPLING_EXTENDED_SPENDING_KEY, encoding::encode_extended_spending_key,
    keys::spending_key,
};
use zcash_client_sqlite::{get_address, init_accounts_table, init_data_database, ErrorKind};
use zcash_primitives::zip32::ExtendedFullViewingKey;

fn unwrap_exc_or<T>(exc: Result<T, ()>, def: T) -> T {
    match exc {
        Ok(value) => value,
        Err(_) => def,
    }
}

fn unwrap_exc_or_null<T>(exc: Result<T, ()>) -> T
where
    T: ffi_helpers::Nullable,
{
    match exc {
        Ok(value) => value,
        Err(_) => ffi_helpers::Nullable::NULL,
    }
}

/// Returns the length of the last error message to be logged.
#[no_mangle]
pub extern "C" fn zcashlc_last_error_length() -> i32 {
    ffi_helpers::error_handling::last_error_length()
}

/// Copies the last error message into the provided allocated buffer.
#[no_mangle]
pub unsafe extern "C" fn zcashlc_error_message_utf8(buf: *mut c_char, length: i32) -> i32 {
    ffi_helpers::error_handling::error_message_utf8(buf, length)
}

/// Clears the record of the last error message.
#[no_mangle]
pub extern "C" fn zcashlc_clear_last_error() {
    ffi_helpers::error_handling::clear_last_error()
}

/// Sets up the internal structure of the data database.
#[no_mangle]
pub extern "C" fn zcashlc_init_data_database(db_data: *const u8, db_data_len: usize) -> i32 {
    let res = catch_panic(|| {
        let db_data = Path::new(OsStr::from_bytes(unsafe {
            slice::from_raw_parts(db_data, db_data_len)
        }));

        init_data_database(&db_data)
            .map(|()| 1)
            .map_err(|e| format_err!("Error while initializing data DB: {}", e))
    });
    unwrap_exc_or_null(res)
}

/// Initialises the data database with the given number of accounts using the given seed.
///
/// Returns the ExtendedSpendingKeys for the accounts. The caller should store these
/// securely for use while spending.
///
/// Call `zcashlc_vec_string_free` on the returned pointer when you are finished with it.
#[no_mangle]
pub extern "C" fn zcashlc_init_accounts_table(
    db_data: *const u8,
    db_data_len: usize,
    seed: *const u8,
    seed_len: usize,
    accounts: i32,
) -> *mut *mut c_char {
    let res = catch_panic(|| {
        let db_data = Path::new(OsStr::from_bytes(unsafe {
            slice::from_raw_parts(db_data, db_data_len)
        }));
        let seed = unsafe { slice::from_raw_parts(seed, seed_len) };
        let accounts = if accounts >= 0 {
            accounts as u32
        } else {
            return Err(format_err!("accounts argument must be positive"));
        };

        let extsks: Vec<_> = (0..accounts)
            .map(|account| spending_key(&seed, 1, account))
            .collect();
        let extfvks: Vec<_> = extsks.iter().map(ExtendedFullViewingKey::from).collect();

        match init_accounts_table(&db_data, &extfvks) {
            Ok(()) => (),
            Err(e) => match e.kind() {
                ErrorKind::TableNotEmpty => {
                    // Ignore this error.
                }
                _ => return Err(format_err!("Error while initializing accounts: {}", e)),
            },
        }

        // Return the ExtendedSpendingKeys for the created accounts.
        let mut v: Vec<_> = extsks
            .iter()
            .map(|extsk| {
                let encoded =
                    encode_extended_spending_key(HRP_SAPLING_EXTENDED_SPENDING_KEY, extsk);
                CString::new(encoded).unwrap().into_raw()
            })
            .collect();
        assert!(v.len() == v.capacity());
        let p = v.as_mut_ptr();
        std::mem::forget(v);
        Ok(p)
    });
    unwrap_exc_or_null(res)
}

/// Returns the address for the account.
///
/// Call `zcashlc_string_free` on the returned pointer when you are finished with it.
#[no_mangle]
pub extern "C" fn zcashlc_get_address(
    db_data: *const u8,
    db_data_len: usize,
    account: i32,
) -> *mut c_char {
    let res = catch_panic(|| {
        let db_data = Path::new(OsStr::from_bytes(unsafe {
            slice::from_raw_parts(db_data, db_data_len)
        }));
        let account = if account >= 0 {
            account as u32
        } else {
            return Err(format_err!("accounts argument must be positive"));
        };

        match get_address(&db_data, account) {
            Ok(addr) => {
                let c_str_addr = CString::new(addr).unwrap();
                Ok(c_str_addr.into_raw())
            }
            Err(e) => Err(format_err!("Error while fetching address: {}", e)),
        }
    });
    unwrap_exc_or_null(res)
}

/// Frees strings returned by other zcashlc functions.
#[no_mangle]
pub extern "C" fn zcashlc_string_free(s: *mut c_char) {
    unsafe {
        if s.is_null() {
            return;
        }
        CString::from_raw(s)
    };
}

/// Frees vectors of strings returned by other zcashlc functions.
#[no_mangle]
pub extern "C" fn zcashlc_vec_string_free(v: *mut *mut c_char, len: usize) {
    unsafe {
        if v.is_null() {
            return;
        }
        // All Vecs created by other functions MUST have length == capacity.
        let v = Vec::from_raw_parts(v, len, len);
        v.into_iter().map(|s| CString::from_raw(s)).for_each(drop);
    };
}
