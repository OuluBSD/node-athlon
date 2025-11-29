
// Copyright 2024 the V8 project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "src/strings/string-hasher.h"

#include "src/strings/string-hasher-inl.h"

namespace v8::internal {

struct ConvertTo8BitHashReader {
  static constexpr unsigned kCompressionFactor = 2;
  static constexpr unsigned kExpansionFactor = 1;

  V8_INLINE static uint64_t Read64(const uint8_t* ptr) {
    const uint16_t* p = reinterpret_cast<const uint16_t*>(ptr);
    DCHECK_LE(p[0], 0xff);
    DCHECK_LE(p[1], 0xff);
    DCHECK_LE(p[2], 0xff);
    DCHECK_LE(p[3], 0xff);
    DCHECK_LE(p[4], 0xff);
    DCHECK_LE(p[5], 0xff);
    DCHECK_LE(p[6], 0xff);
    DCHECK_LE(p[7], 0xff);
#ifdef __ALTIVEC__
    // Altivec implementation for PowerPC systems (like G5)
    vector unsigned short x = vec_ld(0, p);
    vector unsigned short y = vec_ld(8, p); // Load second set of 16-bit values
    vector unsigned char packed = vec_pack(x, y);
    // Extract 64-bit result from the packed vector
    uint64_t result;
    // Use vec_extract to get the lower 64 bits properly
    union { vector unsigned char v; uint64_t u64[2]; } converter = { .v = packed };
    result = converter.u64[0];
    return result;
#elif defined(__3dNOW__)
    // 3DNow! implementation for AMD Athlon processors
    // Since _m_packuswb isn't always available, we'll use a manual approach
    uint64_t result = 0;
    for (int i = 0; i < 8; ++i) {
        result |= (static_cast<uint64_t>(p[i]) & 0xFF) << (i * 8);
    }
    _m_empty();  // Clean up 3DNow! state
    return result;
#elif defined(__SSE2__)
    // Load 16-bit values into 2 64-bit registers and pack them to 8-bit values
    __m128i x_low = _mm_loadl_epi64(reinterpret_cast<const __m128i*>(p));      // Load first 4 16-bit values
    __m128i x_high = _mm_loadl_epi64(reinterpret_cast<const __m128i*>(p + 4)); // Load last 4 16-bit values
    __m128i packed = _mm_packus_epi16(x_low, x_high);
#ifdef V8_TARGET_ARCH_32_BIT
    // On 32-bit systems, use alternative method for 64-bit extraction
    uint32_t low = _mm_cvtsi128_si32(packed);
    uint32_t high = _mm_cvtsi128_si32(_mm_shuffle_epi32(packed, 1));
    return low | (static_cast<uint64_t>(high) << 32);
#elif defined(__x86_64__) || defined(_M_X64)
    // On 64-bit systems, _mm_cvtsi128_si64 is available
    return _mm_cvtsi128_si64(packed);
#else
    // For other cases, use the portable method
    uint32_t low = _mm_cvtsi128_si32(packed);
    uint32_t high = _mm_cvtsi128_si32(_mm_shuffle_epi32(packed, 1));
    return low | (static_cast<uint64_t>(high) << 32);
#endif
#elif defined(__ARM_NEON__)
    uint16x8_t x;
    memcpy(&x, p, sizeof(x));
    return vget_lane_u64(vreinterpret_u64_u8(vmovn_u16(x)), 0);
#else
    return (uint64_t{p[0]}) | (uint64_t{p[1]} << 8) | (uint64_t{p[2]} << 16) |
           (uint64_t{p[3]} << 24) | (uint64_t{p[4]} << 32) |
           (uint64_t{p[5]} << 40) | (uint64_t{p[6]} << 48) |
           (uint64_t{p[7]} << 56);
#endif
  }

  V8_INLINE static uint64_t Read32(const uint8_t* ptr) {
    const uint16_t* p = reinterpret_cast<const uint16_t*>(ptr);
    DCHECK_LE(p[0], 0xff);
    DCHECK_LE(p[1], 0xff);
    DCHECK_LE(p[2], 0xff);
    DCHECK_LE(p[3], 0xff);
#ifdef __ALTIVEC__
    // Altivec implementation for PowerPC systems (like G5)
    vector unsigned short x = vec_ld(0, p);
    vector unsigned short y = vec_splat_s16(0); // Zero vector for packing
    vector unsigned char packed = vec_pack(x, y);
    // Extract 32-bit result from the packed vector (as low 32 bits)
    union { vector unsigned char v; uint32_t u32[4]; } converter = { .v = packed };
    return static_cast<uint64_t>(converter.u32[0]);
#elif defined(__3dNOW__)
    // 3DNow! implementation for AMD Athlon processors
    // Since _m_packuswb isn't always available, we'll use a manual approach
    uint64_t result = 0;
    for (int i = 0; i < 4; ++i) {
        result |= (static_cast<uint64_t>(p[i]) & 0xFF) << (i * 8);
    }
    _m_empty();  // Clean up 3DNow! state
    return result;
#elif defined(__SSE2__)
    // Load 16-bit values and pack them to 8-bit values
    // Only pack first 4 16-bit values to get 4 8-bit values
    __m128i x = _mm_setzero_si128();
    x = _mm_insert_epi16(x, p[0], 0);
    x = _mm_insert_epi16(x, p[1], 1);
    x = _mm_insert_epi16(x, p[2], 2);
    x = _mm_insert_epi16(x, p[3], 3);
    __m128i packed = _mm_packus_epi16(x, x);
#ifdef V8_TARGET_ARCH_32_BIT
    // On 32-bit systems, use the safe method
    return static_cast<uint64_t>(_mm_cvtsi128_si32(packed));
#elif defined(__x86_64__) || defined(_M_X64)
    return static_cast<uint64_t>(_mm_cvtsi128_si64(packed));
#else
    return static_cast<uint64_t>(_mm_cvtsi128_si32(packed));
#endif
#elif defined(__ARM_NEON__)
    uint16x4_t x;
    memcpy(&x, p, sizeof(x));
    uint16x8_t x_wide = vcombine_u16(x, x);
    return static_cast<uint64_t>(vget_lane_u32(vreinterpret_u32_u8(vmovn_u16(x_wide)), 0));
#else
    return (uint64_t{p[0]}) | (uint64_t{p[1]} << 8) | (uint64_t{p[2]} << 16) |
           (uint64_t{p[3]} << 24);
#endif
  }

  V8_INLINE static uint64_t ReadSmall(const uint8_t* ptr, size_t k) {
    const uint16_t* p = reinterpret_cast<const uint16_t*>(ptr);
    DCHECK_LE(p[0], 0xff);
    DCHECK_LE(p[k >> 1], 0xff);
    DCHECK_LE(p[k - 1], 0xff);
    return (uint64_t{p[0]} << 56) | (uint64_t{p[k >> 1]} << 32) | p[k - 1];
  }
};

namespace detail {
uint64_t HashConvertingTo8Bit(const uint16_t* chars, uint32_t length,
                              uint64_t seed, const uint64_t secret[3]) {
  return rapidhash<ConvertTo8BitHashReader>(
      reinterpret_cast<const uint8_t*>(chars), length, seed, secret);
}
}  // namespace detail

}  // namespace v8::internal
