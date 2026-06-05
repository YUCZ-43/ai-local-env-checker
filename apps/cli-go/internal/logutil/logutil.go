package logutil

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

func CreateLog(dir string, lines []string) (string, error) {
	if dir == "" {
		dir = "logs"
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("create logs directory: %w", err)
	}
	path := filepath.Join(dir, "run-"+time.Now().UTC().Format("20060102-150405")+".log")
	body := ""
	for _, line := range lines {
		body += redact(line) + "\n"
	}
	if err := os.WriteFile(path, []byte(body), 0600); err != nil {
		return "", fmt.Errorf("write log: %w", err)
	}
	return path, nil
}

func redact(s string) string {
	return s
}
