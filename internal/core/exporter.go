package core

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"cloud.google.com/go/bigquery"
	"cloud.google.com/go/storage"
	"github.com/sirupsen/logrus"
	"google.golang.org/api/option"
)

type Exporter struct {
	logger *logrus.Logger
	config ExporterConfig
}

type ExporterConfig struct {
	BatchSize        int
	CompressionLevel int
	Timeout          time.Duration
	RetryAttempts    int
	RetryDelay       time.Duration
}

type ExportOptions struct {
	Format          string
	Destination     string
	Bucket          string
	Dataset         string
	Table           string
	Path            string
	Compress        bool
	IncludeMetadata bool
	Filters         map[string]interface{}
	Transform       TransformFunc
}

type TransformFunc func(interface{}) (interface{}, error)

type ExportResult struct {
	Format       string                 `json:"format"`
	Destination  string                 `json:"destination"`
	Location     string                 `json:"location"`
	RecordsCount int                    `json:"records_count"`
	BytesWritten int64                  `json:"bytes_written"`
	Duration     time.Duration          `json:"duration"`
	Metadata     map[string]interface{} `json:"metadata,omitempty"`
	Error        error                  `json:"error,omitempty"`
}

func NewExporter(logger *logrus.Logger) *Exporter {
	return &Exporter{
		logger: logger,
		config: ExporterConfig{
			BatchSize:        1000,
			CompressionLevel: gzip.DefaultCompression,
			Timeout:          10 * time.Minute,
			RetryAttempts:    3,
			RetryDelay:       2 * time.Second,
		},
	}
}

func (e *Exporter) Export(ctx context.Context, data interface{}, options ExportOptions) error {
	ctx, cancel := context.WithTimeout(ctx, e.config.Timeout)
	defer cancel()

	e.logger.Infof("Starting export to %s in %s format", options.Destination, options.Format)

	if options.Transform != nil {
		transformed, err := options.Transform(data)
		if err != nil {
			return fmt.Errorf("failed to transform data: %w", err)
		}
		data = transformed
	}

	switch strings.ToLower(options.Destination) {
	case "file", "local":
		return e.exportToFile(ctx, data, options)
	case "gcs", "storage":
		return e.exportToGCS(ctx, data, options)
	case "bq", "bigquery":
		return e.exportToBigQuery(ctx, data, options)
	case "stdout":
		return e.exportToStdout(data, options)
	default:
		return fmt.Errorf("unsupported destination: %s", options.Destination)
	}
}

