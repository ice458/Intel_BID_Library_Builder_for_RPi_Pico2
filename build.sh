#!/bin/bash

# Intel Decimal Floating-Point Math Library Builder for Raspberry Pi Pico 2 (RP2350)
# This script builds the Intel Decimal Floating-Point Math Library (RDFP)
# specifically optimized for the Pi Pico 2's Cortex-M33 processor.
#
# Memory Optimization Features:
# - Source code patches: static arrays → static const arrays for ROM placement
# - Const data arrays placed in ROM (.rodata) instead of RAM (.data)
# - Lookup tables stored in flash memory to save RAM
# - Compiler flags optimized for embedded systems memory usage
# - Function/data section separation for better linker optimization

set -e

# Configuration
PICO2_FLAGS="-mthumb -march=armv8-m.main+fp+dsp -mfloat-abi=softfp -mfpu=fpv5-sp-d16 -mcmse -DARM -DPICO2 -DBID_THREAD= -fdata-sections -ffunction-sections"
BUILD_DIR="build"
OUTPUT_LIB="gcc111libdecimal_pico2.a"
INTEL_LIB_VERSION="IntelRDFPMathLib20U2"

# Verification mode (off by default). Enable by --verify-const or VERIFY_CONST=1
VERIFY_CONST=${VERIFY_CONST:-0}
for arg in "$@"; do
  case "$arg" in
    --verify-const) VERIFY_CONST=1 ;;
  esac
done

# Check for ARM toolchain
if ! which arm-none-eabi-gcc > /dev/null 2>&1; then
  echo "Error: ARM toolchain not found. Please install arm-none-eabi-gcc"
  echo "On Ubuntu/Debian: sudo apt install gcc-arm-none-eabi"
  exit 1
fi

# Readelf detection for verification
if [ "$VERIFY_CONST" -eq 1 ]; then
  if which arm-none-eabi-readelf > /dev/null 2>&1; then
    READELF="arm-none-eabi-readelf"
  elif which readelf > /dev/null 2>&1; then
    READELF="readelf"
  else
    echo "Error: readelf not found (install binutils or arm-none-eabi-binutils)."
    exit 1
  fi
  # Harden warnings (do not promote to errors: upstream macros cast away const)
  PICO2_FLAGS="$PICO2_FLAGS -Wall -Wextra -Wcast-qual"
fi

echo "=== Intel Decimal Floating-Point Math Library Builder for Pi Pico 2 ==="
echo "Target: Raspberry Pi Pico 2 (RP2350 Cortex-M33)"
echo "Compiler: $(arm-none-eabi-gcc --version | head -1)"
echo "Flags: $PICO2_FLAGS"
[ "$VERIFY_CONST" -eq 1 ] && echo "Verification: enabled (.rodata.constcheck; const-cast warnings are not fatal)"
echo

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Check if Intel library source exists
if [ ! -d "../$INTEL_LIB_VERSION" ]; then
  echo "Error: Intel Decimal Floating-Point Math Library source not found!"
  echo "Please extract $INTEL_LIB_VERSION.tar.gz to the project root directory."
  echo "Expected location: ../$INTEL_LIB_VERSION"
  exit 1
fi

# Copy Intel RDFP library sources
if [ ! -d "$INTEL_LIB_VERSION" ]; then
  echo "Copying Intel Decimal Floating-Point Math Library sources..."
  cp -r "../$INTEL_LIB_VERSION" .
fi

cd "$INTEL_LIB_VERSION/LIBRARY"

# Apply memory optimization patches to source code
echo "Applying memory optimization patches..."
echo "- Adding 'const' keyword to static arrays for ROM placement"

# Function to add const to static arrays
add_const_to_static_arrays() {
  local file="$1"
  if [ -f "$file" ]; then
    # Backup original file
    cp "$file" "$file.backup"
    
    # Add const to static array declarations
    sed -i 's/static \([A-Za-z_][A-Za-z0-9_]*\) \([A-Za-z_][A-Za-z0-9_]*\)\[\]/static const \1 \2[]/g' "$file"
    
    # Also handle cases with explicit array sizes
    sed -i 's/static \([A-Za-z_][A-Za-z0-9_]*\) \([A-Za-z_][A-Za-z0-9_]*\)\[\([0-9]*\)\]/static const \1 \2[\3]/g' "$file"

    # Verification mode: put const arrays into a dedicated RO section for checking
    if [ "$VERIFY_CONST" -eq 1 ]; then
      # Append attribute only if not already annotated; match both sized and unsized arrays
      sed -i -E '/rodata\.constcheck/! s/(static[[:space:]]+const[^;=]*\[[^]]*\])/\1 __attribute__((section(".rodata.constcheck")))/g' "$file"
    fi
    
    echo "  ✓ Patched: $file"
  fi
}

