import os

base = "/Users/cliff/Library/CloudStorage/Dropbox/agents"
dirs_to_check = [
    os.path.join(base, "skills"),
    os.path.join(base, "skills-tbd")
]

non_conforming = []

for d in dirs_to_check:
    print(f"Scanning {d} for non-conforming skills...")
    if not os.path.exists(d):
        continue
        
    for item in os.listdir(d):
        if item.startswith('.'):
            continue
            
        full_path = os.path.join(d, item)
        if os.path.isdir(full_path):
            # The required file for the Agent Skills format is SKILL.md
            skill_md_path = os.path.join(full_path, "SKILL.md")
            if not os.path.isfile(skill_md_path):
                non_conforming.append(full_path)

if len(non_conforming) == 0:
    print("\nAll skill directories conform to the Agent Skills format (they all have a SKILL.md file)!")
else:
    print(f"\nFound {len(non_conforming)} folders missing the required 'SKILL.md' file:\n")
    for folder in sorted(non_conforming):
        print(f" - {folder}")
