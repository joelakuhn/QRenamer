use qr_reader::read_qr;
use std::ffi::{CString, CStr};
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn read_qr_ffi(path_ptr: *const c_char, max_size_ptr : *const c_char) -> *const c_char {
    let res = std::panic::catch_unwind(|| {
        let path_cstr = unsafe { CStr::from_ptr(path_ptr) };
        let path = String::from(path_cstr.to_str().unwrap());

        let max_size_cstr = unsafe { CStr::from_ptr(max_size_ptr) };
        let max_size = String::from(max_size_cstr.to_str().unwrap()).parse().unwrap();

        let qr_data = read_qr(path, max_size);
        return CString::new(qr_data).unwrap().into_raw();
    });

    return match res {
        Ok(qr_data) => qr_data,
        _ => CString::new("").unwrap().into_raw()
    };
}

#[no_mangle]
pub extern "C" fn free_str_ffi(ptr: *mut c_char) {
    unsafe {
        if ptr.is_null() {
            return;
        }
        CString::from_raw(ptr);
    }
}
