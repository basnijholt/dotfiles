# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "requests",
# ]
# ///
import re
import subprocess
import sys
from pathlib import Path
import requests

def get_latest_llama_cpp_version():
    url = "https://api.github.com/repos/ggml-org/llama.cpp/releases"
    try:
        response = requests.get(url)
        response.raise_for_status()
        releases = response.json()
    except Exception as e:
        print(f"Failed to fetch releases: {e}")
        sys.exit(1)
    
    max_ver = 0
    for release in releases:
        name = release["tag_name"]
        if name.startswith("b"):
            try:
                ver = int(name[1:])
                if ver > max_ver:
                    max_ver = ver
            except ValueError:
                continue
    return str(max_ver)

def update_file(file_path):
    path = Path(file_path)
    content = path.read_text()
    
    # Regex to find version and hash inside llama-cpp block
    # pattern:  llama-cpp = ... version = "7097"; ... hash = "sha256-...";
    
    # First, find current version
    version_pattern = re.compile(r'(llama-cpp\s*=\s*.*?version\s*=\s*")(\d+)(";)', re.DOTALL)
    match = version_pattern.search(content)
    if not match:
        print("Could not find llama-cpp version definition.")
        return False
        
    current_ver = match.group(2)
    print(f"Current llama-cpp version: {current_ver}")
    
    latest_ver = get_latest_llama_cpp_version()
    print(f"Latest llama-cpp version:  {latest_ver}")
    
    if int(latest_ver) <= int(current_ver):
        print("Already up to date.")
        return False
        
    print(f"Updating version to {latest_ver}...")
    new_content = version_pattern.sub(fr'\g<1>{latest_ver}\g<3>', content)
    
    # Reset hash to dummy to force failure and capture real hash
    # Find the position of the version match
    ver_end = match.end()
    
    # Search for hash after that
    hash_pattern = re.compile(r'(hash\s*=\s*")(sha256-.*?|)";')
    hash_match = hash_pattern.search(new_content, pos=ver_end)
    
    if not hash_match:
        print("Could not find hash field.")
        return False
        
    # Replace hash with dummy
    dummy_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    
    # Reconstruct string
    final_content = (
        new_content[:hash_match.start(2)] + 
        dummy_hash + 
        new_content[hash_match.end(2):]
    )
    
    path.write_text(final_content)
    
    print("Attempting to build to capture new hash...")
    # Run nix build to get the error
    # We use .#nixosConfigurations.pc.pkgs.llama-cpp because the override is in 'pc' config
    cmd = [
        "nix", "build", 
        ".#nixosConfigurations.pc.pkgs.llama-cpp", 
        "--no-link",
        "--cores", "1"
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    # It SHOULD fail.
    stderr = result.stderr
    
    # Look for "got: sha256-..."
    got_pattern = re.compile(r'\s+got:\s+(sha256-\S+)')
    got_match = got_pattern.search(stderr)
    
    if not got_match:
        print("Build failed but could not extract new hash from stderr.")
        print("Stderr output:")
        print(stderr)
        return False
        
    new_hash = got_match.group(1)
    print(f"Found new hash: {new_hash}")
    
    # Update file with real hash
    final_content = final_content.replace(dummy_hash, new_hash)
    path.write_text(final_content)
    print("Successfully updated package-overrides.nix")
    return True

if __name__ == "__main__":
    target_file = Path("hosts/pc/package-overrides.nix")
    if not target_file.exists():
        print(f"Error: {target_file} not found.")
        sys.exit(1)
        
    update_file(target_file)
