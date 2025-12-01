# NixOS Wiki Offline Copy Guide

This guide describes how to create a local, offline copy of the [NixOS Wiki](https://wiki.nixos.org/) and convert the content into Markdown format for easy reading and searching.

## Prerequisites

*   **wget**: For downloading the website.
*   **Nix**: For running `pandoc` without installing it globally (or you can install `pandoc` manually).

## Step 1: Download the Wiki

We use `wget` to mirror the wiki. This process downloads the HTML files, images, and necessary assets.

Run the following command in your terminal:

```bash
# Create a directory for the raw HTML
mkdir -p nixos-wiki

# Download the wiki
# - --mirror: Turn on options suitable for mirroring (recursion, time-stamping, etc.)
# - --convert-links: Make links in downloaded HTML point to local files.
# - --adjust-extension: Save HTML documents with .html extensions.
# - --page-requisites: Get all images, etc. needed to display the HTML page.
# - --no-parent: Do not ascend to the parent directory.
# - --domains=wiki.nixos.org: Only download files from this domain.
wget --mirror \
     --convert-links \
     --adjust-extension \
     --page-requisites \
     --no-parent \
     --domains=wiki.nixos.org \
     https://wiki.nixos.org/wiki/NixOS_Wiki \
     -P nixos-wiki
```

*Note: This process may take several minutes depending on your connection speed and the size of the wiki.*

## Step 2: Convert to Markdown

Once the download is complete, you can convert the HTML files to Markdown using `pandoc`. We will use a script to automate this for all files.

1.  **Create the conversion script** (e.g., `convert.sh`):

```bash
#!/usr/bin/env bash

# Directory containing the downloaded HTML (adjust if different)
SOURCE_DIR="nixos-wiki/wiki.nixos.org"
# Output directory for Markdown files
OUTPUT_DIR="nixos-wiki-md"

mkdir -p "$OUTPUT_DIR"

echo "Starting conversion..."
find "$SOURCE_DIR" -name "*.html" | while read html_file; do
    # Create relative path structure
    rel_path="${html_file#$SOURCE_DIR/}"
    
    # Determine output file path with .md extension
    md_file="$OUTPUT_DIR/${rel_path%.html}.md"
    
    # Create the destination directory
    mkdir -p "$(dirname "$md_file")"
    
    # Convert using pandoc
    # -f html: Input format HTML
    # -t markdown: Output format Markdown
    echo "Converting: $rel_path"
pandoc -f html -t markdown "$html_file" -o "$md_file"
done

echo "Conversion complete. Files are located in $OUTPUT_DIR/"
```

2.  **Make the script executable**:

```bash
chmod +x convert.sh
```

3.  **Run the script**:

If you have `nix` installed with flake support enabled:

```bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#pandoc -c ./convert.sh
```

If you are using standard `nix-shell`:

```bash
nix-shell -p pandoc --run ./convert.sh
```

If you have `pandoc` installed globally:

```bash
./convert.sh
```

## Step 3: Accessing the Data

*   **Raw HTML**: Located in `nixos-wiki/wiki.nixos.org/` (viewable in a browser).
*   **Markdown**: Located in `nixos-wiki-md/` (viewable in any text editor or Markdown viewer).

## Cleanup

After verifying the Markdown files, you can optionally remove the raw HTML downloads and the script:

```bash
rm -rf nixos-wiki convert.sh
```
