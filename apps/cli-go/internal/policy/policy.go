package policy

import (
	"strings"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
)

type Options struct {
	DryRun   bool
	Confirm  bool
	Elevated bool
}

type Decision struct {
	Allowed bool     `json:"allowed"`
	Mode    string   `json:"mode"`
	Reasons []string `json:"reasons"`
}

func Evaluate(p *plan.Plan, opts Options) Decision {
	mode := "execute"
	if opts.DryRun {
		mode = "dry-run"
	}
	decision := Decision{Allowed: true, Mode: mode}
	if opts.DryRun {
		return decision
	}
	if p == nil {
		return Decision{Allowed: false, Mode: mode, Reasons: []string{"plan is nil"}}
	}
	if p.ConfirmationRequired && !opts.Confirm {
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "confirmation is required before execution")
	}
	if p.RequiresAdmin && !opts.Elevated {
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "administrator elevation is required; rerun from an elevated shell in a future version")
	}
	if p.DryRunOnly {
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "plan is marked dryRunOnly")
	}
	switch strings.ToUpper(p.RiskLevel) {
	case "LOW":
	case "MEDIUM", "HIGH":
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, p.RiskLevel+" risk execution is disabled in v0.5.0")
	case "DANGEROUS":
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "DANGEROUS risk execution is always refused")
	default:
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "unknown riskLevel")
	}
	return decision
}
