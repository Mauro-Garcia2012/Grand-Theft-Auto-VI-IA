#!/bin/bash
# Re-import assets and refresh the global class cache
cd "$(dirname "$0")/.."
timeout 900 godot --headless --editor --quit --path . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: Failed|at: GDScript" | grep -v "tools/" | head -40
