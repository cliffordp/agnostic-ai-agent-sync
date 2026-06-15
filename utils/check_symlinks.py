import os
import glob

tbd_dir = "/Users/cliff/Library/CloudStorage/Dropbox/agents/skills-tbd"
print(f"Scanning {tbd_dir} for symlinks...\n")

symlinks_found = 0
for root, dirs, files in os.walk(tbd_dir):
    # Check directories
    for d in dirs:
        full_path = os.path.join(root, d)
        if os.path.islink(full_path):
            target = os.readlink(full_path)
            print(f"[DIR SYMLINK] {full_path}")
            print(f"  └── Points to: {target}")
            symlinks_found += 1
            
    # Check files
    for f in files:
        full_path = os.path.join(root, f)
        if os.path.islink(full_path):
            target = os.readlink(full_path)
            print(f"[FILE SYMLINK] {full_path}")
            print(f"  └── Points to: {target}")
            symlinks_found += 1

if symlinks_found == 0:
    print("No symlinks found.")
else:
    print(f"\nTotal symlinks found: {symlinks_found}")
