#!/bin/bash
VF="Sources/NotepadNextCore/Version.swift"
case "$1" in
  get) grep 'appVersion' "$VF" | sed 's/.*"\(.*\)".*/\1/' ;;
  bump) C=$(grep 'appVersion' "$VF" | sed 's/.*"\(.*\)".*/\1/'); IFS='.' read -r a b c <<< "$C"
    case "$2" in major) a=$((a+1));b=0;c=0;; minor) b=$((b+1));c=0;; *) c=$((c+1));; esac
    sed -i '' "s/appVersion = \".*\"/appVersion = \"$a.$b.$c\"/" "$VF"; echo "$a.$b.$c" ;;
  *) echo "Usage: $0 get|bump [major|minor|patch]" ;;
esac
