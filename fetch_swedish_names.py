#!/usr/bin/env python3
"""
Fetch Swedish names from SCB and Skatteverket for generating fake user names.
"""

import requests
import json

def fetch_male_names():
    """Fetch top 100 male names from SCB."""
    url = 'https://api.scb.se/OV0104/v1/doris/sv/ssd/START/BE/BE0001/BE0001G/BE0001F100'
    payload = {"query": [], "response": {"format": "json"}}

    print("Fetching male names from SCB...")
    response = requests.post(url, json=payload)
    data = response.json()

    names = []
    for item in data['data']:
        name = item['key'][0]
        try:
            count = int(item['values'][0])
            names.append((name, count))
        except (ValueError, TypeError):
            # Skip names with '..' or other non-numeric values
            continue

    # Sort and take the top 100
    names = sorted(names, key=lambda x: x[1], reverse=True)[:100]
    return [name for name, _ in names]

def fetch_female_names():
    """Fetch top 100 female names from SCB."""
    # Note: Same URL as male names, SCB returns combined data
    url = 'https://api.scb.se/OV0104/v1/doris/sv/ssd/START/BE/BE0001/BE0001G/BE0001F100'
    payload = {"query": [], "response": {"format": "json"}}

    print("Fetching female names from SCB...")
    response = requests.post(url, json=payload)
    data = response.json()

    names = []
    for item in data['data']:
        name = item['key'][0]
        try:
            count = int(item['values'][0])
            names.append((name, count))
        except (ValueError, TypeError):
            # Skip names with '..' or other non-numeric values
            continue

    # Sort and take the top 100
    names = sorted(names, key=lambda x: x[1], reverse=True)[:100]
    return [name for name, _ in names]

def fetch_surnames():
    """Fetch surnames from Skatteverket."""
    url = 'https://skatteverket.se/download/18.25688d121956e35b0c218b2/1743510574534/Fria_efternamn_namn_antal_textfil_2025.txt'

    print("Fetching surnames from Skatteverket...")
    response = requests.get(url)

    # Parse the text file
    lines = response.text.strip().split('\n')
    surnames = []

    for line in lines:
        # Skip header and empty lines
        if not line or line.startswith('Namn') or line.startswith('---'):
            continue

        # Format: "Name    Count" (column headers are in Swedish)
        parts = line.split()
        if len(parts) >= 2:
            name = parts[0]
            surnames.append(name)

    # Take the top 200 surnames
    return surnames[:200]

if __name__ == '__main__':
    # Fetch names
    male_names = fetch_male_names()
    female_names = fetch_female_names()
    surnames = fetch_surnames()

    print(f"\n✓ Fetched {len(male_names)} male names")
    print(f"  Examples: {', '.join(male_names[:10])}")

    print(f"\n✓ Fetched {len(female_names)} female names")
    print(f"  Examples: {', '.join(female_names[:10])}")

    print(f"\n✓ Fetched {len(surnames)} surnames")
    print(f"  Examples: {', '.join(surnames[:10])}")

    # Save to JSON file
    data = {
        'male_names': male_names,
        'female_names': female_names,
        'surnames': surnames
    }

    with open('swedish_names.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✓ Saved to swedish_names.json")
