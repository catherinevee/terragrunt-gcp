package testhelpers

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// TestReport represents a comprehensive test report
type TestReport struct {
	Timestamp   time.Time    `json:"timestamp"`
	Environment string       `json:"environment"`
	Tests       []TestResult `json:"tests"`
	Summary     TestSummary  `json:"summary"`
	Metadata    TestMetadata `json:"metadata"`
}

// TestSummary represents test summary statistics
type TestSummary struct {
	Total       int           `json:"total"`
	Passed      int           `json:"passed"`
	Failed      int           `json:"failed"`
	Skipped     int           `json:"skipped"`
	Duration    time.Duration `json:"duration"`
	SuccessRate float64       `json:"success_rate"`
}

// TestMetadata represents test metadata
type TestMetadata struct {
	GoVersion        string `json:"go_version"`
	TerraformVersion string `json:"terraform_version"`
	GCPProjectID     string `json:"gcp_project_id"`
	GCPRegion        string `json:"gcp_region"`
	TestEnvironment  string `json:"test_environment"`
	TestType         string `json:"test_type"`
	TestCategory     string `json:"test_category"`
}

// GenerateTestReport generates a comprehensive test report
func GenerateTestReport(report *TestReport) error {
	// Create reports directory if it doesn't exist
	reportsDir := "test-results"
	err := os.MkdirAll(reportsDir, 0755)
	if err != nil {
		return err
	}

	// Generate filename with timestamp
	timestamp := report.Timestamp.Format("2006-01-02_15-04-05")
	filename := fmt.Sprintf("test-report-%s-%s.json", report.Environment, timestamp)
	filepath := filepath.Join(reportsDir, filename)

	// Marshal report to JSON
	data, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}

	// Write report to file
	err = os.WriteFile(filepath, data, 0644)
	if err != nil {
		return err
	}

	// Generate HTML report
	err = GenerateHTMLReport(report, reportsDir)
	if err != nil {
		return err
	}

	// Generate summary report
	err = GenerateSummaryReport(report, reportsDir)
	if err != nil {
		return err
	}

	return nil
}

