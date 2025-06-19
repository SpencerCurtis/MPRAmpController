#!/bin/bash

# MPRAmpController x86 Build Script
# Builds the application for Intel x86_64 architecture and places it in the binary folder

set -e  # Exit on any error

echo "🚀 Building MPRAmpController for x86_64 architecture..."
echo "============================================="

# Generate embedded templates from .leaf files
echo "📝 Generating embedded templates..."
if [ -f "generate-embedded-templates.sh" ]; then
    chmod +x generate-embedded-templates.sh
    ./generate-embedded-templates.sh
else
    echo "⚠️  generate-embedded-templates.sh not found, skipping template generation"
fi

# Optional: Clean previous build artifacts (use --clean flag)
if [[ "$1" == "--clean" ]]; then
    echo "🧹 Cleaning previous builds..."
    rm -rf .build/x86_64-apple-macosx
else
    echo "ℹ️  Using incremental build (use --clean for fresh build)"
fi

# Build for x86_64 in release configuration
echo "🔨 Building for x86_64..."
swift build --configuration release --arch x86_64

# Check if build was successful
if [ ! -f ".build/x86_64-apple-macosx/release/Run" ]; then
    echo "❌ Build failed - executable not found!"
    exit 1
fi

# Create binary directory if it doesn't exist
echo "📁 Preparing binary directory..."
mkdir -p binary

# Copy the executable to binary folder as "Run"
echo "📦 Copying executable to binary/Run..."
cp .build/x86_64-apple-macosx/release/Run binary/Run

# Copy Resources directory for Leaf templates
echo "📂 Copying Resources directory..."
if [ -d "Sources/App/Resources" ]; then
    cp -r Sources/App/Resources binary/
    echo "✅ Resources copied to binary/Resources"
else
    echo "⚠️  No Resources directory found"
fi

# Set executable permissions
chmod +x binary/Run

# Verify the build
echo "✅ Verifying the executable..."
file binary/Run
ls -la binary/Run

echo ""
echo "🎉 Build complete!"
echo "============================================="
echo "📍 Executable location: binary/Run"
echo "🏗️  Architecture: $(file binary/Run | grep -o 'x86_64')"
echo "📏 Size: $(du -h binary/Run | cut -f1)"
echo ""
echo "🚀 Ready to deploy to your Intel Mac mini!"
echo "   Run with: ./binary/Run"
echo "   Access at: http://localhost:8080"
echo ""
echo "💡 Usage: ./build-x86.sh [--clean]"
echo "   --clean: Force a clean build (slower but guaranteed fresh)" 