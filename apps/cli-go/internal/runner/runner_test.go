package runner

import (
	"context"
	"strings"
	"testing"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
)

func TestDryRunDoesNotExecuteCommands(t *testing.T) {
	p := demoPlan(plan.Command{ID: "demo", Command: "not-a-real-command", RiskLevel: "LOW"})

	results := DryRun(p)

	if len(results) != 1 {
		t.Fatalf("expected 1 dry-run result, got %d", len(results))
	}
	if results[0].Status != "DRY_RUN" {
		t.Fatalf("expected DRY_RUN status, got %#v", results[0])
	}
}

func TestRunRefusesWithoutConfirm(t *testing.T) {
	p := demoPlan(plan.Command{ID: "demo", Command: "Write-Output", Args: []string{"hello"}, RiskLevel: "LOW"})

	results := Run(context.Background(), p, Options{Confirm: false})

	if len(results) != 1 || results[0].Status != "REFUSED" {
		t.Fatalf("expected refused result, got %#v", results)
	}
}

func TestRunRefusesMediumAdminHighAndDangerousCommands(t *testing.T) {
	for _, risk := range []string{"MEDIUM", "ADMIN_REQUIRED", "HIGH", "DANGEROUS"} {
		p := demoPlan(plan.Command{ID: "demo", Command: "Write-Output", Args: []string{"hello"}, RiskLevel: risk})
		results := Run(context.Background(), p, Options{Confirm: true})
		if results[0].Status != "REFUSED" {
			t.Fatalf("expected %s command to be refused, got %#v", risk, results[0])
		}
	}
}

func TestAllowlistBlocksInstallAndMutationCommands(t *testing.T) {
	blocked := []plan.Command{
		{Command: "winget", Args: []string{"install", "Git.Git"}, RiskLevel: "LOW"},
		{Command: "npm", Args: []string{"install", "-g", "codex"}, RiskLevel: "LOW"},
		{Command: "setx", Args: []string{"PATH", "demo"}, RiskLevel: "LOW"},
		{Command: "Remove-Item", Args: []string{"file.txt"}, RiskLevel: "LOW"},
		{Command: "Start-Process", Args: []string{"powershell", "-Verb", "RunAs"}, RiskLevel: "LOW"},
	}
	for _, cmd := range blocked {
		if IsAllowedSafeCommand(cmd) {
			t.Fatalf("expected command to be blocked: %#v", cmd)
		}
	}
}

func TestRunAllowsSafeLowRiskDemoCommand(t *testing.T) {
	p := demoPlan(plan.Command{ID: "demo", Command: "Write-Output", Args: []string{"hello"}, RiskLevel: "LOW"})

	results := Run(context.Background(), p, Options{Confirm: true})

	if len(results) != 1 || results[0].Status != "SUCCEEDED" {
		t.Fatalf("expected safe command success, got %#v", results)
	}
	if !strings.Contains(results[0].Stdout, "hello") {
		t.Fatalf("expected command output, got %#v", results[0])
	}
}

func demoPlan(cmd plan.Command) *plan.Plan {
	return &plan.Plan{
		ID:                   "demo",
		Platform:             "windows",
		Action:               "demo",
		Description:          "demo",
		RiskLevel:            "LOW",
		ConfirmationRequired: true,
		Commands:             []plan.Command{cmd},
	}
}
