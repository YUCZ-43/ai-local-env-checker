package plan

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadValidPlanWithObjectCommands(t *testing.T) {
	path := writeTempPlan(t, `{
  "id": "windows-safe-demo-plan",
  "toolId": "safe-demo",
  "platform": "windows",
  "action": "demo",
  "description": "Safe demo plan",
  "requiresAdmin": false,
  "riskLevel": "LOW",
  "confirmationRequired": true,
  "rollbackAvailable": false,
  "commands": [
    {
      "id": "demo-output",
      "description": "Print a message",
      "shell": "powershell",
      "command": "Write-Output",
      "args": ["hello"],
      "workingDirectory": ".",
      "requiresAdmin": false,
      "riskLevel": "LOW",
      "timeoutSec": 5,
      "dryRunOnly": false,
      "verificationCommands": ["Write-Output verified"]
    }
  ],
  "verificationCommands": ["Write-Output verified"],
  "autoExecute": false
}`)

	got, err := Load(path)
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if got.ID != "windows-safe-demo-plan" {
		t.Fatalf("unexpected plan id: %q", got.ID)
	}
	if got.ToolID != "safe-demo" {
		t.Fatalf("unexpected tool id: %q", got.ToolID)
	}
	if len(got.Commands) != 1 {
		t.Fatalf("expected 1 command, got %d", len(got.Commands))
	}
	cmd := got.Commands[0]
	if cmd.ID != "demo-output" || cmd.Command != "Write-Output" || cmd.Args[0] != "hello" {
		t.Fatalf("unexpected command: %#v", cmd)
	}
}

func TestLoadRejectsMissingFile(t *testing.T) {
	_, err := Load(filepath.Join(t.TempDir(), "missing.json"))
	if err == nil {
		t.Fatal("expected missing file error")
	}
}

func TestLoadRejectsInvalidJSON(t *testing.T) {
	path := writeTempPlan(t, `{`)
	_, err := Load(path)
	if err == nil {
		t.Fatal("expected invalid JSON error")
	}
}

func TestValidateRequiredFields(t *testing.T) {
	got := Validate(&Plan{})
	if len(got) == 0 {
		t.Fatal("expected validation errors for empty plan")
	}
}

func TestLoadSupportsLegacyStringCommands(t *testing.T) {
	path := writeTempPlan(t, `{
  "id": "legacy-plan",
  "platform": "windows",
  "action": "demo",
  "description": "Legacy command plan",
  "requiresAdmin": false,
  "riskLevel": "LOW",
  "confirmationRequired": true,
  "rollbackAvailable": false,
  "commands": ["whoami"],
  "verificationCommands": ["whoami"],
  "autoExecute": false
}`)

	got, err := Load(path)
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if got.Commands[0].ID == "" || got.Commands[0].Command != "whoami" {
		t.Fatalf("legacy command was not normalized: %#v", got.Commands[0])
	}
}

func writeTempPlan(t *testing.T, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "plan.json")
	if err := os.WriteFile(path, []byte(body), 0600); err != nil {
		t.Fatalf("write temp plan: %v", err)
	}
	return path
}
