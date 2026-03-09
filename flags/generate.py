#!/usr/bin/env python3
import hashlib
import json
import random
import string

def random_flag():
    """Generate a random flag string"""
    prefix = random.choice(['FLAG', 'FLG', 'CTF'])
    chars = string.ascii_uppercase + string.digits
    suffix = ''.join(random.choices(chars, k=16))
    return f"{prefix}_{{{suffix}}}"

# Generate flags for each stage
stages = ['stage1', 'stage2', 'stage3', 'stage4', 'stage5', 'stage6', 'stage7']
flags = {}
hashes = {}

print("Generating flags...")
for stage in stages:
    flag = random_flag()
    flags[stage] = flag
    hashes[stage] = hashlib.sha1(flag.encode()).hexdigest()
    print(f"{stage}: {flag}")

# Save flags to files
for stage, flag in flags.items():
    with open(f"{stage}.txt", "w") as f:
        f.write(flag + "\n")

# Save hashes for API
with open("hashes.json", "w") as f:
    json.dump(hashes, f, indent=2)

print("\nFlags saved to individual files.")
print("Hashes saved to hashes.json")