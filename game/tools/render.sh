#!/bin/bash
# Runs godot with a virtual X display and software Vulkan (lavapipe)
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
exec xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver vulkan "$@"
