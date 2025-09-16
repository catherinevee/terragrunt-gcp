#!/usr/bin/env python3
"""
Security Badge Generator
Generates dynamic security badges based on security scan results.
"""

import json
from pathlib import Path

def load_security_results():
    """Load security results from JSON file."""
    try:
        with open("docs/badges/security-results.json", 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def create_security_badge(score, grade, issues_count):
    """Create security badge SVG."""
    if score >= 95:
        color = "brightgreen"
        status = "excellent"
    elif score >= 90:
        color = "green"
        status = "good"
    elif score >= 80:
        color = "yellow"
        status = "fair"
    elif score >= 70:
        color = "orange"
        status = "poor"
    else:
        color = "red"
        status = "critical"
    
    message = f"{score}/100 ({grade})"
    text_width = len(message) * 6 + 20
    
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{text_width + 80}" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <mask id="a">
    <rect width="100%" height="100%" rx="3" fill="#fff"/>
  </mask>
  <g mask="url(#a)">
    <path fill="#555" d="M0 0h60v20H0z"/>
    <path fill="{color}" d="M60 0h{text_width}v20H60z"/>
  </g>
  <rect width="100%" height="100%" rx="3" fill="none" stroke="rgba(0,0,0,.1)"/>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="30" y="14" fill="#010101" fill-opacity=".3">security</text>
    <text x="30" y="13" fill="#fff">security</text>
    <text x="{60 + text_width//2}" y="14" fill="#010101" fill-opacity=".3">{message}</text>
    <text x="{60 + text_width//2}" y="13" fill="#fff">{message}</text>
  </g>
</svg>'''
    
    return svg, status, color, message

def create_issues_badge(issues_count):
    """Create issues count badge SVG."""
    if issues_count == 0:
        color = "brightgreen"
        status = "clean"
        message = "0 issues"
    elif issues_count <= 2:
        color = "yellow"
        status = "minor"
        message = f"{issues_count} issues"
    elif issues_count <= 5:
        color = "orange"
        status = "moderate"
        message = f"{issues_count} issues"
    else:
        color = "red"
        status = "major"
        message = f"{issues_count} issues"
    
    text_width = len(message) * 6 + 20
    
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{text_width + 80}" height="20">
  <linearGradient id="b" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <mask id="a">
    <rect width="100%" height="100%" rx="3" fill="#fff"/>
  </mask>
  <g mask="url(#a)">
    <path fill="#555" d="M0 0h60v20H0z"/>
    <path fill="{color}" d="M60 0h{text_width}v20H60z"/>
  </g>
  <rect width="100%" height="100%" rx="3" fill="none" stroke="rgba(0,0,0,.1)"/>
  <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
    <text x="30" y="14" fill="#010101" fill-opacity=".3">issues</text>
    <text x="30" y="13" fill="#fff">issues</text>
    <text x="{60 + text_width//2}" y="14" fill="#010101" fill-opacity=".3">{message}</text>
    <text x="{60 + text_width//2}" y="13" fill="#fff">{message}</text>
  </g>
</svg>'''
    
    return svg, status, color, message

def main():
    """Main function to generate security badges."""
    print("🏷️ Generating security badges...")
    
    # Load security results
    results = load_security_results()
    
    if not results:
        print("❌ No security results found")
        return
    
    # Extract data
    score = results.get("security_score", 0)
    grade = results.get("security_grade", "F")
    issues_count = results.get("summary", {}).get("total_issues", 0)
    
    # Create security score badge
    security_svg, security_status, security_color, security_message = create_security_badge(score, grade, issues_count)
    
    # Create issues count badge
    issues_svg, issues_status, issues_color, issues_message = create_issues_badge(issues_count)
    
    # Save badges
    badges_dir = Path("docs/badges")
    badges_dir.mkdir(parents=True, exist_ok=True)
    
    # Security score badge
    with open(badges_dir / "security-score.svg", 'w') as f:
        f.write(security_svg)
    
    # Issues count badge
    with open(badges_dir / "security-issues.svg", 'w') as f:
        f.write(issues_svg)
    
    print(f"✅ Security badges generated:")
    print(f"   📊 Security Score: {score}/100 ({grade}) - {security_status}")
    print(f"   🐛 Issues Count: {issues_count} - {issues_status}")
    print(f"   📁 Saved to: {badges_dir}")
    
    return {
        "security_score": score,
        "security_grade": grade,
        "issues_count": issues_count,
        "security_status": security_status,
        "issues_status": issues_status
    }

if __name__ == "__main__":
    main()
