#include "simd_abstraction.h"
#include <stdint.h>

/* Define SIMD instruction set constants */
static simd_instruction_set_t current_simd_instruction_set = SIMD_NONE;

/* Function pointers for SIMD operations */
static simd_functions_t simd_funcs = {0};

/* Initialize SIMD function pointers based on runtime detection */
static void init_simd_functions(void) {
    /* Initialize function pointers based on detected SIMD capabilities */
    cpu_check_features(); /* Ensure CPU features are detected */
    
    #if defined(USE_SSE2)
        /* Initialize SSE2 function pointers */
        #ifdef __SSE2__
        #include <emmintrin.h>
        simd_funcs.add_ps = sse2_add_ps;
        simd_funcs.mul_ps = sse2_mul_ps;
        simd_funcs.sub_ps = sse2_sub_ps;
        simd_funcs.add_epi32 = sse2_add_epi32;
        simd_funcs.shuffle_epi32 = sse2_shuffle_epi32;
        current_simd_instruction_set = SIMD_SSE2;
        #endif
    #elif defined(USE_3DNOW)
        /* Initialize 3DNow! function pointers */
        #ifdef __3dNOW__
        #include <mm3dnow.h>
        simd_funcs.add_ps = d3now_add_ps;
        simd_funcs.mul_ps = d3now_mul_ps;
        simd_funcs.sub_ps = d3now_sub_ps;
        /* Note: 3DNow! has limited integer operations */
        simd_funcs.add_epi32 = scalar_add_epi32;  /* Fallback to scalar */
        simd_funcs.shuffle_epi32 = scalar_shuffle_epi32;  /* Fallback to scalar */
        current_simd_instruction_set = SIMD_3DNOW;
        #endif
    #elif defined(USE_ALTIVEC)
        /* Initialize Altivec function pointers */
        #ifdef __ALTIVEC__
        #include <altivec.h>
        simd_funcs.add_ps = altivec_add_ps;
        simd_funcs.mul_ps = altivec_mul_ps;
        simd_funcs.sub_ps = altivec_sub_ps;
        simd_funcs.add_epi32 = altivec_add_epi32;
        simd_funcs.shuffle_epi32 = altivec_shuffle_epi32;
        current_simd_instruction_set = SIMD_ALTIVEC;
        #endif
    #else
        /* Use scalar implementations */
        simd_funcs.add_ps = scalar_add_ps;
        simd_funcs.mul_ps = scalar_mul_ps;
        simd_funcs.sub_ps = scalar_sub_ps;
        simd_funcs.add_epi32 = scalar_add_epi32;
        simd_funcs.shuffle_epi32 = scalar_shuffle_epi32;
        current_simd_instruction_set = SIMD_SCALAR;
    #endif
}

/* SSE2 implementations */
#ifdef __SSE2__
#include <emmintrin.h>

static void sse2_add_ps(void* a, void* b, void* result) {
    __m128* va = (__m128*)a;
    __m128* vb = (__m128*)b;
    __m128* vr = (__m128*)result;
    *vr = _mm_add_ps(*va, *vb);
}

static void sse2_mul_ps(void* a, void* b, void* result) {
    __m128* va = (__m128*)a;
    __m128* vb = (__m128*)b;
    __m128* vr = (__m128*)result;
    *vr = _mm_mul_ps(*va, *vb);
}

static void sse2_sub_ps(void* a, void* b, void* result) {
    __m128* va = (__m128*)a;
    __m128* vb = (__m128*)b;
    __m128* vr = (__m128*)result;
    *vr = _mm_sub_ps(*va, *vb);
}

static void sse2_add_epi32(void* a, void* b, void* result) {
    __m128i* va = (__m128i*)a;
    __m128i* vb = (__m128i*)b;
    __m128i* vr = (__m128i*)result;
    *vr = _mm_add_epi32(*va, *vb);
}

static void sse2_shuffle_epi32(void* a, int mask, void* result) {
    __m128i* va = (__m128i*)a;
    __m128i* vr = (__m128i*)result;
    *vr = _mm_shuffle_epi32(*va, mask);
}
#endif

/* 3DNow! implementations */
#ifdef __3dNOW__
#include <mm3dnow.h>

static void d3now_add_ps(void* a, void* b, void* result) {
    __m64* va = (__m64*)a;
    __m64* vb = (__m64*)b;
    __m64* vr = (__m64*)result;
    
    // 3DNow! operates on 2 floats at a time
    *vr = _mm_add_pi32(*va, *vb);
    // Note: This is a simplified example - 3DNow! has specific instructions like pfadd
    // that need proper usage
}

