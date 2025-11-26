
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
    vector unsigned char packed = vec_pack(x, x);
    // Extract 64-bit result from the packed vector
    uint64_t result;
    vec_ste((vector unsigned long long)packed, 0, (unsigned long long*)&result);
    return result;
#elif defined(__3dNOW__)
    // 3DNow! implementation for AMD Athlon processors
    __m64 x = *reinterpret_cast<const __m64*>(p);
    __m64 result = _mm_packs_pu16(x, x);  // Pack with 3DNow! instruction
    uint64_t ret = *reinterpret_cast<uint32_t*>(&result);
    _m_empty();  // Clean up 3DNow! state
    return ret;
#elif defined(__SSE2__)
    __m128i x = _mm_loadu_si128(reinterpret_cast<const __m128i*>(p));
    __m128i packed = _mm_packus_epi16(x, x);
#ifdef _M_IX86  // 32-bit x86 - _mm_cvtsi128_si64 might not be available
    // Extract lower 64 bits using alternative method
    return _mm_cvtsi128_si32(packed) | (static_cast<uint64_t>(_mm_cvtsi128_si32(_mm_srli_si128(packed, 4))) << 32);
#else
    return _mm_cvtsi128_si64(packed);
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
    vector unsigned char packed = vec_pack(x, x);
    // Extract 64-bit result from the packed vector
    uint64_t result;
    vec_ste((vector unsigned long long)packed, 0, (unsigned long long*)&result);
    return result;
#elif defined(__3dNOW__)
    // 3DNow! implementation for AMD Athlon processors
    __m64 x = *reinterpret_cast<const __m64*>(p);
    __m64 result = _mm_packs_pu16(x, x);  // Pack with 3DNow! instruction
    uint64_t ret = *reinterpret_cast<uint32_t*>(&result);
    _m_empty();  // Clean up 3DNow! state
    return ret;
#elif defined(__SSE2__)
    __m128i x = _mm_loadu_si64(reinterpret_cast<const __m128i*>(p));
    __m128i packed = _mm_packus_epi16(x, x);
#ifdef _M_IX86  // 32-bit x86 - _mm_cvtsi128_si64 might not be available
    // Extract lower 64 bits using alternative method
    return _mm_cvtsi128_si32(packed) | (static_cast<uint64_t>(_mm_cvtsi128_si32(_mm_srli_si128(packed, 4))) << 32);
#else
    return _mm_cvtsi128_si64(packed);
#endif
#elif defined(__ARM_NEON__)
    uint16x4_t x;
    memcpy(&x, p, sizeof(x));
    uint16x8_t x_wide = vcombine_u16(x, x);
    return vget_lane_u32(vreinterpret_u32_u8(vmovn_u16(x_wide)), 0);
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
