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
WITH_NPM=true
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
    --without-npm)
      WITH_NPM=false
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
  echo "  --clean       Clean previous build before starting"
  echo "  -jN           Run N build jobs in parallel (default: 1)"
  echo "  --without-npm  Build without npm (default: npm is included)"
  echo "  --help, -h    Show this help message"
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

# Apply endianness correction flags specifically for OpenSSL and other affected libraries
# Also force V8 to use portable implementation instead of buggy Altivec implementation
export CFLAGS="$CFLAGS -DB_ENDIAN -UL_ENDIAN -DV8_SWISS_TABLE_HAVE_SSE2_TARGET=1"
export CXXFLAGS="$CXXFLAGS -DB_ENDIAN -UL_ENDIAN -DV8_SWISS_TABLE_HAVE_SSE2_TARGET=1"
export CPPFLAGS="$CPPFLAGS -DB_ENDIAN -UL_ENDIAN -DV8_SWISS_TABLE_HAVE_SSE2_TARGET=1"

# Build configure command based on npm option
CONFIGURE_CMD=("/usr/bin/env python3" "./configure")
CONFIGURE_CMD+=("--dest-cpu=ppc64")
CONFIGURE_CMD+=("--dest-os=linux")
CONFIGURE_CMD+=("--without-intl")
CONFIGURE_CMD+=("--without-inspector")
CONFIGURE_CMD+=("--without-node-snapshot")
CONFIGURE_CMD+=("--with-simd-support=altivec")
CONFIGURE_CMD+=("--openssl-no-asm")

if [ "$WITH_NPM" = false ]; then
  CONFIGURE_CMD+=("--without-npm")
  echo "Configuring build with AltiVec support (without npm)..."
else
  echo "Configuring build with AltiVec support (with npm)..."
fi

# Execute configure command
"${CONFIGURE_CMD[@]}"

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
if [ "$WITH_NPM" = true ]; then
  echo "npm is included in the build."
else
  echo "npm is not included in the build."
fi

# Clean up temporary header file
rm -f /tmp/ppc64_endian_fix.h
