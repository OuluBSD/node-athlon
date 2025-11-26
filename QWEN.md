# Node.js Athlon Build Project

## Project Goal
This repository is designed to modify the Node.js build process to allow compilation and execution on older processors that lack SSE/SSE2 instruction support, specifically:

- **AMD Athlon CPUs** (such as the 800MHz model) that support 3DNow!, 3DNow! Extensions, MMX, and MMX Extensions but not SSE/SSE2
- **PowerPC processors** (such as those in PowerMac G5) that use Altivec (Velocity Engine) instead of SSE instructions

## Current State
The project implements SIMD instruction set detection and conditional compilation to support multiple instruction set architectures:
- SSE2 (for newer x86/x64 processors)  
- 3DNow! and 3DNow! Extensions (for older AMD processors like Athlon)
- Altivec (for PowerPC systems like G5)
- Fallback implementations for maximum compatibility

## Build Configuration
The build system supports a `--with-simd-support` option that can be set to:
- `sse2` - Use SSE2 instructions (default for compatible systems)
- `3dnow` - Use 3DNow! instructions (for AMD Athlon and compatible processors) 
- `altivec` - Use Altivec instructions (for PowerPC systems)
- `auto` - Automatically detect the best available SIMD instruction set
- `none` - Build without SIMD optimizations for maximum compatibility

## Technical Approach
- Runtime CPU feature detection for SIMD capabilities
- Conditional compilation with appropriate fallback implementations
- Maintaining performance on SIMD-capable systems while enabling execution on older hardware
- Allowing Node.js to run on processors from the late 1990s and early 2000s

## SIMD Optimizations Implemented
- **SSE2 optimizations** - Enhanced performance for modern x86/x64 systems
- **3DNow!/3DNow! Extensions** - Optimized code paths for AMD Athlon processors using 3DNow! instructions
- **Altivec (VMX)** - Optimized code paths for PowerPC G4/G5 systems using Altivec instructions
- **Fallback implementations** - Pure C++ implementations for systems without SIMD support

## Files Modified to Support Multiple SIMD Instruction Sets
- `deps/v8/src/strings/string-hasher.cc` - Added Altivec and 3DNow! support
- `deps/v8/third_party/fast_float/src/include/fast_float/ascii_number.h` - Added Altivec and 3DNow! support
- `deps/v8/third_party/abseil-cpp/absl/crc/internal/crc32_x86_arm_combined_simd.h` - Added Altivec and 3DNow! support
- `deps/simdjson/simdjson.h` and `simdjson.cpp` - Added Altivec and 3DNow! support
- `deps/v8/src/objects/swiss-hash-table-helpers.h` - Added Altivec and 3DNow! support with proper includes
- `deps/v8/third_party/zlib/slide_hash_simd.h` - Added Altivec and 3DNow! support
- `deps/v8/third_party/zlib/adler32_simd.c` - Added Altivec and 3DNow! support
- `src/simd_abstraction.c` and `src/simd_abstraction.h` - Complete SIMD abstraction layer with runtime detection

## Status
Successfully enables Node.js builds for processors without SSE2 support while preserving performance optimizations for systems that support these instruction sets. The codebase now contains comprehensive implementations for Altivec and 3DNow! alternatives to SSE2 instructions, with proper runtime detection and configuration support.