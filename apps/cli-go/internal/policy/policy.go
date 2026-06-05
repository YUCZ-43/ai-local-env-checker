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
	if p.RequiresAdmin {
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "admin-required plans are blocked in v0.8.0; no auto-elevation is performed")
	}
	if p.DryRunOnly {
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "plan is marked dryRunOnly")
	}
	switch strings.ToUpper(p.RiskLevel) {
	case "LOW":
	case "MEDIUM", "HIGH", "ADMIN_REQUIRED":
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, p.RiskLevel+" risk execution is disabled in v0.8.0")
	case "DANGEROUS":
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "DANGEROUS risk execution is always refused")
	default:
		decision.Allowed = false
		decision.Reasons = append(decision.Reasons, "unknown riskLevel")
	}
	for _, cmd := range p.Commands {
		if cmd.RequiresAdmin {
			decision.Allowed = false
			decision.Reasons = append(decision.Reasons, "command "+cmd.ID+" requires admin privileges and is blocked in v0.8.0")
		}
		switch strings.ToUpper(strings.TrimSpace(cmd.RiskLevel)) {
		case "LOW":
		case "MEDIUM", "HIGH", "ADMIN_REQUIRED":
			decision.Allowed = false
			decision.Reasons = append(decision.Reasons, "command "+cmd.ID+" "+cmd.RiskLevel+" risk execution is disabled in v0.8.0")
		case "DANGEROUS":
			decision.Allowed = false
			decision.Reasons = append(decision.Reasons, "command "+cmd.ID+" DANGEROUS risk execution is always refused")
		default:
			decision.Allowed = false
			decision.Reasons = append(decision.Reasons, "command "+cmd.ID+" has unknown riskLevel")
		}
	}
	return decision
}
