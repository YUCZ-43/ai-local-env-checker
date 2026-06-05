package report

import (
	"testing"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/policy"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/runner"
)

func TestNewPlanReportIncludesRequiredSections(t *testing.T) {
	p := &plan.Plan{
		ID:          "demo",
		Platform:    "windows",
		Action:      "demo",
		Description: "demo",
		Commands:    []plan.Command{{ID: "demo", Command: "whoami", RiskLevel: "LOW"}},
	}
	decision := policy.Decision{Allowed: true, Mode: "dry-run"}
	results := []runner.Result{{ID: "demo", Status: "DRY_RUN"}}

	got := NewPlanReport(p, decision, results, []VerificationResult{{Command: "whoami", Status: "SIMULATED"}}, "simulate")

	if got.Meta.Mode != "simulate" {
		t.Fatalf("unexpected mode: %#v", got.Meta)
	}
	if got.Plan.ID != "demo" {
		t.Fatalf("unexpected plan section: %#v", got.Plan)
	}
	if len(got.Commands) != 1 || len(got.Results) != 1 || len(got.Verification) != 1 {
		t.Fatalf("expected commands, results, and verification sections: %#v", got)
	}
}
