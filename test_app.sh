#!/bin/bash

# Galaxy Watch iOS App - Testing Script
# This script builds, installs, and launches the Galaxy Watch app on iOS Simulator

set -e

PROJECT_PATH="/Users/akhil/Projects/repos/galaxy watch"
PROJECT_NAME="galaxy watch"
SCHEME="galaxy watch"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5"
BUNDLE_ID="com.easy-life.galaxy-watch.galaxy-watch"

echo "🚀 Starting Galaxy Watch iOS App Testing..."
echo "============================================="

# Navigate to project directory
cd "$PROJECT_PATH"

echo "📁 Current directory: $(pwd)"
echo "📱 Target: iPhone 16 Pro iOS 18.5 Simulator"
echo ""

# Step 1: Clean the build
echo "🧹 Cleaning previous builds..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME" \
           clean

echo "✅ Clean completed"
echo ""

# Step 2: Build the project
echo "🔨 Building Galaxy Watch app..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME" \
           -destination "$DESTINATION" \
           -configuration Debug \
           build

echo "✅ Build completed successfully"
echo ""

# Step 3: Open iOS Simulator
echo "📱 Opening iOS Simulator..."
open -a Simulator
sleep 3

# Step 4: Install the app
echo "📲 Installing Galaxy Watch app on simulator..."
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
APP_PATH=$(find "$DERIVED_DATA_PATH" -name "galaxy watch.app" -path "*/Debug-iphonesimulator/*" | head -1)

if [ -n "$APP_PATH" ]; then
    echo "📍 Found app at: $APP_PATH"
    xcrun simctl install booted "$APP_PATH"
    echo "✅ App installed successfully"
else
    echo "❌ Could not find built app"
    exit 1
fi

# Step 5: Launch the app
echo "🚀 Launching Galaxy Watch app..."
xcrun simctl launch booted "$BUNDLE_ID"

echo ""
echo "🎉 Galaxy Watch app launched successfully!"
echo "============================================="
echo ""

# Display app information
echo "📊 App Information:"
echo "   • Bundle ID: $BUNDLE_ID"
echo "   • Target: iPhone 16 Pro iOS 18.5 Simulator"
echo "   • App Path: $APP_PATH"
echo ""

# Display testing instructions
echo "🧪 Testing Instructions:"
echo "   1. Grant Health permissions when prompted"
echo "   2. Grant Bluetooth permissions for Galaxy Watch pairing"
echo "   3. Grant notification permissions for iPhone sync"
echo "   4. Test 'Connect to Galaxy Watch' button (requires physical device)"
echo "   5. Test 'Connect to Strava' OAuth flow"
echo "   6. Verify UI displays correctly on iPhone 16 Pro"
echo ""

echo "✨ Testing setup complete! App is ready for interaction."
