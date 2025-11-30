#!/bin/bash

# Script to build Node.js using native architecture optimizations
# This uses the host system's native architecture and available SIMD instructions

set -e  # Exit on error

echo "Setting up Node.js build with native architecture optimizations..."

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

# Build configure command based on npm option
CONFIGURE_CMD=("/usr/bin/env python3" "./configure")
CONFIGURE_CMD+=("--dest-cpu=x64")
CONFIGURE_CMD+=("--dest-os=linux")
CONFIGURE_CMD+=("--without-intl")
CONFIGURE_CMD+=("--without-inspector")
CONFIGURE_CMD+=("--without-node-snapshot")

if [ "$WITH_NPM" = false ]; then
  CONFIGURE_CMD+=("--without-npm")
  echo "Configuring build with native architecture optimizations (without npm)..."
else
  echo "Configuring build with native architecture optimizations (with npm)..."
fi

# Execute configure command
"${CONFIGURE_CMD[@]}"

# Build with specified parallelism
echo "Starting build with native optimizations (using $JOBS parallel job(s))..."
make -j"$JOBS"

echo ""
echo "Build completed!"
echo ""
echo "To verify the resulting executable:"
echo "ls -la out/Release/"
echo ""
echo "Note: The resulting executable is optimized for the host system architecture."
if [ "$WITH_NPM" = true ]; then
  echo "npm is included in the build."
else
  echo "npm is not included in the build."
fi