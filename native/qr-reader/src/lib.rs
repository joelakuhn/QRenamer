use image;
use image::{Luma, ImageBuffer, GenericImageView, Pixel};
use image::imageops::colorops::{index_colors, ColorMap};
use image::io::Reader;

use std::path::Path;

use rqrr;
use rawloader;
use mozjpeg;
use rgb::alt::*;

#[derive(Clone, Copy)]
pub struct Threshold {
    boundary: u8
}

impl ColorMap for Threshold {
    type Color = Luma<u8>;

    #[inline(always)]
    fn index_of(&self, color: &Luma<u8>) -> usize {
        let luma = color.0;
        if luma[0] > self.boundary {
            1
        } else {
            0
        }
    }

    #[inline(always)]
    fn lookup(&self, idx: usize) -> Option<Self::Color> {
        match idx {
            0 => Some([0].into()),
            1 => Some([255].into()),
            _ => None,
        }
    }

    /// Indicate NeuQuant implements `lookup`.
    fn has_lookup(&self) -> bool {
        true
    }

    #[inline(always)]
    fn map_color(&self, color: &mut Luma<u8>) {
        let new_color = 0xFF * self.index_of(color) as u8;
        let luma = &mut color.0;
        luma[0] = new_color;
    }
}

fn constrain_size(orig_w : u32, orig_h : u32, max_dim : u32) -> (u32, u32) {
    if max_dim == 0 {
        return (orig_w, orig_h);
    }

    let mut w = orig_w;
    let mut h = orig_h;

    if w > (max_dim as f32 * 1.5) as u32 || h > (max_dim as f32 * 1.5) as u32 {
        if h > w {
            h = max_dim;
            w = ((orig_w as f32 / orig_h as f32) * max_dim as f32) as u32;
        }
        else {
            w = max_dim;
            h = ((orig_h as f32 / orig_w as f32) * max_dim as f32) as u32;
        }
    }

    return (w, h);
}

fn threshold(img : &ImageBuffer<Luma<u8>, Vec<u8>>, boundary : u8) -> ImageBuffer<Luma<u8>, Vec<u8>> {
    let cmap = Threshold{ boundary: boundary };
    let palletized = index_colors(&img, &cmap);
    let bw_img = ImageBuffer::from_fn(img.width(), img.height(), |x, y| {
        let p = palletized.get_pixel(x, y);
        cmap.lookup(p.0[0] as usize).expect("index color out of range")
    });
    return bw_img;
}

#[inline]
fn clamp(val : u32, min : u32, max : u32) -> u32 {
    if val > max {
        return max;
    }
    if val < min {
        return min;
    }
    return val;
}

fn get_average_pixel(data : &[u16], x : i32, y : i32, steps : i32, w : i32, h : i32) -> u16{
    let mut pixels_found = 0;
    let mut wide_pixel = 0u64;
    for dx in -steps..(steps + 1) {
        for dy in -steps..(steps + 1) {
            if dx.abs() + dy.abs() <= steps {
                let nx = x + dx;
                let ny = y + dy;
                if nx >= 0 && nx < w && ny >= 0 && ny < h {
                    pixels_found += 1;
                    let offset = (nx + ny * w) as usize;
                    let px = data[offset];
                    wide_pixel += px as u64;
                }
            }
        }
    }
    return (wide_pixel as f32 / pixels_found as f32) as u16;
}

fn open_raw(path : &String, max_size : u32) -> Option<image::ImageBuffer<image::Luma<u8>, std::vec::Vec<u8>>> {
    let img = rawloader::decode_file(path).unwrap();

    let (w, h) = constrain_size(img.width as u32, img.height as u32, max_size);
    let img_width = img.width;
    let img_height = img.height;
    let w_ratio = img_width as f32 / w as f32;
    let h_ratio = img_height as f32 / h as f32;

    if let rawloader::RawImageData::Integer(data) = img.data {

        let luma_img = image::ImageBuffer::from_fn(w, h, |x, y| {
            let src_x = (x as f32 * w_ratio) as usize;
            let src_y = (y as f32 * h_ratio) as usize;

            let avg_px = get_average_pixel(&data, src_x as i32, src_y as i32, w_ratio as i32, img_width as i32, img_height as i32);
            let px = ((avg_px as f32 / 0xfff as f32) * 0xff as f32) as u8;
            image::Luma([px])
        });
        return Some(luma_img);
    } else {
        eprintln!("Don't know how to process non-integer raw files");
    }
    return None;
}

