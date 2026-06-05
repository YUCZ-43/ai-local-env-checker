package detect

import (
	"os/exec"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/platform"
)

type ToolCheck struct {
	Name      string `json:"name"`
	Detected  bool   `json:"detected"`
	Detail    string `json:"detail,omitempty"`
	CheckOnly bool   `json:"checkOnly"`
}

type DoctorReport struct {
	Platform platform.Info `json:"platform"`
	Tools    []ToolCheck   `json:"tools"`
}

func Doctor() DoctorReport {
	tools := []string{"git", "node", "npm", "code", "wsl", "claude", "codex"}
	report := DoctorReport{Platform: platform.Current()}
	for _, name := range tools {
		path, err := exec.LookPath(name)
		check := ToolCheck{Name: name, Detected: err == nil, CheckOnly: true}
		if err == nil {
			check.Detail = path
		}
		report.Tools = append(report.Tools, check)
	}
	return report
}