# List of files that contain large static arrays that need to be placed in ROM
files_to_patch=(
  "src/bid32_sin.c"
  "src/bid32_cos.c" 
  "src/bid32_tan.c"
  "src/bid64_sin.c"
  "src/bid64_cos.c"
  "src/bid64_tan.c"
  "src/bid128_sin.c"
  "src/bid128_cos.c"
  "src/bid128_tan.c"
  "src/bid_decimal_data.c"
  "src/bid128_2_str_tables.c"
  "src/bid_convert_data.c"
)

# Apply patches to identified files
for file in "${files_to_patch[@]}"; do
  add_const_to_static_arrays "$file"
done

# Also search for any other files with large static arrays
echo "- Scanning for additional static arrays..."
find src -name "*.c" -exec grep -l "static.*\[\]" {} \; | while read file; do
  # Skip if already patched
  if [[ ! " ${files_to_patch[@]} " =~ " $file " ]]; then
    add_const_to_static_arrays "$file"
  fi
done

echo "Building Intel Decimal Floating-Point Math Library for Pi Pico 2..."
echo "This may take several minutes..."
echo

# Clean previous build
make clean > /dev/null 2>&1 || true

# Build the library with Pi Pico 2 specific settings
make \
  CC="arm-none-eabi-gcc $PICO2_FLAGS" \
  CC_NAME=gcc \
  AR="arm-none-eabi-ar" \
  AR_CMD="arm-none-eabi-ar rv" \
  CALL_BY_REF=1 \
  GLOBAL_RND=1 \
  GLOBAL_FLAGS=1 \
  UNCHANGED_BINARY_FLAGS=0 \
  THREAD=0 \
  _HOST_OS=Linux \
  lib

# Verification helper
verify_rodata_constcheck() {
  local libpath="../../$OUTPUT_LIB"
  local tmpdir
  tmpdir="$(mktemp -d)"
  cp "$libpath" "$tmpdir/"
  pushd "$tmpdir" > /dev/null
  arm-none-eabi-ar x "$OUTPUT_LIB"
  local found=0
  local issues=0
  for obj in *.o; do
    [ -e "$obj" ] || continue
    if $READELF -S "$obj" | grep -q '\.rodata\.constcheck'; then
      found=1
      # Extract flags column; ensure no 'W'
      local flags
      flags="$($READELF -S "$obj" | awk '/\.rodata\.constcheck/ {print $7}')"
      if echo "$flags" | grep -q 'W'; then
        echo "  ✗ Writable .rodata.constcheck in $obj (flags=$flags)"
        issues=$((issues+1))
      fi
    fi
  done
  popd > /dev/null
  rm -rf "$tmpdir"
  if [ "$found" -eq 0 ]; then
    echo "Warning: No .rodata.constcheck sections found. Patch may not have annotated arrays."
  fi
  if [ "$issues" -gt 0 ]; then
    echo "Error: Found writable sections for const-annotated arrays ($issues issue(s))."
    exit 1
  fi
  echo "Const write check: OK (read-only sections verified)"
}

# Check if build was successful
if [ -f "libbid.a" ]; then
  # Copy to project root with appropriate name
  cp libbid.a "../../$OUTPUT_LIB"
  # Run verification if enabled
  if [ "$VERIFY_CONST" -eq 1 ]; then
    echo
    echo "Verifying that const arrays are in read-only memory..."
    verify_rodata_constcheck
  fi
  echo
  echo "=== Build Successful ==="
  echo "Output library: $OUTPUT_LIB"
  echo "Size: $(ls -lh ../../$OUTPUT_LIB | awk '{print $5}')"
  echo "Architecture: $(arm-none-eabi-objdump -f ../../$OUTPUT_LIB | grep architecture | head -1)"
  echo
  echo
  echo "Library ready for use with Pi Pico 2 projects!"
  echo "Link with: -L. -ldecimal or add gcc111libdecimal_pico2.a to your project"
else
  echo "Error: Build failed - libbid.a not found"
  exit 1
fi