func (e *Exporter) exportToFile(ctx context.Context, data interface{}, options ExportOptions) error {
	if options.Path == "" {
		options.Path = fmt.Sprintf("export-%s.%s",
			time.Now().Format("20060102-150405"),
			e.getFileExtension(options.Format))
	}

	dir := filepath.Dir(options.Path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", dir, err)
	}

	var content []byte
	var err error

	switch strings.ToLower(options.Format) {
	case "json":
		content, err = e.marshalJSON(data, true)
	case "csv":
		content, err = e.marshalCSV(data)
	case "terraform", "tf":
		content, err = e.marshalTerraform(data)
	case "yaml":
		content, err = e.marshalYAML(data)
	case "html":
		content, err = e.marshalHTML(data)
	case "markdown", "md":
		content, err = e.marshalMarkdown(data)
	default:
		return fmt.Errorf("unsupported format: %s", options.Format)
	}

	if err != nil {
		return fmt.Errorf("failed to marshal data: %w", err)
	}

	if options.Compress {
		content, err = e.compressData(content)
		if err != nil {
			return fmt.Errorf("failed to compress data: %w", err)
		}
		if !strings.HasSuffix(options.Path, ".gz") {
			options.Path += ".gz"
		}
	}

	if err := os.WriteFile(options.Path, content, 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	e.logger.Infof("Successfully exported to file: %s (%d bytes)", options.Path, len(content))
	return nil
}

func (e *Exporter) exportToGCS(ctx context.Context, data interface{}, options ExportOptions) error {
	if options.Bucket == "" {
		return fmt.Errorf("bucket name is required for GCS export")
	}

	client, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create storage client: %w", err)
	}
	defer client.Close()

	content, err := e.prepareContent(data, options)
	if err != nil {
		return fmt.Errorf("failed to prepare content: %w", err)
	}

	objectName := options.Path
	if objectName == "" {
		objectName = fmt.Sprintf("exports/%s/export-%s.%s",
			time.Now().Format("2006-01-02"),
			time.Now().Format("150405"),
			e.getFileExtension(options.Format))
	}

	if options.Compress && !strings.HasSuffix(objectName, ".gz") {
		objectName += ".gz"
	}

	bucket := client.Bucket(options.Bucket)
	obj := bucket.Object(objectName)

	writer := obj.NewWriter(ctx)
	writer.ContentType = e.getContentType(options.Format)

	if options.IncludeMetadata {
		writer.Metadata = map[string]string{
			"export-time":   time.Now().Format(time.RFC3339),
			"export-format": options.Format,
			"compressed":    fmt.Sprintf("%v", options.Compress),
		}
	}

	if _, err := writer.Write(content); err != nil {
		writer.Close()
		return fmt.Errorf("failed to write to GCS: %w", err)
	}

	if err := writer.Close(); err != nil {
		return fmt.Errorf("failed to close GCS writer: %w", err)
	}

	e.logger.Infof("Successfully exported to GCS: gs://%s/%s", options.Bucket, objectName)
	return nil
}

func (e *Exporter) exportToBigQuery(ctx context.Context, data interface{}, options ExportOptions) error {
	if options.Dataset == "" || options.Table == "" {
		return fmt.Errorf("dataset and table are required for BigQuery export")
	}

	client, err := bigquery.NewClient(ctx, os.Getenv("GOOGLE_CLOUD_PROJECT"))
	if err != nil {
		return fmt.Errorf("failed to create BigQuery client: %w", err)
	}
	defer client.Close()

	dataset := client.Dataset(options.Dataset)
	table := dataset.Table(options.Table)

	schema, err := e.inferBigQuerySchema(data)
	if err != nil {
		return fmt.Errorf("failed to infer schema: %w", err)
	}

	metadata := &bigquery.TableMetadata{
		Schema: schema,
	}

	if err := table.Create(ctx, metadata); err != nil {
		if !strings.Contains(err.Error(), "Already Exists") {
			return fmt.Errorf("failed to create table: %w", err)
		}
	}

	inserter := table.Inserter()

	records, err := e.prepareBigQueryRecords(data)
	if err != nil {
		return fmt.Errorf("failed to prepare records: %w", err)
	}

	for i := 0; i < len(records); i += e.config.BatchSize {
		end := i + e.config.BatchSize
		if end > len(records) {
			end = len(records)
		}

		batch := records[i:end]
		if err := inserter.Put(ctx, batch); err != nil {
			return fmt.Errorf("failed to insert batch %d-%d: %w", i, end, err)
		}

		e.logger.Debugf("Inserted batch %d-%d of %d records", i, end, len(records))
	}

	e.logger.Infof("Successfully exported %d records to BigQuery: %s.%s",
		len(records), options.Dataset, options.Table)
	return nil
}

func (e *Exporter) exportToStdout(data interface{}, options ExportOptions) error {
	content, err := e.prepareContent(data, options)
	if err != nil {
		return fmt.Errorf("failed to prepare content: %w", err)
	}

	_, err = os.Stdout.Write(content)
	return err
}

