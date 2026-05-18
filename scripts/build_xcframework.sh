#!/bin/bash

# ============================================================================
# Paylisher XCFramework Build Script
# ============================================================================
# Build Libraries for Distribution enabled static XCFramework builder
# Supports backward compatibility for different Xcode/Swift versions
# ============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

set -e

# ============================================================================
# Functions
# ============================================================================

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}🚀 $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

usage() {
    echo "Usage: $0 [-s SCHEME_NAME] [-t TOOLCHAIN]"
    echo ""
    echo "Options:"
    echo "  -s    Scheme name (default: Paylisher)"
    echo "  -t    Toolchain identifier or shorthand alias"
    echo "        Use 'swift6' for Swift 6.0 Release toolchain (Xcode 16.x compat)"
    echo "        Use 'swift5' for Swift 5.10 Release toolchain"
    echo "  -h    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                          # Build with default Xcode toolchain"
    echo "  $0 -t swift6               # Build with Swift 6.0 toolchain"
    echo "  $0 -t swift5               # Build with Swift 5.10 toolchain"
    exit 0
}

# ============================================================================
# Parse Arguments
# ============================================================================

SCHEME_NAME="Paylisher"
TOOLCHAIN_ID=""

while getopts "s:t:h" opt; do
    case $opt in
        s) SCHEME_NAME="$OPTARG" ;;
        t) TOOLCHAIN_ID="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ============================================================================
# Toolchain Resolution
# ============================================================================

TOOLCHAIN_FLAG=""
TOOLCHAIN_DISPLAY="Default (Xcode built-in)"

if [ -n "$TOOLCHAIN_ID" ]; then
    # Shorthand aliases
    case "$TOOLCHAIN_ID" in
        swift6|swift6.0|swift60)
            TOOLCHAIN_ID="org.swift.600202409101a"
            ;;
        swift5|swift5.10|swift510)
            TOOLCHAIN_ID="org.swift.5101202403041a"
            ;;
    esac

    # Verify toolchain exists
    TOOLCHAIN_PATH=$(find /Library/Developer/Toolchains -name "*.xctoolchain" -maxdepth 1 2>/dev/null | while read tc; do
        if plutil -p "$tc/Info.plist" 2>/dev/null | grep -q "$TOOLCHAIN_ID"; then
            echo "$tc"
            break
        fi
    done)

    if [ -z "$TOOLCHAIN_PATH" ]; then
        log_error "Toolchain '$TOOLCHAIN_ID' not found! Check installed toolchains in /Library/Developer/Toolchains/"
    fi

    TOOLCHAIN_DISPLAY="$TOOLCHAIN_ID"
    TOOLCHAIN_FLAG="-toolchain $TOOLCHAIN_ID"

    # Show toolchain Swift version
    TOOLCHAIN_SWIFT_VERSION=$("$TOOLCHAIN_PATH/usr/bin/swift" --version 2>/dev/null | head -1)
    log_info "Using toolchain: $TOOLCHAIN_SWIFT_VERSION"
fi

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT" || log_error "Could not change to project directory!"

# Use Xcode 16.1
export DEVELOPER_DIR="/Volumes/Mac/Uygulama 2/Xcode.app/Contents/Developer"

BUILD_DIR="$PROJECT_ROOT/build"
LOG_DIR="$BUILD_DIR/logs"
LOG_FILE="$LOG_DIR/${SCHEME_NAME}_build.log"

XCFRAMEWORK_OUTPUT="$BUILD_DIR/${SCHEME_NAME}.xcframework"
IOS_ARCHIVE="$BUILD_DIR/ios_devices.xcarchive"
SIMULATOR_ARCHIVE="$BUILD_DIR/ios_simulator.xcarchive"

# Create directories
mkdir -p "$LOG_DIR"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

log_section "Build Configuration"
echo -e "  📁 Project Root:  $PROJECT_ROOT"
echo -e "  🎯 Scheme:        $SCHEME_NAME"
echo -e "  🔧 Toolchain:     $TOOLCHAIN_DISPLAY"
echo -e "  📦 Output:        $XCFRAMEWORK_OUTPUT"
echo -e "  📝 Log:           $LOG_FILE"
echo ""

