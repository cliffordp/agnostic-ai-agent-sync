import os
import shutil

base = "/Users/cliff/Library/CloudStorage/Dropbox/agents"
skills_dir = os.path.join(base, "skills")
tbd_dir = os.path.join(base, "skills-tbd")

# The comprehensive whitelist keywords based on user preferences
whitelist_keywords = [
    # WordPress
    "wordpress", "wp-",
    # SEO
    "seo", "search-engine",
    # Postman
    "postman",
    # Financial
    "finance", "finops", "billing", "crypto", "defi", "fintech", "paypal", "stripe", "pricing", "leiloeiro",
    # PHP
    "php", "laravel",
    # API
    "api", "graphql", "rest", "fastapi", "openapi",
    # Generate Skills
    "generator", "creator", "skill-smith", "agent-tool-builder",
    # File Generation
    "file-uploads", "pdf", "docx", "pptx", "latex", "readme",
    # Writing
    "writing", "copywriting", "content", "blog", "proofreader", "editorial", "internal-comms", "technical-writing",
    # Diagrams/Charting
    "diagram", "chart", "mermaid", "c4-",
    # Marketing
    "marketing", "hubspot", "mailchimp", "growth", "cro-", "sales",
    # Ads
    "ads",
    # File Management
    "file-organizer", "filesystem", "dropbox", "google-drive", "onedrive",
    # Office/Documents/Email
    "google-docs", "google-sheets", "google-slides", "office", "gmail", "outlook", "email",
    # Design
    "design", "ui", "ux", "figma", "canvas",
    # Git/GitHub
    "git", "gh-", "bitbucket",
    # Code Planning
    "planning", "architecture", "ddd-", "project-development", "prd", "agile", "conductor"
]

def matches_whitelist(name):
    lower_name = name.lower()
    for kw in whitelist_keywords:
        if kw in lower_name:
            return True
    return False

moved_to_tbd = 0
moved_to_skills = 0

print("Scanning 'skills' to move non-matching items to 'skills-tbd'...")
if os.path.exists(skills_dir):
    for item in os.listdir(skills_dir):
        if item.startswith('.'):
            continue
        
        full_path = os.path.join(skills_dir, item)
        
        # If it DOES NOT match the whitelist, move it to TBD
        if not matches_whitelist(item):
            print(f"[-] Moving to TBD: {item}")
            try:
                shutil.move(full_path, tbd_dir)
                moved_to_tbd += 1
            except Exception as e:
                print(f"    Failed to move {item}: {e}")

print("\nScanning 'skills-tbd' to rescue matching items back to 'skills'...")
if os.path.exists(tbd_dir):
    for item in os.listdir(tbd_dir):
        if item.startswith('.'):
            continue
        
        full_path = os.path.join(tbd_dir, item)
        
        # If it DOES match the whitelist, move it back to SKILLS
        if matches_whitelist(item):
            print(f"[+] Restoring to SKILLS: {item}")
            try:
                shutil.move(full_path, skills_dir)
                moved_to_skills += 1
            except Exception as e:
                print(f"    Failed to move {item}: {e}")

print(f"\nDone!")
print(f"Moved {moved_to_tbd} non-matching items to 'skills-tbd'.")
print(f"Restored {moved_to_skills} matching items back to 'skills'.")
