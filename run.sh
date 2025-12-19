#!/bin/bash
echo "🚀 Building FlowOS 1.0..."
make clean
make all
echo "✅ Starting FlowOS in QEMU..."
make run