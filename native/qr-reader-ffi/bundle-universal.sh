#!/bin/bash

cargo build --release && \
cargo build --target=aarch64-apple-darwin --release && \
lipo -create -arch arm64 target/aarch64-apple-darwin/release/libqr_reader_ffi.dylib -arch x86_64 target/release/libqr_reader_ffi.dylib -output libqr_reader_ffi.dylib

file libqr_reader_ffi.dylib

