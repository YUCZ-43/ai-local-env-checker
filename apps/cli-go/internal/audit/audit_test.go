package audit

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteRecordsExecutionAttemptAsJSONL(t *testing.T) {
	dir := t.TempDir()
	record := Record{
		Platform:       "windows/amd64",
		ToolID:         "safe-demo",
		PlanFile:       "examples/install-plans/windows-safe-demo-plan.json",
		CommandPreview: "Write-Output hello",
		Mode:           "execute",
		RiskLevel:      "LOW",
		Allowed:        true,
		Reason:         "allowlisted LOW-risk command",
		ExitCode:       0,
		ReportPath:     filepath.Join(dir, "plan-report.json"),
	}

	path, err := Write(dir, []Record{record})

	if err != nil {
		t.Fatalf("write audit: %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read audit: %v", err)
	}
	got := string(data)
	for _, want := range []string{`"toolId":"safe-demo"`, `"allowed":true`, `"riskLevel":"LOW"`} {
		if !strings.Contains(got, want) {
			t.Fatalf("expected %s in audit log, got %s", want, got)
		}
	}
}