# ============================================================================
# Clean
# ============================================================================

log_section "Cleaning Previous Builds"

# Clean Xcode cache
log_info "Cleaning Xcode build cache..."
xcodebuild clean -project Paylisher.xcodeproj -scheme "$SCHEME_NAME" 2>&1 | tee -a "$LOG_FILE" || true

# Backup existing XCFramework
if [ -d "$XCFRAMEWORK_OUTPUT" ]; then
    BACKUP_NAME="${SCHEME_NAME}_$(date +%Y%m%d_%H%M%S).xcframework"
    log_warning "Backing up existing XCFramework: $BACKUP_NAME"
    mv "$XCFRAMEWORK_OUTPUT" "$BUILD_DIR/$BACKUP_NAME"
fi

# Remove old archives
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"
log_info "Cleanup complete"

# ============================================================================
# Resolve SPM Packages (with default toolchain)
# ============================================================================

if [ -n "$TOOLCHAIN_FLAG" ]; then
    log_section "Resolving SPM Packages (default toolchain)"
    log_info "SPM packages must be resolved with Xcode's default toolchain..."
    xcodebuild -resolvePackageDependencies \
        -project Paylisher.xcodeproj \
        -scheme "$SCHEME_NAME" 2>&1 | tee -a "$LOG_FILE" || log_error "Package resolution failed!"
    log_info "SPM packages resolved successfully"
    DISABLE_PKG_RESOLVE="-disableAutomaticPackageResolution"
else
    DISABLE_PKG_RESOLVE=""
fi

# ============================================================================
# Build iOS Device Archive (arm64)
# ============================================================================

log_section "Building iOS Device Archive (arm64)"

xcodebuild archive \
    -project Paylisher.xcodeproj \
    -scheme "$SCHEME_NAME" \
    -archivePath "$IOS_ARCHIVE" \
    -sdk iphoneos \
    $TOOLCHAIN_FLAG \
    $DISABLE_PKG_RESOLVE \
    SKIP_INSTALL=NO 2>&1 | tee -a "$LOG_FILE" || log_error "iOS device archive failed!"

log_info "iOS device archive completed"

# ============================================================================
# Build iOS Simulator Archive (x86_64 + arm64)
# ============================================================================

log_section "Building iOS Simulator Archive (x86_64, arm64)"

xcodebuild archive \
    -project Paylisher.xcodeproj \
    -scheme "$SCHEME_NAME" \
    -archivePath "$SIMULATOR_ARCHIVE" \
    -sdk iphonesimulator \
    $TOOLCHAIN_FLAG \
    $DISABLE_PKG_RESOLVE \
    SKIP_INSTALL=NO 2>&1 | tee -a "$LOG_FILE" || log_error "Simulator archive failed!"

log_info "Simulator archive completed"

# ============================================================================
# Create XCFramework
# ============================================================================

log_section "Creating XCFramework"

# Dynamically find the framework path inside the archive (location may vary with staticlib)
IOS_FW_PATH=$(find "$IOS_ARCHIVE/Products" -name "${SCHEME_NAME}.framework" -type d 2>/dev/null | head -1)
SIM_FW_PATH=$(find "$SIMULATOR_ARCHIVE/Products" -name "${SCHEME_NAME}.framework" -type d 2>/dev/null | head -1)

[ -z "$IOS_FW_PATH" ]  && log_error "Framework not found in device archive: $IOS_ARCHIVE"
[ -z "$SIM_FW_PATH" ]  && log_error "Framework not found in simulator archive: $SIMULATOR_ARCHIVE"

log_info "Device framework:    $IOS_FW_PATH"
log_info "Simulator framework: $SIM_FW_PATH"

xcodebuild -create-xcframework \
    -framework "$IOS_FW_PATH" \
    -framework "$SIM_FW_PATH" \
    -output "$XCFRAMEWORK_OUTPUT" 2>&1 | tee -a "$LOG_FILE" || log_error "XCFramework creation failed!"

log_info "XCFramework created successfully"

# ============================================================================
# Validation
# ============================================================================

log_section "Validating XCFramework"

