use qr_reader::read_qr;
use std::ffi::{CString, CStr};
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn read_qr_ffi(ptr: *const c_char) -> *const c_char {
    let cstr = unsafe { CStr::from_ptr(ptr) };
    let path = String::from(cstr.to_str().unwrap());
    let qr_data = read_qr(path);
    return CString::new(qr_data).unwrap().into_raw();
}
