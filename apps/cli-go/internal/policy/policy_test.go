package policy

import (
	"strings"
	"testing"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
)

func TestEvaluateRequiresDryRunWithoutConfirm(t *testing.T) {
	p := demoPlan("LOW")

	decision := Evaluate(p, Options{DryRun: false, Confirm: false, Elevated: false})

	if decision.Allowed {
		t.Fatalf("expected execution to be refused: %#v", decision)
	}
	if !strings.Contains(strings.Join(decision.Reasons, " "), "confirmation") {
		t.Fatalf("expected confirmation reason, got %#v", decision.Reasons)
	}
}

func TestEvaluateRefusesMediumAdminHighAndDangerousRisk(t *testing.T) {
	for _, risk := range []string{"MEDIUM", "ADMIN_REQUIRED", "HIGH", "DANGEROUS"} {
		p := demoPlan(risk)
		decision := Evaluate(p, Options{Confirm: true, Elevated: true})
		if decision.Allowed {
			t.Fatalf("expected %s to be refused: %#v", risk, decision)
		}
	}
}

func TestEvaluateRefusesAdminRequiredPlanEvenWhenElevated(t *testing.T) {
	p := demoPlan("LOW")
	p.RequiresAdmin = true

	decision := Evaluate(p, Options{Confirm: true, Elevated: true})

	if decision.Allowed {
		t.Fatalf("expected admin-required plan to be refused in v0.8.0: %#v", decision)
	}
	if !strings.Contains(strings.Join(decision.Reasons, " "), "admin") {
		t.Fatalf("expected admin reason, got %#v", decision.Reasons)
	}
}

func TestEvaluateAllowsConfirmedLowRiskNonAdminPlan(t *testing.T) {
	p := demoPlan("LOW")

	decision := Evaluate(p, Options{Confirm: true, Elevated: false})

	if !decision.Allowed {
		t.Fatalf("expected LOW confirmed plan to be allowed: %#v", decision)
	}
}

func demoPlan(risk string) *plan.Plan {
	return &plan.Plan{
		ID:                   "demo",
		Platform:             "windows",
		Action:               "demo",
		Description:          "demo",
		RiskLevel:            risk,
		ConfirmationRequired: true,
		Commands: []plan.Command{{
			ID:            "demo-output",
			Command:       "Write-Output",
			Args:          []string{"hello"},
			RiskLevel:     risk,
			RequiresAdmin: false,
		}},
	}
}
