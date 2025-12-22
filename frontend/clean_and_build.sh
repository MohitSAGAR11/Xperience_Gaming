#!/bin/bash

# Clean and Build Script for Flutter Android APK
# This script cleans all build caches and rebuilds a fresh APK

echo "🧹 Starting Clean Build Process..."
echo ""

# Step 1: Clean Flutter build cache
echo "Step 1/6: Cleaning Flutter build cache..."
flutter clean
if [ $? -ne 0 ]; then
    echo "❌ Flutter clean failed!"
    exit 1
fi
echo "✅ Flutter cache cleaned"
echo ""

# Step 2: Clean Android build directories
echo "Step 2/6: Cleaning Android build directories..."
if [ -d "android/build" ]; then
    rm -rf android/build
    echo "✅ Removed android/build"
fi
if [ -d "android/app/build" ]; then
    rm -rf android/app/build
    echo "✅ Removed android/app/build"
fi
if [ -d "build" ]; then
    rm -rf build
    echo "✅ Removed build directory"
fi
echo ""

# Step 3: Clean Gradle cache
echo "Step 3/6: Cleaning Gradle cache..."
cd android
if [ -d ".gradle" ]; then
    rm -rf .gradle
    echo "✅ Removed .gradle cache"
fi
./gradlew clean
if [ $? -ne 0 ]; then
    echo "⚠️ Gradle clean had issues, continuing anyway..."
fi
cd ..
echo ""

# Step 4: Get Flutter packages
echo "Step 4/6: Getting Flutter packages..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Flutter pub get failed!"
    exit 1
fi
echo "✅ Packages fetched"
echo ""

# Step 5: Build release APK
echo "Step 5/6: Building release APK..."
echo "This may take a few minutes..."
flutter build apk --release
if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo ""

# Step 6: Show output location
echo "Step 6/6: Build complete!"
echo ""
echo "📦 APK Location:"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    echo "   $APK_PATH"
    echo "   Size: $(du -h "$APK_PATH" | cut -f1)"
    echo "   Modified: $(stat -f "%Sm" "$APK_PATH" 2>/dev/null || stat -c "%y" "$APK_PATH" 2>/dev/null || echo "N/A")"
else
    echo "   ⚠️ APK not found at expected location"
fi
echo ""
echo "✅ Clean build process completed successfully!"

