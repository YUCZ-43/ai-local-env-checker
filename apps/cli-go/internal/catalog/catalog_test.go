package catalog

import (
	"path/filepath"
	"testing"
)

func TestLoadAllCatalogTools(t *testing.T) {
	root := filepath.Join("..", "..", "..", "..")
	items, err := LoadAll(filepath.Join(root, "core", "tool-catalog"))
	if err != nil {
		t.Fatalf("LoadAll returned error: %v", err)
	}
	if len(items) < 15 {
		t.Fatalf("expected at least 15 tools, got %d", len(items))
	}
	if _, ok := Find(items, "claude-code"); !ok {
		t.Fatal("expected claude-code tool")
	}
}

func TestValidateRejectsInstallableAgentWithoutWarnings(t *testing.T) {
	tool := Tool{
		ID:                     "agent",
		DisplayName:            "Agent",
		Category:               "agent-tool",
		Description:            "Agent tool",
		SupportedPlatforms:     []string{"windows"},
		RecommendedInstallMode: "dry-run-only",
		DetectionCommands:      []Command{{Platform: "windows", Shell: "powershell", Command: "agent --version", RiskLevel: "LOW"}},
		InstallPlanTemplates:   []PlanTemplate{{ID: "agent-plan", Path: "examples/install-plans/agent.json", DryRunOnly: true, RiskLevel: "MEDIUM"}},
		VerificationCommands:   []Command{{Platform: "windows", Shell: "powershell", Command: "agent --version", RiskLevel: "LOW"}},
		RiskLevel:              "MEDIUM",
		Status:                 "template-only",
	}
	errs := Validate(tool)
	if len(errs) == 0 {
		t.Fatal("expected validation errors")
	}
}