# Check 1: Swift Interface exists
log_info "Checking Swift interface files..."
SWIFTINTERFACE_FILES=$(find "$XCFRAMEWORK_OUTPUT" -name "*.swiftinterface" 2>/dev/null | head -5)
if [ -n "$SWIFTINTERFACE_FILES" ]; then
    echo "  Found swift interfaces:"
    echo "$SWIFTINTERFACE_FILES" | while read -r file; do
        echo "    📄 $(basename "$file")"
    done
else
    log_warning "No Swift interface files found!"
fi

# Check 2: _WebKit_SwiftUI import (CRITICAL)
log_info "Checking for _WebKit_SwiftUI import (CRITICAL)..."
if grep -r "_WebKit_SwiftUI" "$XCFRAMEWORK_OUTPUT" 2>/dev/null; then
    echo ""
    log_error "_WebKit_SwiftUI import found! This will break backward compatibility."
else
    log_info "No _WebKit_SwiftUI import found ✅"
fi

# Check 3: Static library verification
log_info "Verifying static library..."
BINARY_PATH=$(find "$XCFRAMEWORK_OUTPUT" -name "$SCHEME_NAME" -type f | head -1)
if [ -n "$BINARY_PATH" ]; then
    FILE_TYPE=$(file "$BINARY_PATH")
    if echo "$FILE_TYPE" | grep -q "ar archive"; then
        log_info "Library type: Static (ar archive) ✅"
    elif echo "$FILE_TYPE" | grep -q "Mach-O"; then
        log_warning "Library type: Dynamic (Mach-O) - Expected static!"
    else
        log_warning "Unknown library type: $FILE_TYPE"
    fi
else
    log_warning "Could not find binary for type check"
fi

# Check 4: Swift compiler version
log_info "Swift interface header info:"
FIRST_INTERFACE=$(echo "$SWIFTINTERFACE_FILES" | head -1)
if [ -n "$FIRST_INTERFACE" ]; then
    head -5 "$FIRST_INTERFACE" | while read -r line; do
        echo "    $line"
    done
fi

# ============================================================================
# Summary
# ============================================================================

log_section "Build Complete"

FRAMEWORK_SIZE=$(du -sh "$XCFRAMEWORK_OUTPUT" | cut -f1)

# Compute checksum
CHECKSUM=""
if [ -f "$XCFRAMEWORK_OUTPUT/../${SCHEME_NAME}.xcframework.zip" ]; then
    rm "$XCFRAMEWORK_OUTPUT/../${SCHEME_NAME}.xcframework.zip"
fi
cd "$BUILD_DIR"
zip -r -q "${SCHEME_NAME}.xcframework.zip" "${SCHEME_NAME}.xcframework"
CHECKSUM=$(swift package compute-checksum "${SCHEME_NAME}.xcframework.zip" 2>/dev/null || shasum -a 256 "${SCHEME_NAME}.xcframework.zip" | cut -d' ' -f1)
cd "$PROJECT_ROOT"

echo -e "${BOLD}${GREEN}🎉 XCFramework Build Successful!${NC}"
echo ""
echo -e "  📦 ${BOLD}Output:${NC}     $XCFRAMEWORK_OUTPUT"
echo -e "  📏 ${BOLD}Size:${NC}       $FRAMEWORK_SIZE"
echo -e "  🔑 ${BOLD}Checksum:${NC}   $CHECKSUM"
echo -e "  📝 ${BOLD}Log:${NC}        $LOG_FILE"
echo ""

# Cleanup archives
log_info "Cleaning up archive files..."
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"

echo -e "\n${CYAN}📋 Next Steps:${NC}"
echo "  1. Test import in Xcode 15.x/16.x project"
echo "  2. Update Package.swift checksum if publishing"
echo "  3. Create GitHub release with ${SCHEME_NAME}.xcframework.zip"
if [ -n "$TOOLCHAIN_FLAG" ]; then
    echo ""
    echo -e "  ${YELLOW}ℹ️  Built with custom toolchain: $TOOLCHAIN_DISPLAY${NC}"
    echo -e "  ${YELLOW}   This build targets backward compatibility with older Xcode versions.${NC}"
fi
echo ""
