use std::env;
use qr_reader::read_qr;

fn main() {
    let args : Vec<String> = env::args().collect();

    for i in 1..args.len() {
        let path = String::from(&args[i]);
        let qr_data = read_qr(path);
        if qr_data.len() > 0 {
            println!("{}", qr_data);
        }
    }
}
