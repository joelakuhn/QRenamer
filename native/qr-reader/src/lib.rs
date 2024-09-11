use image::{self, GrayImage, ImageBuffer};
use image::{Luma, GenericImageView, Pixel};
use image::imageops::colorops::ColorMap;
use image::io::Reader;

use std::path::Path;

use rawloader;

#[cfg(target_os = "macos")]
use mozjpeg;
#[cfg(target_os = "macos")]
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

#[cfg(target_os = "macos")]
fn open_jpeg(path: &String, max_size : u32) -> Option<image::ImageBuffer<image::Luma<u8>, std::vec::Vec<u8>>> {
    let res = std::panic::catch_unwind(|| {
        let decompressor = mozjpeg::Decompress::with_markers(mozjpeg::ALL_MARKERS)
            .from_path(path).ok()?;

        let mut img = decompressor.grayscale().ok()?;
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

        img.finish().ok()?;

        Some(luma_img)
    });
    match res {
        Ok(luma) => luma,
        _ => None
    }
}

fn open_image(path : &String, max_size : u32) -> Option<image::ImageBuffer<image::Luma<u8>, std::vec::Vec<u8>>> {
    let reader = Reader::open(path);
    if !reader.is_err() {
        let decoded_img = reader.unwrap().decode();
        if !decoded_img.is_err() {
            return Some(decoded_img.unwrap().to_luma8());
            // let img = decoded_img.unwrap();
            // let img_width = img.width();
            // let img_height = img.height();
            // let (w, h) = constrain_size(img_width, img_height, max_size);
            // // let (w, h) = (img_width, img_height);
            // let w_ratio = img_width as f32 / w as f32;
            // let h_ratio = img_height as f32 / h as f32;

            // let luma_img = image::ImageBuffer::from_fn(w, h, |x, y| {
            //     let neighbor_x = clamp((x as f32 * w_ratio) as u32, 0, img_width);
            //     let neighbor_y = clamp((y as f32 * h_ratio) as u32, 0, img_height);

            //     img.get_pixel(neighbor_x, neighbor_y).to_luma()
            // });

            // return Some(luma_img);
        }
    }
    return None;
}

pub fn myprepare(buf : &mut ImageBuffer<Luma<u8>, Vec<u8>>) {
    let w = buf.width();
    let h = buf.height();

    for y in 0..h {
        let mut row_total = 0u32;
        for x in 0..w {
            row_total += buf.get_pixel(x, y).0[0] as u32;
        }
        let row_average = (row_total / w) as u8;

        for x in 0..w {
            let fill = if buf.get_pixel(x, y).0[0] < row_average {
                0x01
            } else {
                0x00
            };
            buf.put_pixel(x, y, Luma::<u8>([fill]));
        }
    }
}

pub fn read_qr(path : String, max_size : u32) -> String {
    let ext = Path::new(&path).extension();

    if ext.is_some() {

        let img_result = match String::from(ext.unwrap().to_str().unwrap()).to_lowercase().as_str() {
            #[cfg(target_os = "macos")]
            "jpg" | "jpeg"
                => open_image(&path, max_size),

            #[cfg(target_os = "windows")]
            "jpg" | "jpeg"
                => open_image(&path, max_size),

            "png" | "bmp" | "gif" | "tga" | "tiff" | "webp"
                => open_image(&path, max_size),

            "mrw" | "arw" | "srf" | "sr2" | "mef" | "orf" | "srw" | "erf" |
            "kdc" | "dcs" | "rw2" | "raf" | "dcr" | "pef" | "crw" | "iiq" |
            "3fr" | "nrw" | "nef" | "mos" | "cr2" | "ari"
                => open_raw(&path, max_size),

            _ => None
        };

        if img_result.is_some() {
            let orig = img_result.unwrap();
            for size in [ 900, 1200, 1800 ] {

                let (w, h) = constrain_size(orig.width(), orig.height(), size);
                let resized = image::imageops::resize(&orig, w, h, image::imageops::Triangle);

                let img = resized.clone();
                let mut decoder = rqrr::PreparedImage::prepare(img);
                let codes = decoder.detect_grids();

                for code in codes {
                    match code.decode() {
                        Ok((_meta, content)) => { return content; },
                        _ => {}
                    }
                }


                let img = resized.clone();
                match GrayImage::from_vec(img.width(), img.height(), img.into_vec()) {
                    Some(gray_image) => {
                        let otsu_level = imageproc::contrast::otsu_level(&gray_image);

                        let img = imageproc::contrast::threshold(&gray_image, otsu_level);
                        let mut decoder = rqrr::PreparedImage::prepare(img);
                        let codes = decoder.detect_grids();

                        for code in codes {
                            match code.decode() {
                                Ok((_meta, content)) => { return content; },
                                _ => {}
                            }
                        }
                    },
                    _ => {}
                }


                let mut img = resized.clone();
                let block_radius = (((img.width() * img.height()) as f32).sqrt() / 20.0) as u32;
                img = imageproc::contrast::adaptive_threshold(&img.into(), block_radius);

                let mut decoder = rqrr::PreparedImage::prepare(img);
                let codes = decoder.detect_grids();

                for code in codes {
                    match code.decode() {
                        Ok((_meta, content)) => { return content; },
                        _ => {}
                    }
                }


                let mut img = resized.clone();
                myprepare(&mut img);
                let mut decoder = rqrr::PreparedImage::without_preparation(img);
                let codes = decoder.detect_grids();

                for code in codes {
                    match code.decode() {
                        Ok((_meta, content)) => { return content; },
                        _ => {}
                    }
                }
            }
        }
    }
    return String::from("");
}
