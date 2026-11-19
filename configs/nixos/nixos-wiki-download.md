# NixOS Wiki Offline Copy Guide

This guide describes how to create a local, offline copy of the [NixOS Wiki](https://wiki.nixos.org/) and convert the content into clean Markdown files using Python and Pandoc.

## Prerequisites

*   **wget**: For downloading the website.
*   **uv**: For running the Python conversion script with dependencies.
*   **pandoc**: For converting HTML content to Markdown (used by the script).
*   **Nix** (Optional): Can be used to run `pandoc` if not installed globally.

## Step 1: Download the Wiki

We use `wget` to mirror the wiki. This process downloads the HTML files, images, and necessary assets.

```bash
# Create a directory for the raw HTML
mkdir -p nixos-wiki

# Download the wiki
wget --mirror \
     --convert-links \
     --adjust-extension \
     --page-requisites \
     --no-parent \
     --domains=wiki.nixos.org \
     https://wiki.nixos.org/wiki/NixOS_Wiki \
     -P nixos-wiki
```

*Note: This process may take several minutes.*

## Step 2: Convert to Markdown

We use a Python script `nixos-wiki-convert.py` to extract the relevant content from the HTML files and convert it to Markdown. This script uses `beautifulsoup4` to clean the HTML and `pandoc` for high-quality conversion.

1.  **Create the conversion script** (`nixos-wiki-convert.py`):

    (See the `nixos-wiki-convert.py` file in this directory)

2.  **Run the script**:

    Ensure `nixos-wiki-convert.py` is executable:
    ```bash
    chmod +x nixos-wiki-convert.py
    ```

    **Option A: Using Nix (Recommended)**
    This command runs the script in a shell where `pandoc` is available, and `uv` handles the Python dependencies defined in the script header.
    ```bash
    nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#pandoc nixpkgs#uv -c ./nixos-wiki-convert.py
    ```

    **Option B: Using Global Tools**
    If you have `pandoc` and `uv` installed on your system:
    ```bash
    ./nixos-wiki-convert.py
    ```

## Output

*   **Markdown Files**: The converted files are located in the `nixos-wiki-md/` directory.
    *   They include YAML frontmatter with the `title` and original `url`.
    *   Wiki navigation, sidebars, and edit links are removed.
*   **Raw HTML**: The downloaded source is in `nixos-wiki/`.

## Cleanup

To remove the raw downloaded HTML:

```bash
rm -rf nixos-wiki
```