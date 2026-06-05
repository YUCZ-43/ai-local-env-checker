package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCheckCommandPrintsDetectionPlaceholder(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"check"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "will call existing detection scripts later") {
		t.Fatalf("expected detection placeholder, got %q", out.String())
	}
}

func TestDoctorCommandPrintsPlatform(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"doctor"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "platform=") {
		t.Fatalf("expected platform diagnostic, got %q", out.String())
	}
}

func TestReportCommandPrintsReportsDirectory(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"report"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "reports") {
		t.Fatalf("expected reports directory output, got %q", out.String())
	}
}

func TestPlanCommandPrintsNonExecutingInstallPlanJSON(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"plan"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	got := out.String()
	for _, want := range []string{`"confirmationRequired": true`, `"commands"`, `"riskLevel": "LOW"`} {
		if !strings.Contains(got, want) {
			t.Fatalf("expected %s in plan output, got %q", want, got)
		}
	}
}

func TestPlanValidateCommandAcceptsSafeDemoPlan(t *testing.T) {
	path := writeCLITestPlan(t)
	var out bytes.Buffer

	code := run([]string{"plan", "validate", "--file", path}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d with output %q", code, out.String())
	}
	if !strings.Contains(out.String(), "install plan is valid") {
		t.Fatalf("expected validation success, got %q", out.String())
	}
}

func TestPlanRunDryRunPrintsCommandDetails(t *testing.T) {
	path := writeCLITestPlan(t)
	var out bytes.Buffer

	code := run([]string{"plan", "run", "--file", path, "--dry-run"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d with output %q", code, out.String())
	}
	got := out.String()
	for _, want := range []string{"riskLevel: LOW", "requiresAdmin: false", "verificationCommands:", "status: DRY_RUN"} {
		if !strings.Contains(got, want) {
			t.Fatalf("expected %q in output, got %q", want, got)
		}
	}
}

func TestPlanRunConfirmWritesAuditLog(t *testing.T) {
	outputRoot := t.TempDir()
	t.Setenv("AI_LOCAL_DEPLOY_OUTPUT_ROOT", outputRoot)
	path := writeCLITestPlan(t)
	var out bytes.Buffer

	code := run([]string{"plan", "run", "--file", path, "--confirm"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d with output %q", code, out.String())
	}
	auditDir := filepath.Join(outputRoot, "logs")
	entries, err := os.ReadDir(auditDir)
	if err != nil {
		t.Fatalf("read audit directory: %v", err)
	}
	found := false
	for _, entry := range entries {
		if strings.HasPrefix(entry.Name(), "audit-") && strings.HasSuffix(entry.Name(), ".jsonl") {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected audit jsonl in %s, got %v", auditDir, entries)
	}
}

func TestPlanRunConfirmReturnsNonzeroWhenCommandFails(t *testing.T) {
	outputRoot := t.TempDir()
	t.Setenv("AI_LOCAL_DEPLOY_OUTPUT_ROOT", outputRoot)
	path := writeCLITestPlanWithWorkingDirectory(t, filepath.Join(t.TempDir(), "missing-dir"))
	var out bytes.Buffer

	code := run([]string{"plan", "run", "--file", path, "--confirm"}, &out)

	if code == 0 {
		t.Fatalf("expected nonzero exit code for failed command, got 0 with output %q", out.String())
	}
	if !strings.Contains(out.String(), "status: FAILED") {
		t.Fatalf("expected failed command status in output, got %q", out.String())
	}
}

func TestOutputDirUsesConfiguredOutputRoot(t *testing.T) {
	outputRoot := t.TempDir()
	t.Setenv("AI_LOCAL_DEPLOY_OUTPUT_ROOT", outputRoot)

	got := outputDir("reports")

	if got != filepath.Join(outputRoot, "reports") {
		t.Fatalf("expected configured output root, got %q", got)
	}
}

func TestConfiguredContentRootRequiresInstallPlanSchema(t *testing.T) {
	contentRoot := t.TempDir()
	schemaDir := filepath.Join(contentRoot, "core", "schema")
	if err := os.MkdirAll(schemaDir, 0700); err != nil {
		t.Fatalf("create schema dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(schemaDir, "install-plan.schema.json"), []byte("{}"), 0600); err != nil {
		t.Fatalf("write schema: %v", err)
	}
	t.Setenv("AI_LOCAL_DEPLOY_CONTENT_ROOT", contentRoot)

	got, err := findRepoRoot()

	if err != nil {
		t.Fatalf("find repo root: %v", err)
	}
	if got != contentRoot {
		t.Fatalf("expected configured content root, got %q", got)
	}
}

func writeCLITestPlan(t *testing.T) string {
	t.Helper()
	return writeCLITestPlanWithWorkingDirectory(t, ".")
}

func writeCLITestPlanWithWorkingDirectory(t *testing.T, workingDirectory string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "safe-plan.json")
	body := `{
  "id": "windows-safe-demo-plan",
  "platform": "windows",
  "action": "safe-demo",
  "description": "Safe demo plan",
  "requiresAdmin": false,
  "riskLevel": "LOW",
  "confirmationRequired": true,
  "rollbackAvailable": false,
  "commands": [
    {
      "id": "demo-output",
      "description": "Print a demo message",
      "shell": "powershell",
      "command": "Write-Output",
      "args": ["hello"],
      "workingDirectory": "` + strings.ReplaceAll(workingDirectory, `\`, `\\`) + `",
      "requiresAdmin": false,
      "riskLevel": "LOW",
      "timeoutSec": 5,
      "dryRunOnly": false,
      "verificationCommands": ["Write-Output verified"]
    }
  ],
  "verificationCommands": ["Write-Output verified"],
  "autoExecute": false
}`
	if err := os.WriteFile(path, []byte(body), 0600); err != nil {
		t.Fatalf("write test plan: %v", err)
	}
	return path
}