static void d3now_mul_ps(void* a, void* b, void* result) {
    __m64* va = (__m64*)a;
    __m64* vb = (__m64*)b;
    __m64* vr = (__m64*)result;
    
    // 3DNow! specific multiplication
    *vr = _mm_mul_pi32(*va, *vb);
}

static void d3now_sub_ps(void* a, void* b, void* result) {
    __m64* va = (__m64*)a;
    __m64* vb = (__m64*)b;
    __m64* vr = (__m64*)result;
    
    *vr = _mm_sub_pi32(*va, *vb);
}
#endif

/* Altivec implementations */
#ifdef __ALTIVEC__
#include <altivec.h>

static void altivec_add_ps(void* a, void* b, void* result) {
    vector float* va = (vector float*)a;
    vector float* vb = (vector float*)b;
    vector float* vr = (vector float*)result;
    *vr = vec_add(*va, *vb);
}

static void altivec_mul_ps(void* a, void* b, void* result) {
    vector float* va = (vector float*)a;
    vector float* vb = (vector float*)b;
    vector float* vr = (vector float*)result;
    *vr = vec_madd(*va, *vb, vec_splat_u32(0));  // For multiply, we use vec_mul or vec_madd
}

static void altivec_sub_ps(void* a, void* b, void* result) {
    vector float* va = (vector float*)a;
    vector float* vb = (vector float*)b;
    vector float* vr = (vector float*)result;
    *vr = vec_sub(*va, *vb);
}

static void altivec_add_epi32(void* a, void* b, void* result) {
    vector signed int* va = (vector signed int*)a;
    vector signed int* vb = (vector signed int*)b;
    vector signed int* vr = (vector signed int*)result;
    *vr = vec_add(*va, *vb);
}

static void altivec_shuffle_epi32(void* a, int mask, void* result) {
    vector signed int* va = (vector signed int*)a;
    vector signed int* vr = (vector signed int*)result;
    
    // Use vec_perm for shuffling, which requires a permutation vector
    // This is a simplified implementation
    vector unsigned char perm_vec = vec_lvsl(0, (int*)mask);  // This is just an example
    *vr = vec_perm(*va, *va, (vector unsigned char)perm_vec);
}
#endif

/* Scalar implementations as fallback */
static void scalar_add_ps(void* a, void* b, void* result) {
    float* fa = (float*)a;
    float* fb = (float*)b;
    float* fr = (float*)result;
    for (int i = 0; i < 4; i++) {
        fr[i] = fa[i] + fb[i];
    }
}

static void scalar_mul_ps(void* a, void* b, void* result) {
    float* fa = (float*)a;
    float* fb = (float*)b;
    float* fr = (float*)result;
    for (int i = 0; i < 4; i++) {
        fr[i] = fa[i] * fb[i];
    }
}

static void scalar_sub_ps(void* a, void* b, void* result) {
    float* fa = (float*)a;
    float* fb = (float*)b;
    float* fr = (float*)result;
    for (int i = 0; i < 4; i++) {
        fr[i] = fa[i] - fb[i];
    }
}

static void scalar_add_epi32(void* a, void* b, void* result) {
    int32_t* ia = (int32_t*)a;
    int32_t* ib = (int32_t*)b;
    int32_t* ir = (int32_t*)result;
    for (int i = 0; i < 4; i++) {
        ir[i] = ia[i] + ib[i];
    }
}

static void scalar_shuffle_epi32(void* a, int mask, void* result) {
    int32_t* ia = (int32_t*)a;
    int32_t* ir = (int32_t*)result;
    
    // Extract mask components (for SSE2-style shuffle mask)
    ir[0] = ia[(mask >> 0) & 0x3];
    ir[1] = ia[(mask >> 2) & 0x3];
    ir[2] = ia[(mask >> 4) & 0x3];
    ir[3] = ia[(mask >> 6) & 0x3];
}

/* Public API functions */
simd_instruction_set_t get_active_simd_instruction_set(void) {
    if (current_simd_instruction_set == SIMD_NONE) {
        init_simd_functions();
    }
    return current_simd_instruction_set;
}

const simd_functions_t* get_simd_functions(void) {
    if (current_simd_instruction_set == SIMD_NONE) {
        init_simd_functions();
    }
    return &simd_funcs;
}

int is_simd_available(simd_instruction_set_t instruction_set) {
    switch(instruction_set) {
        case SIMD_SSE2:
            return x86_cpu_enable_sse2;
        case SIMD_3DNOW:
            return x86_cpu_enable_3dnow;
        case SIMD_ALTIVEC:
            return ppc_cpu_enable_altivec;
        case SIMD_SCALAR:
            return 1;  /* Scalar is always available */
        default:
            return 0;
    }
}