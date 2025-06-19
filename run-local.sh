#!/bin/bash

# Run the MPRAmpController locally with mock hardware
# This allows testing the web interface without the real serial hardware

echo "🎭 Starting MPRAmpController with Mock Zone Controller..."
echo "📍 Server will be available at http://localhost:8001"
echo "🔗 Zone controller at http://localhost:8001"
echo ""
echo "ℹ️  This uses simulated hardware responses - no real amplifier required"
echo ""

# Set environment variable to use mock controller
export USE_MOCK_CONTROLLER=true

# Run the application locally
swift run

echo ""
echo "🛑 Server stopped" 