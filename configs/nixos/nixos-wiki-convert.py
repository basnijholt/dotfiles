#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "beautifulsoup4",
#   "PyYAML",
# ]
# ///
import os
import sys
import yaml
import subprocess
import threading
from pathlib import Path
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor, as_completed

# Global counters for progress
progress_lock = threading.Lock()
completed_count = 0
total_count = 0


def convert_file(html_file, source_dir, output_dir):
    try:
        # Calculate relative path for output
        rel_path = html_file.relative_to(source_dir)
        md_file = output_dir / rel_path.with_suffix(".md")

        # Create parent directories
        md_file.parent.mkdir(parents=True, exist_ok=True)

        # Read and parse HTML
        with open(html_file, "r", encoding="utf-8") as f:
            soup = BeautifulSoup(f, "html.parser")

        # Extract Title
        title_tag = soup.select_one("#firstHeading")
        title = title_tag.get_text(strip=True) if title_tag else rel_path.stem

        # Extract Main Content
        content_div = soup.select_one(".mw-parser-output")

        if not content_div:
            return f"Skipping {rel_path}: No content found"

        # Optional: Remove "edit" links (mw-editsection) to clean up output
        for edit_section in content_div.select(".mw-editsection"):
            edit_section.decompose()

        # Get the cleaner HTML string
        html_content = str(content_div)

        # Convert using Pandoc via subprocess
        # We pipe the specific HTML content to pandoc
        process = subprocess.Popen(
            ["pandoc", "-f", "html", "-t", "gfm-raw_html", "--wrap=none"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        md_content, stderr = process.communicate(input=html_content)

        if process.returncode != 0:
            return f"Error converting {rel_path}: {stderr}"

        # Prepare Frontmatter
        frontmatter = {
            "title": title,
            "url": f"https://wiki.nixos.org/wiki/{rel_path.stem}",
        }

        # Write final file with Frontmatter
        with open(md_file, "w", encoding="utf-8") as f:
            f.write("---\n")
            yaml.dump(frontmatter, f, default_flow_style=False)
            f.write("---\n\n")
            f.write(md_content)

        return None  # Success

    except Exception as e:
        return f"Failed to convert {html_file}: {e}"


def main():
    global total_count, completed_count

    source_dir = Path("nixos-wiki/wiki.nixos.org")
    output_dir = Path("nixos-wiki-md")

    if not source_dir.exists():
        print(f"Error: Source directory {source_dir} does not exist.")
        sys.exit(1)

    print(f"Converting files from {source_dir} to {output_dir}...")

    # Walk through all HTML files
    files = list(source_dir.rglob("*.html"))
    total_count = len(files)

    # Adjust max_workers based on CPU core count or IO preference
    # Since pandoc is a subprocess, we don't want to spawn too many if CPU bound,
    # but here IO and process overhead are factors. 2x cores is a reasonable default.
    max_workers = os.cpu_count() * 2 if os.cpu_count() else 4

    print(f"Starting conversion of {total_count} files using {max_workers} workers...")

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_file = {
            executor.submit(convert_file, f, source_dir, output_dir): f for f in files
        }

        forfuture = as_completed(future_to_file)
        for future in forfuture:
            result = future.result()

            with progress_lock:
                completed_count += 1
                # Print progress overwrite
                sys.stdout.write(f"\r[{completed_count}/{total_count}] Processed")
                sys.stdout.flush()

            if result:
                # If there was a message (error or skip), print it on a new line
                sys.stdout.write(f"\n{result}\n")

    print(f"\nDone. Converted {completed_count} files.")


if __name__ == "__main__":
    main()
