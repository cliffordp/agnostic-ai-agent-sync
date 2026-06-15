import os

dirs_to_clean = [
    "/Users/cliff/Library/CloudStorage/Dropbox/agents/skills",
    "/Users/cliff/Library/CloudStorage/Dropbox/agents/skills-tbd"
]

deleted_count = 0

for d in dirs_to_clean:
    print(f"Scanning {d} for symlinks to delete...")
    # os.walk will not follow symlinks to directories by default, which is safe here.
    for root, dirs, files in os.walk(d):
        # We need to check both files and directories, as symlinks can appear as either.
        for name in dirs + files:
            full_path = os.path.join(root, name)
            if os.path.islink(full_path):
                try:
                    os.unlink(full_path)
                    print(f"Deleted symlink: {full_path}")
                    deleted_count += 1
                except Exception as e:
                    print(f"Failed to delete {full_path}: {e}")

print(f"\nDone! Deleted {deleted_count} symlinks.")
