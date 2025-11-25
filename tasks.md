# Node.js SSE2 to SSE2/3DNow/Altivec Migration Plan

## Overview
This document outlines the plan to modify Node.js codebase to not require SSE2 exclusively, but instead support SSE2/3DNow/Altivec as alternatives, allowing the code to run on processors that don't support SSE2. This enables better backward compatibility with older processors including AMD K6-2, K7, and PowerPC systems.

## Background
The current Node.js codebase has SSE2 requirements enforced in multiple places:
- OpenSSL configuration via `OPENSSL_IA32_SSE2` defines
- zlib SIMD optimizations with `INFLATE_CHUNK_SIMD_SSE2` and `DEFLATE_SLIDE_HASH_SSE2`
- V8 engine SIMD operations
- simdjson library checks
- Various other libraries (zstd, etc.)

## Architecture Strategy
Instead of requiring SSE2 as a hard dependency, we will implement runtime detection and conditional compilation to support:
1. SSE2 (on newer x86/x64 processors) 
2. 3DNow! (on AMD K6-2, K7 Athlon processors) 
3. Altivec (on PowerPC processors)
4. Fallback to scalar implementations when none are available

## Phase 1: Assessment and Architecture Design
### Tasks
- [x] Identify all SSE2-related code in the project
- [x] Analyze configuration files that set SSE2 requirements
- [x] Identify source code that uses SSE2 intrinsics
- [x] Research 3DNow and Altivec alternatives for SSE2 operations
- [x] Create detailed roadmap for replacing SSE2 code

### Completed Analysis
- **OpenSSL**: Uses `OPENSSL_IA32_SSE2` flag in x64 configurations
- **zlib**: Uses SSE2 intrinsics for inflate/deflate operations
- **V8**: Has SSE2-specific optimizations and Swiss table implementations
- **simdjson**: Has SSE2 detection and usage
- **zstd/xxhash**: Include SSE2 optimizations
- **Other dependencies**: Multiple libraries with SIMD optimizations

## Phase 2: Core Infrastructure Changes
### Tasks
- Implement runtime CPU feature detection for SSE2, 3DNow!, and Altivec
- Create conditional compilation macros
- Design abstraction layer for SIMD operations
- Update build configuration to support flexible SIMD selection

### Subtasks
1. **CPU Detection Infrastructure**:
   - Update `deps/zlib/cpu_features.c` and `cpu_features.h` 
   - Add 3DNow! detection functions for x86
   - Enhance Altivec detection for PowerPC
   - Create unified feature detection API

2. **Build System Modifications**:
   - Modify `tools/v8_gypfiles/toolchain.gypi` to conditionally include `-msse2`
   - Update `deps/zlib/CMakeLists.txt` and related build files
   - Add configure options for SIMD flexibility
   - Update GYP build configurations to allow optional SSE2

## Phase 3: Library-by-Library Migration
### Tasks
1. **zlib modifications**:
   - Create 3DNow!/Altivec implementations for inflate_chunk_simd
   - Add fallback mechanisms when SIMD is not available
   - Update `cpu_features.c` to detect 3DNow! and Altivec
   - Modify `deflate.c` to conditionally use SIMD optimizations

2. **OpenSSL modifications**:
   - Update `openssl.gypi` to conditionally define `OPENSSL_IA32_SSE2`
   - Allow builds without SSE2 for older x86 processors
   - Maintain performance for SSE2-capable systems
   - Ensure crypto functionality remains secure without SIMD

3. **V8 modifications**:
   - Update `src/objects/swiss-hash-table-helpers.h` for conditional SSE2 use
   - Implement PowerPC Altivec backend for hash table operations
   - Add AMD 3DNow! alternatives where appropriate
   - Ensure fallback to scalar implementations

4. **simdjson modifications**:
   - Update SIMD detection to support multiple instruction sets
   - Add 3DNow! and Altivec backends
   - Provide scalar fallbacks

## Phase 4: SIMD Implementation and Porting
### Tasks
1. **SSE2 to 3DNow! Porting**:
   - Map SSE2 operations to equivalent 3DNow! instructions
   - Key mappings: `_mm_add_ps` → `pfadd`, `_mm_mul_ps` → `pfmul`, etc.
   - Implement floating-point SIMD operations using 3DNow!

2. **SSE2 to Altivec Porting**:
   - Map SSE2 operations to equivalent Altivec instructions
   - Use `<altivec.h>` intrinsics for PowerPC
   - Implement integer and floating-point operations using VMX

3. **Performance and Validation**:
   - Ensure that 3DNow! and Altivec implementations maintain correctness
   - Benchmark performance against scalar fallbacks
   - Validate all SIMD paths produce identical results

## Phase 5: Build System and Configuration
### Tasks
1. **Configure Script Updates**:
   - Add `--with-simd-support` option (sse2|3dnow|altivec|auto|none)
   - Update configure.py to handle flexible SIMD requirements
   - Allow builds without SSE2 requirement