func (e *Exporter) prepareContent(data interface{}, options ExportOptions) ([]byte, error) {
	var content []byte
	var err error

	switch strings.ToLower(options.Format) {
	case "json":
		content, err = e.marshalJSON(data, true)
	case "csv":
		content, err = e.marshalCSV(data)
	case "terraform", "tf":
		content, err = e.marshalTerraform(data)
	case "yaml":
		content, err = e.marshalYAML(data)
	default:
		content, err = e.marshalJSON(data, false)
	}

	if err != nil {
		return nil, err
	}

	if options.Compress {
		return e.compressData(content)
	}

	return content, nil
}

func (e *Exporter) marshalJSON(data interface{}, indent bool) ([]byte, error) {
	if indent {
		return json.MarshalIndent(data, "", "  ")
	}
	return json.Marshal(data)
}

func (e *Exporter) marshalCSV(data interface{}) ([]byte, error) {
	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)

	switch v := data.(type) {
	case *DiscoveryResults:
		headers := []string{"ID", "Name", "Type", "Region", "Status", "Created", "Modified", "Cost"}
		if err := writer.Write(headers); err != nil {
			return nil, err
		}

		for _, resource := range v.Resources {
			cost := "0"
			if resource.Cost != nil {
				cost = fmt.Sprintf("%.2f", resource.Cost.Actual)
			}

			record := []string{
				resource.ID,
				resource.Name,
				resource.Type,
				resource.Region,
				resource.Status,
				resource.CreatedAt.Format(time.RFC3339),
				resource.ModifiedAt.Format(time.RFC3339),
				cost,
			}
			if err := writer.Write(record); err != nil {
				return nil, err
			}
		}

	case []Resource:
		headers := []string{"ID", "Name", "Type", "Region", "Status"}
		if err := writer.Write(headers); err != nil {
			return nil, err
		}

		for _, resource := range v {
			record := []string{
				resource.ID,
				resource.Name,
				resource.Type,
				resource.Region,
				resource.Status,
			}
			if err := writer.Write(record); err != nil {
				return nil, err
			}
		}

	default:
		return nil, fmt.Errorf("unsupported data type for CSV export: %T", data)
	}

	writer.Flush()
	return buf.Bytes(), writer.Error()
}

func (e *Exporter) marshalTerraform(data interface{}) ([]byte, error) {
	var buf bytes.Buffer

	switch v := data.(type) {
	case *DiscoveryResults:
		for _, resource := range v.Resources {
			tf := e.resourceToTerraform(resource)
			buf.WriteString(tf)
			buf.WriteString("\n\n")
		}

	case []Resource:
		for _, resource := range v {
			tf := e.resourceToTerraform(resource)
			buf.WriteString(tf)
			buf.WriteString("\n\n")
		}

	default:
		return nil, fmt.Errorf("unsupported data type for Terraform export: %T", data)
	}

	return buf.Bytes(), nil
}

func (e *Exporter) resourceToTerraform(resource Resource) string {
	var buf bytes.Buffer

	resourceType := e.mapToTerraformType(resource.Type)
	resourceName := e.sanitizeTerraformName(resource.Name)

	buf.WriteString(fmt.Sprintf("resource \"%s\" \"%s\" {\n", resourceType, resourceName))

	if resource.Configuration != nil {
		for key, value := range resource.Configuration {
			buf.WriteString(fmt.Sprintf("  %s = %q\n", key, value))
		}
	}

	if len(resource.Labels) > 0 {
		buf.WriteString("  labels = {\n")
		for key, value := range resource.Labels {
			buf.WriteString(fmt.Sprintf("    %s = %q\n", key, value))
		}
		buf.WriteString("  }\n")
	}

	if len(resource.Tags) > 0 {
		buf.WriteString("  tags = {\n")
		for key, value := range resource.Tags {
			buf.WriteString(fmt.Sprintf("    %s = %q\n", key, value))
		}
		buf.WriteString("  }\n")
	}

	buf.WriteString("}")

	return buf.String()
}

func (e *Exporter) marshalYAML(data interface{}) ([]byte, error) {
	jsonData, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}

	var yamlData interface{}
	if err := json.Unmarshal(jsonData, &yamlData); err != nil {
		return nil, err
	}

	return e.toYAML(yamlData, 0), nil
}

