#!/bin/bash
# Build script for xInsight

set -e

echo "🔨 Building xInsight..."
echo ""

# Build
swift build

echo ""
echo "✅ Build successful!"
echo ""
echo "Run with: .build/debug/xInsight"
