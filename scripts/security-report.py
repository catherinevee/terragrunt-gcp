#!/usr/bin/env python3
"""
Security Report Generator
Generates comprehensive security reports from multiple security scanning tools.
"""

import json
import os
from pathlib import Path
from datetime import datetime

def load_json_file(file_path):
    """Load JSON file safely."""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def generate_security_report():
    """Generate comprehensive security report."""
    print("📊 Generating security report...")
    
    # Load results from different security tools
    checkov_results = load_json_file("checkov-results.json")
    trivy_results = load_json_file("trivy-results.json")
    gosec_results = load_json_file("gosec-results.json")
    semgrep_results = load_json_file("semgrep-results.json")
    
    # Initialize report
    report = {
        "timestamp": datetime.now().isoformat(),
        "summary": {
            "total_issues": 0,
            "critical_issues": 0,
            "high_issues": 0,
            "medium_issues": 0,
            "low_issues": 0,
            "info_issues": 0
        },
        "tools": {},
        "recommendations": []
    }
    
    # Process Checkov results
    if checkov_results:
        checkov_issues = checkov_results.get("failed", 0)
        report["tools"]["checkov"] = {
            "status": "completed",
            "issues_found": checkov_issues,
            "passed": checkov_results.get("passed", 0),
            "skipped": checkov_results.get("skipped", 0)
        }
        report["summary"]["total_issues"] += checkov_issues
        report["summary"]["medium_issues"] += checkov_issues
    else:
        report["tools"]["checkov"] = {"status": "failed", "issues_found": 0}
    
    # Process Trivy results
    if trivy_results:
        vulnerabilities = trivy_results.get("Results", [])
        trivy_issues = len(vulnerabilities)
        report["tools"]["trivy"] = {
            "status": "completed",
            "issues_found": trivy_issues,
            "vulnerabilities": vulnerabilities
        }
        report["summary"]["total_issues"] += trivy_issues
        report["summary"]["high_issues"] += trivy_issues
    else:
        report["tools"]["trivy"] = {"status": "failed", "issues_found": 0}
    
    # Process Gosec results
    if gosec_results:
        gosec_issues = len(gosec_results.get("Issues", []))
        report["tools"]["gosec"] = {
            "status": "completed",
            "issues_found": gosec_issues,
            "issues": gosec_results.get("Issues", [])
        }
        report["summary"]["total_issues"] += gosec_issues
        report["summary"]["medium_issues"] += gosec_issues
    else:
        report["tools"]["gosec"] = {"status": "failed", "issues_found": 0}
    
    # Process Semgrep results
    if semgrep_results:
        semgrep_issues = len(semgrep_results.get("results", []))
        report["tools"]["semgrep"] = {
            "status": "completed",
            "issues_found": semgrep_issues,
            "results": semgrep_results.get("results", [])
        }
        report["summary"]["total_issues"] += semgrep_issues
        report["summary"]["low_issues"] += semgrep_issues
    else:
        report["tools"]["semgrep"] = {"status": "failed", "issues_found": 0}
    
    # Generate recommendations
    if report["summary"]["critical_issues"] > 0:
        report["recommendations"].append("🚨 Critical issues found - immediate action required")
    if report["summary"]["high_issues"] > 0:
        report["recommendations"].append("⚠️ High priority issues found - address within 24 hours")
    if report["summary"]["medium_issues"] > 0:
        report["recommendations"].append("📋 Medium priority issues found - address within 1 week")
    if report["summary"]["low_issues"] > 0:
        report["recommendations"].append("ℹ️ Low priority issues found - address when convenient")
    
    # Calculate security score
    total_issues = report["summary"]["total_issues"]
    if total_issues == 0:
        security_score = 100
    elif total_issues <= 2:
        security_score = 95
    elif total_issues <= 5:
        security_score = 85
    elif total_issues <= 10:
        security_score = 70
    else:
        security_score = 50
    
    report["security_score"] = security_score
    report["security_grade"] = get_security_grade(security_score)
    
    # Save report
    report_path = Path("docs/badges/security-results.json")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"✅ Security report generated: {report_path}")
    print(f"📊 Security Score: {security_score}/100 ({report['security_grade']})")
    print(f"📈 Total Issues: {total_issues}")
    
    return report

def get_security_grade(score):
    """Get security grade based on score."""
    if score >= 95:
        return "A+"
    elif score >= 90:
        return "A"
    elif score >= 80:
        return "B"
    elif score >= 70:
        return "C"
    elif score >= 60:
        return "D"
    else:
        return "F"

def main():
    """Main function."""
    report = generate_security_report()
    return report

if __name__ == "__main__":
    main()
