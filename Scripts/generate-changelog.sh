#!/bin/bash
echo "# Changelog"; echo ""; git log --pretty=format:"- %s (%h)" --no-merges "${1:-HEAD}" | head -50
