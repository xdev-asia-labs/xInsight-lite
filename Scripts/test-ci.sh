#!/bin/bash
# test-ci.sh - Test build like CI/CD environment locally
# Run this before pushing to avoid CI failures

set -e

echo "🧪 Testing CI/CD build locally..."
echo "================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Step 1: Clean
echo "🧹 Cleaning build..."
swift package clean

# Step 2: Build for ARM64 (Release)
echo ""
echo "🔨 Building for ARM64 (Release)..."
if swift build -c release --arch arm64 2>&1 | tee /tmp/build_arm64.log | grep -E "error:|warning:"; then
    if grep -q "error:" /tmp/build_arm64.log; then
        echo -e "${RED}❌ ARM64 build failed!${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ ARM64 build passed${NC}"

# Step 3: Build for x86_64 (Release)
echo ""
echo "🔨 Building for x86_64 (Release)..."
if swift build -c release --arch x86_64 2>&1 | tee /tmp/build_x86.log | grep -E "error:|warning:"; then
    if grep -q "error:" /tmp/build_x86.log; then
        echo -e "${RED}❌ x86_64 build failed!${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ x86_64 build passed${NC}"

# Step 4: Run tests
echo ""
echo "🧪 Running tests..."
if swift test 2>&1 | tee /tmp/test.log | grep -E "error:|passed|failed"; then
    if grep -q "failed" /tmp/test.log; then
        echo -e "${RED}❌ Tests failed!${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ All tests passed${NC}"

echo ""
echo "================================="
echo -e "${GREEN}✅ CI/CD simulation passed! Safe to push.${NC}"
