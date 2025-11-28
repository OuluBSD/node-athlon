#!/bin/bash

# Script to build Node.js using native architecture optimizations for 32-bit x86
# This uses the host system's native architecture but forces 32-bit compilation

set -e  # Exit on error

echo "Setting up Node.js build with 32-bit native architecture optimizations..."

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
  echo "Builds Node.js using native 32-bit x86 architecture optimizations for the host system."
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

# Set environment variables to use native architecture with 32-bit target and auto-detected SIMD support
export CC="gcc -march=native -m32"
export CXX="g++ -march=native -m32"
export CPP="cpp -march=native -m32"

# Ensure 32-bit development libraries are available
if [ ! -d "/usr/include/i386-linux-gnu" ] && [ ! -f "/usr/include/gnu/stubs-32.h" ]; then
  echo "Warning: 32-bit development libraries may not be installed."
  echo "On Debian/Ubuntu systems, you may need to run: sudo apt-get install gcc-multilib g++-multilib libc6-dev-i386"
  echo "Continuing with build..."
fi

echo "Configuring build with 32-bit native architecture optimizations..."
/usr/bin/env python3 ./configure \
  --dest-cpu=ia32 \
  --dest-os=linux \
  --without-intl \
  --without-inspector \
  --without-npm \
  --without-node-snapshot

# Build with specified parallelism
echo "Starting build with 32-bit native optimizations (using $JOBS parallel job(s))..."
make -j"$JOBS"

echo ""
echo "Build completed!"
echo ""
echo "To verify the resulting executable:"
echo "ls -la out/Release/"
echo ""
echo "Note: The resulting executable is optimized for 32-bit x86 architecture with native optimizations."