#!/bin/zsh
# Builds and signs the Twist On / Twist Off shortcuts into App/Resources.
set -e
cd "${0:A:h}"
mkdir -p build
python3 -I make.py
for n in "Twist On" "Twist Off"; do
  shortcuts sign --mode anyone --input "build/$n.unsigned.shortcut" --output "../App/Resources/$n.shortcut"
done
