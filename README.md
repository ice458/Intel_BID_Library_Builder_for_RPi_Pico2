# Intel Decimal Floating-Point Math Library Builder for Raspberry Pi Pico 2

This directory contains a script for building the Intel Decimal Floating-Point Math Library (RDFP) specifically optimized for the Raspberry Pi Pico 2 (RP2350) microcontroller.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important**: This project only provides build scripts and configuration. The Intel Decimal Floating-Point Math Library itself is licensed separately under Intel's BSD-style license. Users must obtain the Intel library source code separately and comply with Intel's license terms.

## Overview

The Intel Decimal Floating-Point Math Library (RDFP) provides high-precision decimal floating-point arithmetic operations that are essential for calculator applications and financial computations where binary floating-point precision is insufficient.

## Target Platform

- **MCU**: Raspberry Pi Pico 2 (RP2350)
- **Processor**: ARM Cortex-M33
- **Architecture**: ARMv8-M Mainline with FPU

## Prerequisites

### ARM Toolchain
Install the ARM GNU Embedded Toolchain:

```bash
# Ubuntu/Debian
sudo apt install gcc-arm-none-eabi
```

### Intel Decimal Floating-Point Math Library Source
Download and extract the Intel RDFP Math Library:

1. Download `IntelRDFPMathLib20U2.tar.gz` from Intel
2. Extract it to this directory:
   ```bash
   tar xzf IntelRDFPMathLib20U2.tar.gz
   ```

The directory structure should be:
```
intel-decimal-floating-point-pico2/
├── build.sh
├── README.md
├── IntelRDFPMathLib20U2/
│   ├── LIBRARY/
│   ├── TESTS/
│   └── ...
└── build/          (created during build)
```

## Building

### Quick Start
```bash
./build.sh
```

### Verification Mode (Optional)

You can enable verification mode to check that all patched `const` arrays are placed in read-only memory and not written to at runtime.  
This mode adds section attributes to patched arrays and inspects the resulting library to ensure correct placement.

Enable verification mode by running:
```bash
./build.sh --verify-const
# or
VERIFY_CONST=1 ./build.sh
```
If any `const` array is not placed in a read-only section, the build will fail.

### Advanced Memory Optimization Process

The build script implements a comprehensive memory optimization strategy:

#### 1. **Automated Source Code Patching**
Before compilation, the script automatically patches Intel RDFP source files:
- **Target Files**: Trigonometric, exponential, and mathematical function files
- **Patch Process**: Converts `static` arrays to `static const` arrays
- **Backup Creation**: Original files preserved with `.backup` extension
- **Files Modified**: 14+ source files containing large lookup tables

#### 2. **ROM Placement Verification**
The optimization moves large mathematical lookup tables to Flash ROM:
- **bid_decimal128_moduli**: 288KB per file → Flash ROM (.rodata)
- **bid_decimal64_moduli**: 12KB per file → Flash ROM (.rodata)  
- **bid_decimal32_moduli**: 1.5KB per file → Flash ROM (.rodata)
- **Total RAM Savings**: 300KB+ preserved for application use

### Build Configuration

The build script uses the following optimized settings for Pi Pico 2:

**Compiler Flags:**
- `-mthumb`: Use Thumb instruction set
- `-march=armv8-m.main+fp+dsp`: Target ARMv8-M Mainline with FP and DSP
- `-mfloat-abi=softfp`: Use software floating-point ABI for compatibility
- `-mfpu=fpv5-sp-d16`: Target FPv5 single-precision FPU
- `-mcmse`: Enable Cortex-M Security Extensions (RP2350 feature)
- `-fdata-sections`: Place each data item in its own section for optimal placement
- `-ffunction-sections`: Enable dead code elimination and optimal linking
- `-DARM -DPICO2`: Target-specific preprocessor defines

**Memory Optimization Features:**
- **Automated Source Patching**: Static arrays converted to const arrays before compilation
- **ROM Placement**: Large const arrays (e.g., trigonometric lookup tables) stored in flash memory instead of RAM
- **Section Separation**: Each function and data item in separate sections for fine-grained control
- **RAM Conservation**: 300KB+ of lookup tables moved from .data to .rodata section
- **Embedded Optimization**: Compiler flags specifically tuned for microcontroller memory constraints
- **Verified Results**: objdump-verified ROM placement with zero .data section usage

**Library Configuration:**
- `CALL_BY_REF=1`: Enable call-by-reference mode
- `GLOBAL_RND=1`: Enable global rounding mode
- `GLOBAL_FLAGS=1`: Enable global exception flags
- `UNCHANGED_BINARY_FLAGS=0`: Allow flag modifications

## Output

The build process generates:
- `gcc111libbid_pico2.a`: Optimized Intel Decimal Floating-Point Math Library for Pi Pico 2 (6.6MB)

### Memory Optimization Results (Verified)
- ** ROM Placement Success**: Large lookup tables moved to Flash ROM
- ** RAM Usage**: 0 bytes in .data section for lookup tables  
- ** Flash Usage**: 1MB+ lookup tables in .rodata section
- ** Pi Pico 2**: Full 520KB RAM available for applications

### Modified Source Files
The build process patches the following files with const qualifiers:
- `bid32_sin.c`, `bid32_cos.c`, `bid32_tan.c`
- `bid64_sin.c`, `bid64_cos.c`, `bid64_tan.c`  
- `bid128_sin.c`, `bid128_cos.c`, `bid128_tan.c`
- `bid_decimal_data.c`, `bid128_2_str_tables.c`, `bid_convert_data.c`
- Additional files containing static arrays

## Library Features

The built library provides comprehensive decimal floating-point support:

### Data Types
- **32-bit decimal**: 7 decimal digits precision
- **64-bit decimal**: 16 decimal digits precision  
- **128-bit decimal**: 34 decimal digits precision

### Mathematical Functions
- **Basic arithmetic**: +, -, ×, ÷
- **Trigonometric**: sin, cos, tan, asin, acos, atan, atan2
- **Hyperbolic**: sinh, cosh, tanh, asinh, acosh, atanh
- **Exponential**: exp, exp2, exp10, expm1, pow
- **Logarithmic**: log, log2, log10, log1p
- **Power/Root**: sqrt, cbrt, hypot
- **Special**: erf, erfc, gamma, lgamma

### Utility Functions
- Type conversions (decimal ↔ integer)
- String conversions (decimal ↔ text)
- Comparison operations
- Rounding and truncation
- NaN and infinity handling

## Integration

To use the library in your Pi Pico 2 project:

1. Copy `gcc111libbid_pico2.a` to your project's library directory
2. Include the RDFP headers in your source:
   ```c
   #include "bid_functions.h"
   ```
3. Link against the library:
   ```cmake
   target_link_libraries(your_target gcc111libbid_pico2.a)
   ```

## Example Usage
See this [repository](https://github.com/ice458/Intel_RDFP_Library_Example_for_RPi_Pico2).

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for full license text.

### Third-Party Components

This project builds upon Intel's Decimal Floating-Point Math Library:
- **Intel Library**: Licensed under Intel's BSD-style license
- **Source**: Intel Decimal Floating-Point Math Library (IntelRDFPMathLib20U2)
- **License**: See `IntelRDFPMathLib20U2/eula.txt` for Intel's license terms
- **Availability**: Must be obtained separately from Intel

The build scripts and configuration in this project are original works licensed under MIT.

