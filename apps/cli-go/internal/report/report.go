package report

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/policy"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/runner"
)

type Meta struct {
	Version   string `json:"version"`
	Timestamp string `json:"timestamp"`
	Mode      string `json:"mode"`
	CheckOnly bool   `json:"checkOnly"`
}

type PlanSummary struct {
	ID          string `json:"id"`
	Platform    string `json:"platform"`
	Action      string `json:"action"`
	Description string `json:"description"`
	RiskLevel   string `json:"riskLevel"`
}

type VerificationResult struct {
	Command string `json:"command"`
	Status  string `json:"status"`
}

type Summary struct {
	TotalCommands int `json:"totalCommands"`
	Refused       int `json:"refused"`
	Succeeded     int `json:"succeeded"`
	DryRun        int `json:"dryRun"`
	Failed        int `json:"failed"`
}

type PlanReport struct {
	Meta           Meta                 `json:"Meta"`
	Plan           PlanSummary          `json:"Plan"`
	PolicyDecision policy.Decision      `json:"PolicyDecision"`
	Commands       []plan.Command       `json:"Commands"`
	Results        []runner.Result      `json:"Results"`
	Verification   []VerificationResult `json:"Verification"`
	Summary        Summary              `json:"Summary"`
}

func NewPlanReport(p *plan.Plan, decision policy.Decision, results []runner.Result, verification []VerificationResult, mode string) PlanReport {
	r := PlanReport{
		Meta: Meta{
			Version:   "v0.5.0",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Mode:      mode,
			CheckOnly: mode == "simulate" || mode == "dry-run",
		},
		PolicyDecision: decision,
		Results:        results,
		Verification:   verification,
	}
	if p != nil {
		r.Plan = PlanSummary{ID: p.ID, Platform: p.Platform, Action: p.Action, Description: p.Description, RiskLevel: p.RiskLevel}
		r.Commands = p.Commands
	}
	for _, result := range results {
		r.Summary.TotalCommands++
		switch result.Status {
		case "REFUSED":
			r.Summary.Refused++
		case "SUCCEEDED":
			r.Summary.Succeeded++
		case "DRY_RUN":
			r.Summary.DryRun++
		case "FAILED":
			r.Summary.Failed++
		}
	}
	return r
}

func SimulatedVerification(commands []string) []VerificationResult {
	results := make([]VerificationResult, 0, len(commands))
	for _, command := range commands {
		results = append(results, VerificationResult{Command: command, Status: "SIMULATED"})
	}
	return results
}

func Write(dir string, r PlanReport) (string, error) {
	if dir == "" {
		dir = "reports"
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("create reports directory: %w", err)
	}
	path := filepath.Join(dir, "plan-report-"+time.Now().UTC().Format("20060102-150405")+".json")
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return "", fmt.Errorf("encode report: %w", err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0600); err != nil {
		return "", fmt.Errorf("write report: %w", err)
	}
	return path, nil
}