func (e *Exporter) toYAML(data interface{}, indent int) []byte {
	var buf bytes.Buffer
	indentStr := strings.Repeat("  ", indent)

	switch v := data.(type) {
	case map[string]interface{}:
		for key, value := range v {
			buf.WriteString(fmt.Sprintf("%s%s:\n", indentStr, key))
			buf.Write(e.toYAML(value, indent+1))
		}
	case []interface{}:
		for _, item := range v {
			buf.WriteString(fmt.Sprintf("%s- ", indentStr))
			yamlItem := e.toYAML(item, indent+1)
			if bytes.HasPrefix(yamlItem, []byte(strings.Repeat("  ", indent+1))) {
				buf.Write(yamlItem[len(indentStr)+2:])
			} else {
				buf.Write(yamlItem)
			}
		}
	default:
		buf.WriteString(fmt.Sprintf("%s%v\n", indentStr, v))
	}

	return buf.Bytes()
}

func (e *Exporter) marshalHTML(data interface{}) ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString(`<!DOCTYPE html>
<html>
<head>
    <title>CloudRecon Export</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:hover { background-color: #f5f5f5; }
        .summary { background-color: #e7f3ff; padding: 10px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>CloudRecon Export Report</h1>
`)

	switch v := data.(type) {
	case *DiscoveryResults:
		buf.WriteString(fmt.Sprintf(`
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Resources: %d</p>
        <p>Duration: %v</p>
        <p>Exported: %s</p>
    </div>
`, v.Summary.TotalResources, v.Duration, time.Now().Format(time.RFC3339)))

		buf.WriteString(`
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Type</th>
                <th>Region</th>
                <th>Status</th>
                <th>Created</th>
            </tr>
        </thead>
        <tbody>
`)

		for _, resource := range v.Resources {
			buf.WriteString(fmt.Sprintf(`
            <tr>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
                <td>%s</td>
            </tr>
`, resource.ID, resource.Name, resource.Type, resource.Region,
				resource.Status, resource.CreatedAt.Format(time.RFC3339)))
		}

		buf.WriteString(`
        </tbody>
    </table>
`)
	}

	buf.WriteString(`
</body>
</html>
`)

	return buf.Bytes(), nil
}

func (e *Exporter) marshalMarkdown(data interface{}) ([]byte, error) {
	var buf bytes.Buffer

	buf.WriteString("# CloudRecon Export Report\n\n")
	buf.WriteString(fmt.Sprintf("Generated: %s\n\n", time.Now().Format(time.RFC3339)))

	switch v := data.(type) {
	case *DiscoveryResults:
		buf.WriteString("## Summary\n\n")
		buf.WriteString(fmt.Sprintf("- **Total Resources**: %d\n", v.Summary.TotalResources))
		buf.WriteString(fmt.Sprintf("- **Duration**: %v\n", v.Duration))
		buf.WriteString(fmt.Sprintf("- **Errors**: %d\n\n", len(v.Errors)))

		buf.WriteString("## Resources by Type\n\n")
		for resType, count := range v.Summary.ResourcesByType {
			buf.WriteString(fmt.Sprintf("- %s: %d\n", resType, count))
		}
		buf.WriteString("\n")

		buf.WriteString("## Resources\n\n")
		buf.WriteString("| ID | Name | Type | Region | Status | Created |\n")
		buf.WriteString("|---|---|---|---|---|---|\n")

		for _, resource := range v.Resources {
			buf.WriteString(fmt.Sprintf("| %s | %s | %s | %s | %s | %s |\n",
				resource.ID, resource.Name, resource.Type, resource.Region,
				resource.Status, resource.CreatedAt.Format("2006-01-02")))
		}
	}

	return buf.Bytes(), nil
}

