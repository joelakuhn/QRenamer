use image;
use image::{Luma, ImageBuffer, GenericImageView, Pixel};
use image::imageops::colorops::{index_colors, ColorMap};
use image::io::Reader;

use rqrr;

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

fn open_image(path : &String) -> Option<image::ImageBuffer<image::Luma<u8>, std::vec::Vec<u8>>> {
    let reader = Reader::open(path);
    if !reader.is_err() {
        let decoded_img = reader.unwrap().decode();
        if !decoded_img.is_err() {
            let img = decoded_img.unwrap();
            let img_width = img.width();
            let img_height = img.height();
            let (w, h) = constrain_size(img_width, img_height, 1500);
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

pub fn read_qr(path : String) -> String {
    let img_result = open_image(&path);
    
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
    return String::from("");
}
