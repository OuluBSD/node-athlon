#!/bin/bash

# Script to build Node.js using native architecture optimizations
# This uses the host system's native architecture and available SIMD instructions

set -e  # Exit on error

echo "Setting up Node.js build with native architecture optimizations..."

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
  echo "Builds Node.js using native architecture optimizations for the host system."
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

# Set environment variables to use native architecture with auto-detected SIMD support
export CC="gcc -march=native"
export CXX="g++ -march=native"
export CPP="cpp -march=native"

echo "Configuring build with native architecture optimizations..."
/usr/bin/env python3 ./configure \
  --dest-cpu=x64 \
  --dest-os=linux \
  --without-intl \
  --without-inspector \
  --without-npm \
  --without-node-snapshot

# Build with reduced parallelism to conserve memory
echo "Starting build with native optimizations (using single thread to conserve memory)..."
make -j1

echo ""
echo "Build completed!"
echo ""
echo "To verify the resulting executable:"
echo "ls -la out/Release/"
echo ""
echo "Note: The resulting executable is optimized for the host system architecture."