func (e *Exporter) compressData(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	gz, err := gzip.NewWriterLevel(&buf, e.config.CompressionLevel)
	if err != nil {
		return nil, err
	}

	if _, err := gz.Write(data); err != nil {
		gz.Close()
		return nil, err
	}

	if err := gz.Close(); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

func (e *Exporter) inferBigQuerySchema(data interface{}) (bigquery.Schema, error) {
	switch v := data.(type) {
	case *DiscoveryResults:
		return bigquery.Schema{
			{Name: "id", Type: bigquery.StringFieldType},
			{Name: "name", Type: bigquery.StringFieldType},
			{Name: "type", Type: bigquery.StringFieldType},
			{Name: "region", Type: bigquery.StringFieldType},
			{Name: "status", Type: bigquery.StringFieldType},
			{Name: "created_at", Type: bigquery.TimestampFieldType},
			{Name: "modified_at", Type: bigquery.TimestampFieldType},
			{Name: "cost", Type: bigquery.FloatFieldType},
		}, nil

	case []Resource:
		if len(v) == 0 {
			return nil, fmt.Errorf("cannot infer schema from empty resource list")
		}
		return e.inferBigQuerySchema(&DiscoveryResults{Resources: v})

	default:
		return nil, fmt.Errorf("unsupported data type for BigQuery: %T", data)
	}
}

func (e *Exporter) prepareBigQueryRecords(data interface{}) ([]interface{}, error) {
	var records []interface{}

	switch v := data.(type) {
	case *DiscoveryResults:
		for _, resource := range v.Resources {
			cost := 0.0
			if resource.Cost != nil {
				cost = resource.Cost.Actual
			}

			record := map[string]interface{}{
				"id":          resource.ID,
				"name":        resource.Name,
				"type":        resource.Type,
				"region":      resource.Region,
				"status":      resource.Status,
				"created_at":  resource.CreatedAt,
				"modified_at": resource.ModifiedAt,
				"cost":        cost,
			}
			records = append(records, record)
		}

	case []Resource:
		return e.prepareBigQueryRecords(&DiscoveryResults{Resources: v})

	default:
		return nil, fmt.Errorf("unsupported data type: %T", data)
	}

	return records, nil
}

func (e *Exporter) getFileExtension(format string) string {
	switch strings.ToLower(format) {
	case "json":
		return "json"
	case "csv":
		return "csv"
	case "terraform", "tf":
		return "tf"
	case "yaml":
		return "yaml"
	case "html":
		return "html"
	case "markdown", "md":
		return "md"
	default:
		return "txt"
	}
}

func (e *Exporter) getContentType(format string) string {
	switch strings.ToLower(format) {
	case "json":
		return "application/json"
	case "csv":
		return "text/csv"
	case "yaml":
		return "text/yaml"
	case "html":
		return "text/html"
	case "markdown", "md":
		return "text/markdown"
	default:
		return "text/plain"
	}
}

func (e *Exporter) mapToTerraformType(resourceType string) string {
	parts := strings.Split(resourceType, ".")
	if len(parts) < 2 {
		return resourceType
	}

	service := parts[0]
	resource := parts[1]

	switch service {
	case "compute":
		return fmt.Sprintf("google_compute_%s", resource)
	case "storage":
		return fmt.Sprintf("google_storage_%s", resource)
	case "sql":
		return fmt.Sprintf("google_sql_%s", resource)
	case "bigquery":
		return fmt.Sprintf("google_bigquery_%s", resource)
	default:
		return fmt.Sprintf("google_%s_%s", service, resource)
	}
}

func (e *Exporter) sanitizeTerraformName(name string) string {
	sanitized := strings.ToLower(name)
	sanitized = strings.ReplaceAll(sanitized, " ", "_")
	sanitized = strings.ReplaceAll(sanitized, "-", "_")
	sanitized = strings.ReplaceAll(sanitized, ".", "_")
	sanitized = strings.ReplaceAll(sanitized, "/", "_")

	return sanitized
}