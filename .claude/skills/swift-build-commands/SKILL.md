---
name: swift-build-commands
description: Swift Package Manager and Xcode commands for building, testing, documenting, and managing dependencies in a Swift project. Load when building or running a Swift project.
license: MIT
metadata:
  author: Heiko Panjas
  version: "1.0"
---

# Swift Build Commands

Read this skill when you need to build, test, document, or manage dependencies for a Swift project.

---

## Build Commands

### Setup

```bash
# Check Swift version
swift --version

# Check Swift Package Manager version
swift package --version

# Install Xcode Command Line Tools (macOS - if not already installed)
xcode-select --install

# Install Swift (Linux)
# See: https://swift.org/install/linux/
```

### Development

```bash
# Build the project (debug - use during development)
swift build

# Run the application
swift run

# Run with arguments
swift run <target_name> [args]

# Run tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter <test_name>

# Run tests in parallel
swift test --parallel

# Generate code coverage (requires additional setup)
swift test --enable-code-coverage
```

### Build & Deploy

```bash
# Build for release (optimized - use for final testing/deployment only)
swift build -c release

# Run release build
swift run -c release

# Build with verbose output
swift build --verbose

# Clean build artifacts
swift package clean

# Reset package cache and rebuild
swift package reset
rm -rf .build
swift build
```

### Package Management

```bash
# Initialize a new package
swift package init --type <executable|library>

# Update dependencies to latest compatible versions
swift package update

# Resolve dependencies without building
swift package resolve

# Show package dependencies
swift package show-dependencies

# Show dependency tree
swift package show-dependencies --format json

# Edit package in Xcode (macOS)
swift package generate-xcodeproj

# Open package in Xcode (macOS - Swift 5.6+)
open Package.swift
```

### Documentation

```bash
# Generate documentation (requires DocC)
swift package generate-documentation

# Preview documentation (requires DocC)
swift package --disable-sandbox preview-documentation

# Build documentation archive
swift package generate-documentation --output-path ./docs
```

### Code Quality

```bash
# Format code (requires swift-format tool)
swift-format format --in-place --recursive .

# Lint code (requires swift-format tool)
swift-format lint --recursive .

# Run with sanitizers (debug builds)
swift build --sanitize=address
swift build --sanitize=thread

# Build with warnings as errors
swift build -Xswiftc -warnings-as-errors
```

### Advanced Options

```bash
# Build for specific platform
swift build --triple <target_triple>

# Build static library
swift build -c release --static-swift-stdlib

# Show build commands
swift build --verbose

# Build with optimization level
swift build -Xswiftc -O           # Standard optimization
swift build -Xswiftc -Osize       # Optimize for size
swift build -Xswiftc -Ounchecked  # Optimize with no safety checks

# Enable additional compiler flags
swift build -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete

# List available products and targets
swift package dump-package | grep -E '(name|type)'
```

### Cross-Platform Builds

```bash
# Build for iOS (requires macOS with Xcode)
xcodebuild -scheme <scheme_name> -destination 'platform=iOS Simulator,name=iPhone 14'

# Archive for distribution (requires macOS with Xcode)
xcodebuild archive -scheme <scheme_name> -archivePath ./build/App.xcarchive

# Build universal binary (macOS)
swift build -c release --arch arm64 --arch x86_64
```

**Important**: Always use debug builds (`swift build`) during development. Debug builds compile faster and include debugging symbols. Only use release builds (`swift build -c release`) for final testing or deployment.
