#!/bin/bash

# Script to build Node.js for ARM Hard Float (ARMHF) 32-bit systems
# This uses 32-bit ARM compilation flags with ARMv7, VFPv3 and NEON instructions
# Designed for ARM-based devices that support hard float ABI (ARMHF)

set -e  # Exit on error

export LC_ALL=C

echo "Setting up Node.js build for ARM Hard Float (ARMHF) 32-bit systems with NEON support..."

# Parse command line arguments
CLEAN=false
JOBS=1
WITH_NPM=true
WITH_INTL=true
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
    --without-intl)
      WITH_INTL=false
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
  echo "  --without-intl Build without internationalization (default: intl is included)"
  echo "  --help, -h    Show this help message"
  echo ""
  echo "Builds Node.js with ARMv7, VFPv3 and NEON support for ARMHF 32-bit systems."
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

# Set environment variables to use ARM 32-bit compilation with ARMv7, VFPv3 and NEON support
# Using hard-float ABI which is standard for ARMHF targets
export CC="arm-linux-gnueabihf-gcc -march=armv7-a -mfpu=neon -mfloat-abi=hard -ftree-vectorize -fsingle-precision-constant -funroll-loops -ffast-math"
export CXX="arm-linux-gnueabihf-g++ -march=armv7-a -mfpu=neon -mfloat-abi=hard -ftree-vectorize -fsingle-precision-constant -funroll-loops -ffast-math"
export CPP="arm-linux-gnueabihf-cpp -march=armv7-a -mfpu=neon -mfloat-abi=hard"

# If cross-compiler is not available, try using standard gcc with march settings
if ! command -v arm-linux-gnueabihf-gcc &>/dev/null; then
  echo "Cross-compiler arm-linux-gnueabihf-gcc not found, trying to use standard gcc with ARM flags..."
  export CC="gcc -march=armv7-a -mfpu=vfpv3 -mfloat-abi=hard -ftree-vectorize -fsingle-precision-constant -funroll-loops -ffast-math"
  export CXX="g++ -march=armv7-a -mfpu=vfpv3 -mfloat-abi=hard -ftree-vectorize -fsingle-precision-constant -funroll-loops -ffast-math"
  export CPP="cpp -march=armv7-a -mfpu=vfpv3 -mfloat-abi=hard"
fi

# Additional flags for ARMHF build
export CFLAGS="$CFLAGS -mcpu=cortex-a7 -marm -mfpu=neon -mfloat-abi=hard"
export CXXFLAGS="$CXXFLAGS -mcpu=cortex-a7 -marm -mfpu=neon -mfloat-abi=hard"
export LDFLAGS="$LDFLAGS -Wl,-z,nocopyreloc"

# Additional variables for GYP build system to ensure ARMHF compatibility
export GYP_DEFINES="target_arch=arm v8_target_arch=arm arm_version=7 arm_float_abi=hard arm_fpu=neon"
export GYP_CROSSCOMPILE=1

# To handle potential issues with V8 optimizations that can cause problems on ARM
export GYP_DEFINES="$GYP_DEFINES v8_enable_backtrace=0 v8_enable_slow_dcheck=0 v8_optimized_debugging=0"

# For the --with-simd-support flag, since NEON is not an officially supported option
# we'll use 'auto' which should detect available SIMD capabilities at runtime
# or 'none' to ensure compatibility
CONFIGURE_CMD=("/usr/bin/env" "python3" "./configure")
CONFIGURE_CMD+=("--dest-cpu=arm")
CONFIGURE_CMD+=("--dest-os=linux")
CONFIGURE_CMD+=("--without-inspector")
CONFIGURE_CMD+=("--without-node-snapshot")
CONFIGURE_CMD+=("--with-arm-fpu=neon")
CONFIGURE_CMD+=("--with-arm-float-abi=hard")
CONFIGURE_CMD+=("--with-simd-support=neon")  # Use NEON SIMD instructions

if [ "$WITH_NPM" = false ]; then
  CONFIGURE_CMD+=("--without-npm")
  echo "Configuring build for ARMHF (without npm)..."
else
  echo "Configuring build for ARMHF (with npm)..."
fi

if [ "$WITH_INTL" = false ]; then
  CONFIGURE_CMD+=("--without-intl")
  echo "Configuring build for ARMHF (without internationalization)..."
else
  echo "Configuring build for ARMHF (with internationalization)..."
fi

# Execute configure command
echo "${CONFIGURE_CMD[@]}"
"${CONFIGURE_CMD[@]}"

# Build with specified parallelism
echo "Starting build for ARMHF (using $JOBS parallel job(s))..."
make -j"$JOBS"

echo ""
echo "Build completed!"
echo ""
echo "To verify the resulting executable:"
echo "ls -la out/Release/"
echo ""
echo "Note: The resulting executable should be compatible with ARM Hard Float (ARMHF) 32-bit systems with NEON SIMD support."
if [ "$WITH_NPM" = true ]; then
  echo "npm is included in the build."
else
  echo "npm is not included in the build."
fi