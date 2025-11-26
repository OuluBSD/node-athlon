#!/bin/bash

# Script to build Node.js for x86 systems with SSE2 support
# This uses 32-bit compilation flags with SSE2 instructions

set -e  # Exit on error

echo "Setting up Node.js build for 32-bit x86 with SSE2 support..."

# Parse command line arguments
CLEAN=false
SHOW_HELP=false

for arg in "$@"; do
  case $arg in
    --clean)
      CLEAN=true
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
  echo "  --help, -h Show this help message"
  echo ""
  echo "Builds Node.js with SSE2 support for x86 systems."
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

# Set environment variables to use 32-bit compilation with SSE2 support
export CC="gcc -m32 -march=pentium4 -msse2 -mfpmath=sse -mmmx"
export CXX="g++ -m32 -march=pentium4 -msse2 -mfpmath=sse -mmmx"
export CPP="cpp -m32 -march=pentium4 -msse2 -mfpmath=sse -mmmx"

echo "Configuring build with SSE2 support..."
/usr/bin/env python3 ./configure \
  --dest-cpu=ia32 \
  --dest-os=linux \
  --without-intl \
  --without-inspector \
  --without-npm \
  --without-node-snapshot \
  --with-simd-support=sse2

# Build with reduced parallelism to conserve memory
echo "Starting build with SSE2 support (using single thread to conserve memory)..."
make -j1

echo ""
echo "Build completed!"
echo ""
echo "To verify the resulting executable:"
echo "ls -la out/Release/"
echo ""
echo "Note: The resulting executable should be compatible with x86 systems with SSE2 support."