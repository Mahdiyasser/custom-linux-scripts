#!/bin/bash

OLD="/media/mahdi/D-drive/Mahdi"
NEW="/media/mahdi/Storage"

# Change this to the directory you want to scan
TARGET_DIR="."

find "$TARGET_DIR" -type f \
    ! -path "*/.git/*" \
    -exec grep -Il "$OLD" {} \; | while read -r file; do
        echo "Updating: $file"
        sed -i "s|$OLD|$NEW|g" "$file"
done

echo "Done."
