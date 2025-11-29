#!/bin/bash

# Script to build Node.js for PowerPC 64-bit systems with AltiVec support
# This uses 64-bit PowerPC compilation flags with AltiVec SIMD instructions
# Designed for Power Mac G5 and other 64-bit PowerPC systems

set -e  # Exit on error

export LC_ALL=C

echo "Setting up Node.js build for 64-bit PowerPC with AltiVec support..."

# Parse command line arguments
CLEAN=false
JOBS=1
SHOW_HELP=false

for arg in "$@"; do
  case $arg in
    --clean)
      CLEAN=true
      ;;
    -j*)
      # Extract the number after -j
      JOBS="${arg#-j}"
      if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [ "$JOBS" -le 0 ]; then
        echo "Error: Invalid argument for -j. Must be a positive integer."
        exit 1
      fi
      ;;
    --help|-h)
      SHOW_HELP=true
      ;;
    *)
      # Ignore unknown arguments for now
      ;;
  esac
done

if [ "$SHOW_HELP" = true ]; then
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --clean    Clean previous build before starting"
  echo "  -jN        Run N build jobs in parallel (default: 1)"
  echo "  --help, -h Show this help message"
  echo ""
  echo "Builds Node.js with AltiVec support for PowerPC 64-bit systems (e.g., Power Mac G5)."
  exit 0
fi

# Ensure we're in the correct directory
cd "$(dirname "$0")"

# Clean any previous build only if --clean flag is provided
if [ "$CLEAN" = true ]; then
  echo "Cleaning previous build..."
  make clean || true
else
  echo "Skipping clean step (use --clean flag to clean previous build)"
fi

# Set environment variables to use 64-bit PowerPC compilation with AltiVec support
# Do NOT use -mvsx flag as Power Mac G5 doesn't support VSX instructions
# Also define the correct endianness for PowerPC (big-endian) to fix OpenSSL endianness issue
# Disable PowerPC-specific simdjson implementation that requires VSX instructions
export CC="gcc -m64 -mcpu=G5 -mtune=G5 -maltivec -mabi=altivec -DSIMDUTF_NO_VSX -DSIMDJSON_IMPLEMENTATION_PPC64=0"
export CXX="g++ -m64 -mcpu=G5 -mtune=G5 -maltivec -mabi=altivec -DSIMDUTF_NO_VSX -DSIMDJSON_IMPLEMENTATION_PPC64=0"
export CPP="cpp -m64 -mcpu=G5 -mtune=G5 -maltivec -mabi=altivec -DSIMDUTF_NO_VSX -DSIMDJSON_IMPLEMENTATION_PPC64=0"

# Additionally set the architecture for GYP to ensure correct OpenSSL config is used
# Include endianness information to help Node.js build system make correct decisions
export GYP_DEFINES="target_arch=ppc64 v8_target_arch=ppc64"
export GYP_CROSSCOMPILE=1

# Force endianness correction by using -include to include a header that ensures correct endianness
# Create temporary header file to force correct endianness after all other definitions
cat > /tmp/ppc64_endian_fix.h << 'EOF'
// Force correct endianness for PowerPC 64-bit big-endian systems
// This prevents silent failures where wrong endianness causes incorrect code paths
#ifdef L_ENDIAN
#undef L_ENDIAN
#endif
#ifndef B_ENDIAN
#define B_ENDIAN
#endif

// Also explicitly define the endianness detection macros to prevent any confusion
#undef __BYTE_ORDER__
#undef __ORDER_LITTLE_ENDIAN__
#undef __ORDER_BIG_ENDIAN__

// Define that this is a big-endian system
#define __BYTE_ORDER__ __ORDER_BIG_ENDIAN__
#define __ORDER_LITTLE_ENDIAN__ 1234
#define __ORDER_BIG_ENDIAN__ 4321

// For additional compatibility with endianness detection code
#if defined(__GNUC__) && defined(__PPC64__)
  // Ensure GCC built-in endianness macros are correct
  #undef __LITTLE_ENDIAN__
  #undef __BIG_ENDIAN__
  #define __BIG_ENDIAN__ 1
#endif
EOF

# Use -include to force inclusion of our endianness correction header
export CFLAGS="-include /tmp/ppc64_endian_fix.h"
export CXXFLAGS="-include /tmp/ppc64_endian_fix.h"
export CPPFLAGS="-include /tmp/ppc64_endian_fix.h"

echo "Configuring build with AltiVec support..."
/usr/bin/env python3 ./configure \
  --dest-cpu=ppc64 \
  --dest-os=linux \
  --without-intl \
  --without-inspector \
  --without-npm \
  --without-node-snapshot \
  --with-simd-support=altivec \
  --openssl-no-asm

# Build with specified parallelism
echo "Starting build with AltiVec support (using $JOBS parallel job(s))..."
make -j"$JOBS"

echo ""
echo "Build completed!"
echo ""
echo "To verify the resulting executable:"
echo "ls -la out/Release/"
echo ""
echo "Note: The resulting executable should be compatible with PowerPC 64-bit systems with AltiVec support (e.g., Power Mac G5)."

# Clean up temporary header file
rm -f /tmp/ppc64_endian_fix.h
