import os

base = "/Users/cliff/Library/CloudStorage/Dropbox/agents"
skills_dir = os.path.join(base, "skills")
tbd_dir = os.path.join(base, "skills-tbd")

def list_skills(directory, output_file):
    skills = []
    if os.path.exists(directory):
        for item in os.listdir(directory):
            if not item.startswith('.'):
                skills.append(item)
    
    with open(output_file, 'w') as f:
        for skill in sorted(skills):
            f.write(f"{skill}\n")
    print(f"Wrote {len(skills)} items from {directory} to {output_file}")

list_skills(skills_dir, "skills_list.txt")
list_skills(tbd_dir, "tbd_list.txt")
