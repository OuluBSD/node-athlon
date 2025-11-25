#ifndef SIMD_ABSTRACTION_H
#define SIMD_ABSTRACTION_H

#include "zlib.h"
#include "cpu_features.h"

/*
 * SIMD Abstraction Layer
 * Provides a unified interface for SIMD operations independent of the actual SIMD instruction set
 */

/* Define which SIMD instruction set to use based on runtime detection */
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
    /* x86/x64 platform - check for available SIMD instruction sets in priority order */
    #if defined(__SSE2__) && x86_cpu_enable_sse2
        #define SIMD_INSTRUCTION_SET SIMD_SSE2
        #define USE_SSE2 1
    #elif defined(__3dNOW__) && x86_cpu_enable_3dnow
        #define SIMD_INSTRUCTION_SET SIMD_3DNOW
        #define USE_3DNOW 1
    #else
        #define SIMD_INSTRUCTION_SET SIMD_SCALAR
        #define USE_SCALAR 1
    #endif
#elif defined(__PPC__) || defined(__powerpc__) || defined(__ppc__) || defined(__PPC64__) || defined(__powerpc64__)
    /* PowerPC platform - check for Altivec */
    #if defined(__ALTIVEC__) && ppc_cpu_enable_altivec
        #define SIMD_INSTRUCTION_SET SIMD_ALTIVEC
        #define USE_ALTIVEC 1
    #else
        #define SIMD_INSTRUCTION_SET SIMD_SCALAR
        #define USE_SCALAR 1
    #endif
#else
    /* Other platforms - use scalar fallback */
    #define SIMD_INSTRUCTION_SET SIMD_SCALAR
    #define USE_SCALAR 1
#endif

/* Enum for SIMD instruction set types */
typedef enum {
    SIMD_NONE = 0,
    SIMD_SCALAR = 1,
    SIMD_SSE2 = 2,
    SIMD_3DNOW = 3,
    SIMD_ALTIVEC = 4
} simd_instruction_set_t;

/* SIMD function declarations */
typedef struct {
    /* Float operations */
    void (*add_ps)(void* a, void* b, void* result);
    void (*mul_ps)(void* a, void* b, void* result);
    void (*sub_ps)(void* a, void* b, void* result);
    /* Integer operations */
    void (*add_epi32)(void* a, void* b, void* result);
    void (*shuffle_epi32)(void* a, int mask, void* result);
} simd_functions_t;

/* Get the currently active SIMD instruction set */
simd_instruction_set_t get_active_simd_instruction_set(void);

/* Get the SIMD function table for the active instruction set */
const simd_functions_t* get_simd_functions(void);

/* Check if specific SIMD instruction set is available at runtime */
int is_simd_available(simd_instruction_set_t instruction_set);

#endif /* SIMD_ABSTRACTION_H */