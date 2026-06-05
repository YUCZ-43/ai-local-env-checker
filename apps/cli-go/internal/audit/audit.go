package audit

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type Record struct {
	Timestamp      string `json:"timestamp"`
	Platform       string `json:"platform"`
	ToolID         string `json:"toolId"`
	PlanFile       string `json:"planFile"`
	CommandPreview string `json:"commandPreview"`
	Mode           string `json:"mode"`
	RiskLevel      string `json:"riskLevel"`
	Allowed        bool   `json:"allowed"`
	Reason         string `json:"reason"`
	ExitCode       int    `json:"exitCode,omitempty"`
	StdoutSummary  string `json:"stdoutSummary,omitempty"`
	StderrSummary  string `json:"stderrSummary,omitempty"`
	ReportPath     string `json:"reportPath,omitempty"`
}

func Write(dir string, records []Record) (string, error) {
	if dir == "" {
		dir = "logs"
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("create audit log directory: %w", err)
	}
	path := filepath.Join(dir, "audit-"+time.Now().UTC().Format("20060102-150405")+".jsonl")
	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return "", fmt.Errorf("open audit log: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	for _, record := range records {
		if record.Timestamp == "" {
			record.Timestamp = time.Now().UTC().Format(time.RFC3339)
		}
		if err := encoder.Encode(record); err != nil {
			return "", fmt.Errorf("write audit record: %w", err)
		}
	}
	return path, nil
}
