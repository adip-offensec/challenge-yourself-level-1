#!/usr/bin/env python3
"""
Flag validation API for Attack Path Lab
Serves web frontend and validates submitted flags
"""

from flask import Flask, request, jsonify, send_from_directory, render_template
import json
import os
import hashlib

app = Flask(__name__, static_folder='../', template_folder='../')

# Load flag hashes
def load_flags():
    """Load flag hashes from JSON file"""
    # Try multiple possible paths (development vs deployment)
    possible_paths = [
        os.path.join(os.path.dirname(__file__), '../flags/hashes.json'),  # deployment
        os.path.join(os.path.dirname(__file__), '../../flags/hashes.json'),  # source
        '/vagrant/flags/hashes.json',  # Vagrant shared folder
        '/var/www/attack-lab/flags/hashes.json'  # absolute path
    ]
    
    for FLAGS_FILE in possible_paths:
        try:
            with open(FLAGS_FILE, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            continue
    
    # Default flags for development (fallback)
    return {
        "stage1": "d033e22ae348aeb5660fc2140aec35850c4da997",  # admin:admin
        "stage2": "7110eda4d09e062aa5e4a390b0a572ac0d2c0220",  # 1234
        "stage3": "356a192b7913b04c54574d18c28d46e6395428ab",  # 1
        "stage4": "da4b9237bacccdf19c0760cab7aec4a8359010b0",  # 2
        "stage5": "77de68daecd823babbb58edb1c8e14d7106e83bb",  # 3
        "stage6": "1b6453892473a467d07372d45eb05abc2031647a",  # 4
        "stage7": "ac3478d69a3c81fa62e60f5c3696165a4e5e6ac4"   # 5
    }

FLAGS = load_flags()

# Challenge descriptions
CHALLENGES = [
    {
        "id": "stage1",
        "title": "Initial Access - SQL Injection",
        "description": "Exploit SQL injection on WEB02 to gain command execution.",
        "machine": "WEB02 (10.0.1.20)",
        "difficulty": "Easy",
        "hints": [
            "The login form is vulnerable to SQL injection",
            "Try ' OR 1=1-- as username",
            "Use xp_cmdshell to execute commands"
        ]
    },
    {
        "id": "stage2",
        "title": "Privilege Escalation - WEB02",
        "description": "Escalate privileges on WEB02 using unquoted service path vulnerability.",
        "machine": "WEB02",
        "difficulty": "Medium",
        "hints": [
            "Look for services with unquoted paths",
            "Check write permissions on service binary directories",
            "Restart the service to execute your payload"
        ]
    },
    {
        "id": "stage3",
        "title": "Lateral Movement - FILES02",
        "description": "Use credentials found on WEB02 to access FILES02.",
        "machine": "FILES02 (10.0.2.30)",
        "difficulty": "Easy",
        "hints": [
            "Search for credential files on WEB02",
            "Try RDP or WinRM with found credentials",
            "Check for file shares"
        ]
    },
    {
        "id": "stage4",
        "title": "Privilege Escalation - DEV04",
        "description": "Escalate privileges on DEV04 using token impersonation.",
        "machine": "DEV04 (10.0.2.50)",
        "difficulty": "Hard",
        "hints": [
            "Check user privileges with whoami /priv",
            "Look for SeImpersonatePrivilege",
            "Use a potato attack (JuicyPotato, RoguePotato)"
        ]
    },
    {
        "id": "stage5",
        "title": "Domain Enumeration - Kerberoasting",
        "description": "Perform Kerberoasting attack to obtain service account credentials.",
        "machine": "DC01 (10.0.2.10)",
        "difficulty": "Medium",
        "hints": [
            "Enumerate SPNs with PowerView or Impacket",
            "Request TGS tickets for service accounts",
            "Crack the hash offline"
        ]
    },
    {
        "id": "stage6",
        "title": "Domain Compromise - DCSync",
        "description": "Use compromised service account to perform DCSync and dump domain hashes.",
        "machine": "DC01",
        "difficulty": "Hard",
        "hints": [
            "Check DCSync permissions for the compromised account",
            "Use secretsdump.py or mimikatz",
            "Extract Administrator NTLM hash"
        ]
    },
    {
        "id": "stage7",
        "title": "Final Objective - PROD01",
        "description": "Access PROD01 as Domain Administrator and capture the final flag.",
        "machine": "PROD01 (10.0.2.60)",
        "difficulty": "Medium",
        "hints": [
            "Use the Administrator hash for pass-the-hash",
            "Access PROD01 via WinRM or RDP",
            "Find flag on Administrator desktop"
        ]
    }
]

@app.route('/')
def index():
    """Serve main page"""
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/challenges')
def challenges():
    """Return challenges list"""
    return jsonify(CHALLENGES)

@app.route('/challenges/<challenge_id>')
def challenge_detail(challenge_id):
    """Return specific challenge details"""
    for challenge in CHALLENGES:
        if challenge['id'] == challenge_id:
            return jsonify(challenge)
    return jsonify({"error": "Challenge not found"}), 404

@app.route('/api/validate', methods=['POST'])
def validate():
    """Validate submitted flag"""
    data = request.get_json()
    if not data or 'challenge' not in data or 'flag' not in data:
        return jsonify({"error": "Invalid request"}), 400
    
    challenge_id = data['challenge']
    submitted_flag = data['flag'].strip()
    
    if challenge_id not in FLAGS:
        return jsonify({"error": "Invalid challenge"}), 404
    
    # Hash the submitted flag (SHA1 for simplicity)
    flag_hash = hashlib.sha1(submitted_flag.encode()).hexdigest()
    
    if flag_hash == FLAGS[challenge_id]:
        return jsonify({
            "success": True,
            "message": "Flag validated successfully!"
        })
    else:
        return jsonify({
            "success": False,
            "message": "Invalid flag"
        }), 400

@app.route('/api/hints/<challenge_id>')
def get_hints(challenge_id):
    """Get hints for a challenge (progressive disclosure)"""
    for challenge in CHALLENGES:
        if challenge['id'] == challenge_id:
            hint_level = request.args.get('level', 0, type=int)
            if hint_level < 0 or hint_level >= len(challenge['hints']):
                return jsonify({"error": "Invalid hint level"}), 400
            return jsonify({
                "hint": challenge['hints'][hint_level],
                "level": hint_level,
                "total": len(challenge['hints'])
            })
    return jsonify({"error": "Challenge not found"}), 404

@app.route('/api/status')
def status():
    """Check API status"""
    return jsonify({
        "status": "running",
        "version": "1.0",
        "challenges_count": len(CHALLENGES)
    })

@app.route('/<path:path>')
def static_files(path):
    """Serve static files"""
    return send_from_directory(app.static_folder, path)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)