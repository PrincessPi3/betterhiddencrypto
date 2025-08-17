#!/bin/bash
read -p "Are you sure you want to delete all temporary files? (y/n) " confirm
if [ "$confirm" != "y" ]; then
  echo "Aborting cleanup."
  exit 1
fi

echo "Cleaning all files"
find .. -type f -name "*.tmp" -exec rm -f {} \;
find .. -type f -name "*.bak.*" -exec rm -f {} \;
find .. -type f -name ".volume*" -exec rm -f {} \;
echo "Done!"