fn open_jpeg(path: &String, max_size : u32) -> Option<image::ImageBuffer<image::Luma<u8>, std::vec::Vec<u8>>> {
    let res = std::panic::catch_unwind(|| {
        let d = mozjpeg::Decompress::with_markers(mozjpeg::ALL_MARKERS)
            .from_path(path).unwrap();

        let mut img = d.grayscale().unwrap();
        let pixels : Vec<GRAY8> = img.read_scanlines().unwrap();

        let img_width = img.width() as u32;
        let img_height = img.height() as u32;
        let (w, h) = constrain_size(img_width, img_height, max_size);
        let w_ratio = img_width as f32 / w as f32;
        let h_ratio = img_height as f32 / h as f32;
        
        let luma_img = image::ImageBuffer::from_fn(w, h, |x, y| {
            let neighbor_x = clamp((x as f32 * w_ratio) as u32, 0, img_width);
            let neighbor_y = clamp((y as f32 * h_ratio) as u32, 0, img_height);
            
            image::Luma([pixels[(neighbor_x + neighbor_y * img_width) as usize].0])
        });

        img.finish_decompress();
        
        luma_img
    });
    match res {
        Ok(luma) => Some(luma),
        _ => None
    }
}

fn open_image(path : &String, max_size : u32) -> Option<image::ImageBuffer<image::Luma<u8>, std::vec::Vec<u8>>> {
    let reader = Reader::open(path);
    if !reader.is_err() {
        let decoded_img = reader.unwrap().decode();
        if !decoded_img.is_err() {
            let img = decoded_img.unwrap();
            let img_width = img.width();
            let img_height = img.height();
            let (w, h) = constrain_size(img_width, img_height, max_size);
            // let (w, h) = (img_width, img_height);
            let w_ratio = img_width as f32 / w as f32;
            let h_ratio = img_height as f32 / h as f32;
            
            let luma_img = image::ImageBuffer::from_fn(w, h, |x, y| {
                let neighbor_x = clamp((x as f32 * w_ratio) as u32, 0, img_width);
                let neighbor_y = clamp((y as f32 * h_ratio) as u32, 0, img_height);
                
                img.get_pixel(neighbor_x, neighbor_y).to_luma()
            });
        
            return Some(luma_img);
        }
    }
    return None;
}

pub fn read_qr(path : String, max_size : u32) -> String {
    let ext = Path::new(&path).extension();

    if ext.is_some() {

        let img_result = match String::from(ext.unwrap().to_str().unwrap()).to_lowercase().as_str() {
            "jpg" | "jpeg"
                => open_jpeg(&path, max_size),

            "png" | "bmp" | "gif" | "tga" | "tiff" | "webp"
                => open_image(&path, max_size),

            "mrw" | "arw" | "srf" | "sr2" | "mef" | "orf" | "srw" | "erf" |
            "kdc" | "dcs" | "rw2" | "raf" | "dcr" | "pef" | "crw" | "iiq" |
            "3fr" | "nrw" | "nef" | "mos" | "cr2" | "ari"
                => open_raw(&path, max_size),

            _ => None
        };
    
        if img_result.is_some() {

            let orig_img = img_result.unwrap();
            let mut threshold_boundary = 200;

            while threshold_boundary >= 120 {

                let bw_img = threshold(&orig_img, threshold_boundary);
                let mut img = rqrr::PreparedImage::prepare(bw_img);
                let grids = img.detect_grids();
                
                if grids.len() > 0 {
                    let result = grids[0].decode();
                    if result.is_err() {
                        // println!("{}: {:?}", path, result);
                    }
                    else {
                        let (_meta, content) = result.unwrap();
                        return content;
                    }
                }

                threshold_boundary -= 40;
            }

        }
    }
    return String::from("");
}
