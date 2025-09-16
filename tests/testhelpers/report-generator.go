package testhelpers

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// GenerateTestReport creates a comprehensive test report
func GenerateTestReport(environment string) *TestReport {
	return &TestReport{
		Timestamp:   time.Now(),
		Environment: environment,
		Tests:       []TestResult{},
		Summary:     TestSummary{},
		Metadata: TestMetadata{
			GoVersion:        getEnv("GO_VERSION", "unknown"),
			TerraformVersion: getEnv("TF_VERSION", "unknown"),
			GCPProjectID:     getEnv("GCP_PROJECT_ID", "unknown"),
			GCPRegion:        getEnv("GCP_REGION", "unknown"),
			TestEnvironment:  environment,
			TestType:         "comprehensive",
			TestCategory:     "infrastructure",
		},
	}
}

// AddTestResult adds a test result to the report
func (r *TestReport) AddTestResult(result TestResult) {
	r.Tests = append(r.Tests, result)
}

// UpdateSummary updates the test summary
func (r *TestReport) UpdateSummary() {
	total := len(r.Tests)
	passed := 0
	failed := 0
	skipped := 0
	var totalDuration time.Duration

	for _, test := range r.Tests {
		totalDuration += test.Duration
		switch test.Status {
		case "PASS":
			passed++
		case "FAIL":
			failed++
		case "SKIP":
			skipped++
		}
	}

	successRate := 0.0
	if total > 0 {
		successRate = float64(passed) / float64(total) * 100
	}

	r.Summary = TestSummary{
		Total:       total,
		Passed:      passed,
		Failed:      failed,
		Skipped:     skipped,
		Duration:    totalDuration,
		SuccessRate: successRate,
	}
}

// SaveReport saves the report to a file
func (r *TestReport) SaveReport(filename string) error {
	r.UpdateSummary()

	// Create output directory if it doesn't exist
	dir := filepath.Dir(filename)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}

	// Save JSON report
	jsonFile := filename + ".json"
	jsonData, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %v", err)
	}

	if err := os.WriteFile(jsonFile, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write JSON file: %v", err)
	}

	// Save HTML report
	htmlFile := filename + ".html"
	htmlContent := generateTestResultsHTML(r)
	if err := os.WriteFile(htmlFile, []byte(htmlContent), 0644); err != nil {
		return fmt.Errorf("failed to write HTML file: %v", err)
	}

	fmt.Printf("Test report saved to %s and %s\n", jsonFile, htmlFile)
	return nil
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
