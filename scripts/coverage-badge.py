#!/usr/bin/env python3
"""
Coverage Badge Generator
Generates dynamic coverage badges using CodeCov API or local coverage data.
"""

import json
import subprocess
import sys
import os
import requests
from pathlib import Path

def get_local_coverage():
    """Get coverage data from local test run."""
    try:
        # Run tests and generate coverage
        result = subprocess.run([
            'go', 'test', './...', '-coverprofile=coverage.out'
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            return None
            
        # Parse coverage output
        coverage_result = subprocess.run([
            'go', 'tool', 'cover', '-func=coverage.out'
        ], capture_output=True, text=True)
        
        if coverage_result.returncode != 0:
            return None
            
        # Extract total coverage percentage
        lines = coverage_result.stdout.strip().split('\n')
        total_line = [line for line in lines if 'total:' in line]
        
        if total_line:
            # Extract percentage from line like "total: (statements) 75.2%"
            parts = total_line[0].split()
            for part in parts:
                if '%' in part:
                    return float(part.replace('%', ''))
        
        return None
    except Exception as e:
        print(f"Error getting local coverage: {e}")
        return None

def generate_coverage_badge(coverage_percent):
    """Generate coverage badge SVG."""
    if coverage_percent is None:
        status = "unknown"
        color = "lightgrey"
        message = "No data"
    elif coverage_percent >= 90:
        status = "excellent"
        color = "brightgreen"
        message = f"{coverage_percent:.1f}%"
    elif coverage_percent >= 80:
        status = "good"
        color = "green"
        message = f"{coverage_percent:.1f}%"
    elif coverage_percent >= 70:
        status = "fair"
        color = "yellow"
        message = f"{coverage_percent:.1f}%"
    elif coverage_percent >= 60:
        status = "poor"
        color = "orange"
        message = f"{coverage_percent:.1f}%"
    else:
        status = "critical"
        color = "red"
        message = f"{coverage_percent:.1f}%"
    
    # Calculate text width
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
    <text x="30" y="14" fill="#010101" fill-opacity=".3">coverage</text>
    <text x="30" y="13" fill="#fff">coverage</text>
    <text x="{60 + text_width//2}" y="14" fill="#010101" fill-opacity=".3">{message}</text>
    <text x="{60 + text_width//2}" y="13" fill="#fff">{message}</text>
  </g>
</svg>'''
    
    return svg, status, color, message

def main():
    """Main function to generate coverage badge."""
    print("📊 Generating coverage badge...")
    
    # Get local coverage
    coverage = get_local_coverage()
    
    # Generate badge
    svg_badge, status, color, message = generate_coverage_badge(coverage)
    
    # Save badge to file
    badge_path = Path("docs/badges/coverage.svg")
    badge_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(badge_path, 'w') as f:
        f.write(svg_badge)
    
    print(f"✅ Coverage badge generated: {badge_path}")
    print(f"📊 Coverage Status: {status.upper()}")
    print(f"📈 Coverage: {message}")
    
    # Also create a JSON file with results
    results_path = Path("docs/badges/coverage-results.json")
    with open(results_path, 'w') as f:
        json.dump({
            "coverage_percent": coverage,
            "status": status,
            "color": color,
            "message": message,
            "badge_svg": svg_badge
        }, f, indent=2)
    
    print(f"📄 Results saved: {results_path}")
    
    return {
        "coverage_percent": coverage,
        "status": status,
        "color": color,
        "message": message
    }

if __name__ == "__main__":
    main()