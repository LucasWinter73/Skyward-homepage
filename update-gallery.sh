#!/bin/bash

# Gallery Generator for Skyward Simulations
# - Renames all images to Skyward_Simulations_{index} (chronological order)
# - Converts all images to WebP format
# - Generates gallery.json
#
# Requirements: Install cwebp first with: brew install webp
#
# Usage: ./update-gallery.sh

GALLERY_DIR="images/gallery"
OUTPUT_FILE="$GALLERY_DIR/gallery.json"

# Check if gallery directory exists
if [ ! -d "$GALLERY_DIR" ]; then
    echo "Error: $GALLERY_DIR folder not found!"
    echo "Make sure you're running this from your website root folder."
    exit 1
fi

# Check if cwebp is installed
if ! command -v cwebp &> /dev/null; then
    echo "Error: cwebp is not installed!"
    echo "Install it with: brew install webp"
    exit 1
fi

echo "Processing gallery images..."
echo ""

# Create temp directory for processing
TEMP_DIR=$(mktemp -d)

# Step 1: Collect all images with their modification times
echo "Step 1: Scanning for images..."
while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    
    filename=$(basename "$filepath")
    [[ "$filename" == "gallery.json" ]] && continue
    
    # Get modification timestamp for sorting
    mod_time=$(stat -f "%m" "$filepath" 2>/dev/null)
    
    echo "$mod_time|$filepath" >> "$TEMP_DIR/files.txt"
done < <(find "$GALLERY_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \))

# Check if any images found
if [ ! -f "$TEMP_DIR/files.txt" ]; then
    echo "No images found in $GALLERY_DIR"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Step 2: Sort by modification time (oldest first for chronological numbering)
echo "Step 2: Sorting chronologically..."
sort -t'|' -k1 -n "$TEMP_DIR/files.txt" > "$TEMP_DIR/sorted.txt"

# Step 3: Rename and convert to WebP
echo "Step 3: Renaming and converting to WebP..."
index=1
while IFS='|' read -r mod_time filepath; do
    [ -z "$filepath" ] && continue
    
    filename=$(basename "$filepath")
    new_name="Skyward_Simulations_$(printf "%03d" $index).webp"
    
    echo "  $filename -> $new_name"
    
    # Convert to WebP (or copy if already webp)
    if [[ "$filename" == *.webp ]]; then
        cp "$filepath" "$TEMP_DIR/$new_name"
    else
        cwebp -q 85 "$filepath" -o "$TEMP_DIR/$new_name" 2>/dev/null
    fi
    
    ((index++))
done < "$TEMP_DIR/sorted.txt"

# Step 4: Remove old images from gallery folder
echo "Step 4: Cleaning up old files..."
find "$GALLERY_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -delete

# Step 5: Move new WebP files to gallery folder
echo "Step 5: Moving new files..."
mv "$TEMP_DIR"/Skyward_Simulations_*.webp "$GALLERY_DIR/"

# Step 6: Generate JSON (newest first for display)
echo "Step 6: Generating gallery.json..."
echo "[" > "$OUTPUT_FILE"

first=true
for filepath in $(ls -r "$GALLERY_DIR"/Skyward_Simulations_*.webp 2>/dev/null); do
    filename=$(basename "$filepath")
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi
    
    printf '\t{"file": "%s"}' "$filename" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "]" >> "$OUTPUT_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Done! Processed $((index-1)) images."
echo "Generated $OUTPUT_FILE"
echo ""
echo "Now commit and push to GitHub to update your site."