// GenerateHTMLReport generates an HTML test report
func GenerateHTMLReport(report *TestReport, reportsDir string) error {
	timestamp := report.Timestamp.Format("2006-01-02_15-04-05")
	filename := fmt.Sprintf("test-report-%s-%s.html", report.Environment, timestamp)
	filepath := filepath.Join(reportsDir, filename)

	html := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <title>Test Report - %s</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .test-result { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; }
        .passed { border-left-color: #4CAF50; }
        .failed { border-left-color: #f44336; }
        .skipped { border-left-color: #ff9800; }
        .metadata { background-color: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Test Report - %s</h1>
        <p>Generated: %s</p>
        <p>Environment: %s</p>
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Tests: %d</p>
        <p>Passed: %d</p>
        <p>Failed: %d</p>
        <p>Skipped: %d</p>
        <p>Success Rate: %.2f%%</p>
        <p>Duration: %v</p>
    </div>
    
    <div class="metadata">
        <h2>Metadata</h2>
        <p>Go Version: %s</p>
        <p>Terraform Version: %s</p>
        <p>GCP Project ID: %s</p>
        <p>GCP Region: %s</p>
        <p>Test Environment: %s</p>
        <p>Test Type: %s</p>
        <p>Test Category: %s</p>
    </div>
    
    <div class="test-results">
        <h2>Test Results</h2>
        %s
    </div>
</body>
</html>
`, report.Environment, report.Environment, report.Timestamp.Format("2006-01-02 15:04:05"),
		report.Environment, report.Summary.Total, report.Summary.Passed, report.Summary.Failed,
		report.Summary.Skipped, report.Summary.SuccessRate, report.Summary.Duration,
		report.Metadata.GoVersion, report.Metadata.TerraformVersion, report.Metadata.GCPProjectID,
		report.Metadata.GCPRegion, report.Metadata.TestEnvironment, report.Metadata.TestType,
		report.Metadata.TestCategory, generateTestResultsHTML(report.Tests))

	return os.WriteFile(filepath, []byte(html), 0644)
}

// generateTestResultsHTML generates HTML for test results
func generateTestResultsHTML(tests []TestResult) string {
	html := ""
	for _, test := range tests {
		statusClass := "skipped"
		if test.Status == "passed" {
			statusClass = "passed"
		} else if test.Status == "failed" {
			statusClass = "failed"
		}

		html += fmt.Sprintf(`
        <div class="test-result %s">
            <h3>%s</h3>
            <p>Status: %s</p>
            <p>Duration: %v</p>
            <p>Tests: %d (Passed: %d, Failed: %d, Skipped: %d)</p>
            %s
        </div>
        `, statusClass, test.Key, test.Status, test.Duration, test.Tests,
			test.Passed, test.Failed, test.Skipped,
			func() string {
				if test.Error != "" {
					return fmt.Sprintf("<p>Error: %s</p>", test.Error)
				}
				return ""
			}())
	}
	return html
}

// GenerateSummaryReport generates a summary test report
func GenerateSummaryReport(report *TestReport, reportsDir string) error {
	filename := fmt.Sprintf("test-summary-%s.txt", report.Environment)
	filepath := filepath.Join(reportsDir, filename)

	summary := fmt.Sprintf(`
Test Report Summary
==================

Environment: %s
Generated: %s

Summary:
--------
Total Tests: %d
Passed: %d
Failed: %d
Skipped: %d
Success Rate: %.2f%%
Duration: %v

Metadata:
---------
Go Version: %s
Terraform Version: %s
GCP Project ID: %s
GCP Region: %s
Test Environment: %s
Test Type: %s
Test Category: %s

Test Results:
-------------
`, report.Environment, report.Timestamp.Format("2006-01-02 15:04:05"),
		report.Summary.Total, report.Summary.Passed, report.Summary.Failed,
		report.Summary.Skipped, report.Summary.SuccessRate, report.Summary.Duration,
		report.Metadata.GoVersion, report.Metadata.TerraformVersion, report.Metadata.GCPProjectID,
		report.Metadata.GCPRegion, report.Metadata.TestEnvironment, report.Metadata.TestType,
		report.Metadata.TestCategory)

	for _, test := range report.Tests {
		summary += fmt.Sprintf(`
%s:
  Status: %s
  Duration: %v
  Tests: %d (Passed: %d, Failed: %d, Skipped: %d)
  %s
`, test.Key, test.Status, test.Duration, test.Tests, test.Passed, test.Failed, test.Skipped,
			func() string {
				if test.Error != "" {
					return fmt.Sprintf("Error: %s", test.Error)
				}
				return ""
			}())
	}

	return os.WriteFile(filepath, []byte(summary), 0644)
}

// LoadTestReport loads a test report from file
func LoadTestReport(filepath string) (*TestReport, error) {
	data, err := os.ReadFile(filepath)
	if err != nil {
		return nil, err
	}

	var report TestReport
	err = json.Unmarshal(data, &report)
	if err != nil {
		return nil, err
	}

	return &report, nil
}

// GetTestReportFiles returns all test report files in a directory
func GetTestReportFiles(reportsDir string) ([]string, error) {
	var files []string

	err := filepath.Walk(reportsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && filepath.Ext(path) == ".json" {
			files = append(files, path)
		}
		return nil
	})

	return files, err
}

// MergeTestReports merges multiple test reports
func MergeTestReports(reports []*TestReport) *TestReport {
	if len(reports) == 0 {
		return nil
	}

	merged := &TestReport{
		Timestamp:   time.Now(),
		Environment: reports[0].Environment,
		Tests:       []TestResult{},
		Summary:     TestSummary{},
		Metadata:    reports[0].Metadata,
	}

	for _, report := range reports {
		merged.Tests = append(merged.Tests, report.Tests...)
		merged.Summary.Total += report.Summary.Total
		merged.Summary.Passed += report.Summary.Passed
		merged.Summary.Failed += report.Summary.Failed
		merged.Summary.Skipped += report.Summary.Skipped
		merged.Summary.Duration += report.Summary.Duration
	}

	// Calculate success rate
	if merged.Summary.Total > 0 {
		merged.Summary.SuccessRate = float64(merged.Summary.Passed) / float64(merged.Summary.Total) * 100
	}

	return merged
}

// ValidateTestReport validates a test report
func ValidateTestReport(report *TestReport) error {
	if report == nil {
		return fmt.Errorf("test report is nil")
	}

	if report.Environment == "" {
		return fmt.Errorf("environment is required")
	}

	if report.Summary.Total < 0 {
		return fmt.Errorf("total tests cannot be negative")
	}

	if report.Summary.Passed < 0 || report.Summary.Failed < 0 || report.Summary.Skipped < 0 {
		return fmt.Errorf("test counts cannot be negative")
	}

	if report.Summary.Passed+report.Summary.Failed+report.Summary.Skipped != report.Summary.Total {
		return fmt.Errorf("test counts do not add up to total")
	}

	return nil
}