2. **Compiler Flags Management**:
   - Conditionally apply `-msse2` only when necessary
   - Add `-m3dnow` for 3DNow! support where needed
   - Add appropriate Altivec flags for PowerPC builds 

3. **Cross-Platform Support**:
   - Maintain compatibility across all supported Node.js platforms
   - Ensure Windows, Linux, macOS builds work correctly
   - Test on PowerPC and older AMD systems

## Phase 6: Testing and Validation
### Tasks
1. **Unit Testing**:
   - Create tests that verify SIMD functionality across all paths
   - Test fallback to scalar implementations when SIMD is unavailable
   - Verify correctness of 3DNow!/Altivec implementations

2. **Integration Testing**:
   - Test complete Node.js functionality on various architectures
   - Validate performance on systems with/without SIMD
   - Ensure all crypto, compression, and core functions work

3. **Regression Testing**:
   - Ensure performance doesn't regress on SSE2-capable systems
   - Validate no security issues introduced
   - Test compatibility with existing applications

## Implementation Details

### SIMD Instruction Mappings

**SSE2 to 3DNow! mappings:**
- `_mm_add_ps(a, b)` → `pfadd(a, b)` [packed float add]
- `_mm_mul_ps(a, b)` → `pfmul(a, b)` [packed float mul] 
- `_mm_sub_ps(a, b)` → `pfsub(a, b)` [packed float sub]
- `_mm_cmplt_ps(a, b)` → `pfcmpge(a, b)` [compare and mask]

**SSE2 to Altivec mappings:**
- `_mm_add_ps(a, b)` → `vec_add(a, b)` [vector add]
- `_mm_mul_ps(a, b)` → `vec_madd(a, b, zero)` [multiply-add with zero]
- `_mm_shuffle_epi32(a, mask)` → `vec_perm(a, a, mask)` [vector permute]

### Runtime Detection Code
```c
// Example detection function
typedef enum {
    SIMD_NONE,
    SIMD_3DNOW,
    SIMD_SSE2,
    SIMD_ALTIVEC
} simd_type_t;

static simd_type_t detect_simd_support() {
    #if defined(__x86_64__) || defined(__i386__)
    // x86 CPU detection
    int cpu_info[4];
    
    // Check for SSE2 (bit 26 of EDX from CPUID function 1)
    __cpuid(1, cpu_info[0], cpu_info[1], cpu_info[2], cpu_info[3]);
    if (cpu_info[3] & (1 << 26)) {
        return SIMD_SSE2;
    }
    
    // Check for 3DNow! (bit 31 of EDX from CPUID function 0x80000001) 
    __cpuid(0x80000001, cpu_info[0], cpu_info[1], cpu_info[2], cpu_info[3]);
    if (cpu_info[3] & (1 << 31)) {
        return SIMD_3DNOW;
    }
    #elif defined(__PPC__) || defined(__powerpc__)
    // PowerPC Altivec detection
    #ifdef __ALTIVEC__
    return SIMD_ALTIVEC;
    #endif
    #endif
    
    return SIMD_NONE;
}
```

### Conditional Compilation Example
```c
#if defined(__SSE2__)
  #include <emmintrin.h>
  // SSE2 implementation
#elif defined(__3dNOW__)
  #include <mm3dnow.h>
  // 3DNow! implementation  
#elif defined(__ALTIVEC__)
  #include <altivec.h>
  // Altivec implementation
#else
  // Scalar fallback implementation
#endif
```

## Risks and Mitigation

### Performance Risks
- 3DNow!/Altivec implementations may be slower than SSE2
- Scalar fallbacks will have worst performance
- Mitigation: Optimize implementations and provide performance validation

### Compatibility Risks  
- Changes may affect existing build systems
- May break some CI systems or deployment scenarios
- Mitigation: Extensive testing and backward compatibility options

### Security Risks
- Different paths may have different timing characteristics
- May introduce side-channel vulnerabilities
- Mitigation: Careful review and constant-time implementation where needed

## Success Metrics

### Functional Metrics
- Node.js builds successfully on systems without SSE2
- All functionality remains available and correct
- No regression in functionality on SSE2+ systems

### Performance Metrics  
- Acceptable performance on 3DNow!/Altivec systems
- No performance regression on SSE2+ systems
- Fallback implementations perform adequately

### Compatibility Metrics
- Maintains support for all currently supported platforms
- No breaking changes for existing users
- Optional feature that doesn't affect current usage patterns

## Timeline
- Phase 1: Assessment and Design - Completed
- Phase 2: Infrastructure - 2-3 weeks
- Phase 3: Library Migration - 3-4 weeks  
- Phase 4: SIMD Implementation - 3-4 weeks
- Phase 5: Build System - 1-2 weeks
- Phase 6: Testing - 2-3 weeks

Total estimated duration: 11-16 weeks