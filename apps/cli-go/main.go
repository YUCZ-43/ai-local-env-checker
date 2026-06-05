package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/detect"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/logutil"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/policy"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/report"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/runner"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdout))
}

func run(args []string, out io.Writer) int {
	if len(args) == 0 {
		printUsage(out)
		return 2
	}

	switch args[0] {
	case "check":
		fmt.Fprintln(out, "ai-local-deploy check: will call existing detection scripts later. No install actions are executed.")
	case "doctor":
		return runDoctor(out)
	case "report":
		fmt.Fprintf(out, "ai-local-deploy report: expected logs directory: %s\n", filepath.Join(".", "logs"))
		fmt.Fprintf(out, "ai-local-deploy report: expected reports directory: %s\n", filepath.Join(".", "reports"))
	case "plan":
		return runPlan(args[1:], out)
	default:
		fmt.Fprintf(out, "unknown command: %s\n", args[0])
		printUsage(out)
		return 2
	}

	return 0
}

func runPlan(args []string, out io.Writer) int {
	if len(args) == 0 {
		printExamplePlan(out)
		return 0
	}
	switch args[0] {
	case "show":
		path, err := requireFile(args[1:])
		if err != nil {
			fmt.Fprintln(out, err)
			return 2
		}
		p, err := plan.Load(path)
		if err != nil {
			fmt.Fprintf(out, "failed to load plan: %v\n", err)
			return 1
		}
		printPlanSummary(out, p)
	case "validate":
		path, err := requireFile(args[1:])
		if err != nil {
			fmt.Fprintln(out, err)
			return 2
		}
		p, err := plan.Load(path)
		if err != nil {
			fmt.Fprintf(out, "failed to load plan: %v\n", err)
			return 1
		}
		errs := plan.Validate(p)
		if len(errs) > 0 {
			fmt.Fprintln(out, "install plan validation failed:")
			for _, item := range errs {
				fmt.Fprintf(out, "- %s\n", item)
			}
			return 1
		}
		fmt.Fprintf(out, "install plan is valid: %s\n", p.ID)
	case "run":
		return runPlanRun(args[1:], out)
	case "simulate":
		path, err := requireFile(args[1:])
		if err != nil {
			fmt.Fprintln(out, err)
			return 2
		}
		return simulatePlan(path, out)
	default:
		fmt.Fprintf(out, "unknown plan command: %s\n", args[0])
		printUsage(out)
		return 2
	}
	return 0
}

func runPlanRun(args []string, out io.Writer) int {
	path, err := requireFile(args)
	if err != nil {
		fmt.Fprintln(out, err)
		return 2
	}
	dryRun := hasFlag(args, "--dry-run")
	confirm := hasFlag(args, "--confirm")
	if !dryRun && !confirm {
		fmt.Fprintln(out, "plan run requires --dry-run or --confirm")
		return 2
	}
	p, err := plan.Load(path)
	if err != nil {
		fmt.Fprintf(out, "failed to load plan: %v\n", err)
		return 1
	}
	if errs := plan.Validate(p); len(errs) > 0 {
		fmt.Fprintln(out, "install plan validation failed:")
		for _, item := range errs {
			fmt.Fprintf(out, "- %s\n", item)
		}
		return 1
	}
	if dryRun {
		results := runner.DryRun(p)
		printRunResults(out, results)
		writeRunOutputs(out, p, policy.Decision{Allowed: true, Mode: "dry-run"}, results, "dry-run")
		return 0
	}
	decision := policy.Evaluate(p, policy.Options{Confirm: confirm})
	if !decision.Allowed {
		fmt.Fprintln(out, "plan execution refused by policy:")
		for _, reason := range decision.Reasons {
			fmt.Fprintf(out, "- %s\n", reason)
		}
		results := runner.Run(context.Background(), p, runner.Options{Confirm: confirm})
		printRunResults(out, results)
		writeRunOutputs(out, p, decision, results, "refused")
		return 1
	}
	results := runner.Run(context.Background(), p, runner.Options{Confirm: confirm})
	printRunResults(out, results)
	writeRunOutputs(out, p, decision, results, "execute")
	return 0
}

func simulatePlan(path string, out io.Writer) int {
	p, err := plan.Load(path)
	if err != nil {
		fmt.Fprintf(out, "failed to load plan: %v\n", err)
		return 1
	}
	errs := plan.Validate(p)
	if len(errs) > 0 {
		fmt.Fprintln(out, "install plan validation failed:")
		for _, item := range errs {
			fmt.Fprintf(out, "- %s\n", item)
		}
		return 1
	}
	decision := policy.Evaluate(p, policy.Options{DryRun: true})
	results := runner.DryRun(p)
	planReport := report.NewPlanReport(p, decision, results, report.SimulatedVerification(p.VerificationCommands), "simulate")
	reportPath, err := report.Write(outputDir("reports"), planReport)
	if err != nil {
		fmt.Fprintf(out, "failed to write report: %v\n", err)
		return 1
	}
	fmt.Fprintf(out, "simulation complete for plan: %s\n", p.ID)
	fmt.Fprintf(out, "report written: %s\n", reportPath)
	printRunResults(out, results)
	return 0
}

func writeRunOutputs(out io.Writer, p *plan.Plan, decision policy.Decision, results []runner.Result, mode string) {
	lines := []string{
		"ai-local-deploy v0.5.0 plan runner",
		"mode=" + mode,
		"plan=" + p.ID,
	}
	for _, result := range results {
		lines = append(lines, fmt.Sprintf("%s %s %s", result.ID, result.Status, result.Command))
	}
	logPath, err := logutil.CreateLog(outputDir("logs"), lines)
	if err != nil {
		fmt.Fprintf(out, "failed to write log: %v\n", err)
		return
	}
	planReport := report.NewPlanReport(p, decision, results, report.SimulatedVerification(p.VerificationCommands), mode)
	reportPath, err := report.Write(outputDir("reports"), planReport)
	if err != nil {
		fmt.Fprintf(out, "failed to write report: %v\n", err)
		return
	}
	fmt.Fprintf(out, "log written: %s\n", logPath)
	fmt.Fprintf(out, "report written: %s\n", reportPath)
}

func outputDir(name string) string {
	root, err := findRepoRoot()
	if err != nil {
		return name
	}
	return filepath.Join(root, name)
}

func findRepoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(wd, "core", "schema", "install-plan.schema.json")); err == nil {
			return wd, nil
		}
		parent := filepath.Dir(wd)
		if parent == wd {
			return "", fmt.Errorf("repository root not found")
		}
		wd = parent
	}
}

func runDoctor(out io.Writer) int {
	doctor := detect.Doctor()
	fmt.Fprintf(out, "ai-local-deploy doctor: platform=%s/%s user=%s elevated=%v\n", doctor.Platform.OS, doctor.Platform.Arch, doctor.Platform.User, doctor.Platform.IsElevated)
	for _, tool := range doctor.Tools {
		status := "missing"
		if tool.Detected {
			status = "detected"
		}
		fmt.Fprintf(out, "- %s: %s", tool.Name, status)
		if tool.Detail != "" {
			fmt.Fprintf(out, " (%s)", tool.Detail)
		}
		fmt.Fprintln(out)
	}
	fmt.Fprintln(out, "doctor is check-only; no repair or install actions were run.")
	return 0
}

func requireFile(args []string) (string, error) {
	for i := 0; i < len(args)-1; i++ {
		if args[i] == "--file" {
			if strings.TrimSpace(args[i+1]) == "" {
				return "", fmt.Errorf("--file requires a path")
			}
			return args[i+1], nil
		}
	}
	return "", fmt.Errorf("--file <path> is required")
}

func hasFlag(args []string, flag string) bool {
	for _, arg := range args {
		if arg == flag {
			return true
		}
	}
	return false
}

func printPlanSummary(out io.Writer, p *plan.Plan) {
	fmt.Fprintf(out, "Install plan: %s\n", p.ID)
	fmt.Fprintf(out, "Platform: %s\n", p.Platform)
	fmt.Fprintf(out, "Action: %s\n", p.Action)
	fmt.Fprintf(out, "Description: %s\n", p.Description)
	fmt.Fprintf(out, "Risk level: %s\n", p.RiskLevel)
	fmt.Fprintf(out, "Requires admin: %v\n", p.RequiresAdmin)
	fmt.Fprintf(out, "Confirmation required: %v\n", p.ConfirmationRequired)
	fmt.Fprintf(out, "Rollback available: %v\n", p.RollbackAvailable)
	fmt.Fprintln(out, "Commands:")
	printRunResults(out, runner.DryRun(p))
	fmt.Fprintln(out, "Verification commands:")
	for _, cmd := range p.VerificationCommands {
		fmt.Fprintf(out, "- %s\n", cmd)
	}
}

func printRunResults(out io.Writer, results []runner.Result) {
	for _, result := range results {
		fmt.Fprintf(out, "- id: %s\n", result.ID)
		fmt.Fprintf(out, "  description: %s\n", result.Description)
		fmt.Fprintf(out, "  riskLevel: %s\n", result.RiskLevel)
		fmt.Fprintf(out, "  requiresAdmin: %v\n", result.RequiresAdmin)
		fmt.Fprintf(out, "  workingDirectory: %s\n", result.WorkingDirectory)
		fmt.Fprintf(out, "  shell: %s\n", result.Shell)
		fmt.Fprintf(out, "  command: %s\n", result.Command)
		fmt.Fprintf(out, "  status: %s\n", result.Status)
		if result.Error != "" {
			fmt.Fprintf(out, "  error: %s\n", result.Error)
		}
		if result.Stdout != "" {
			fmt.Fprintf(out, "  stdout: %s\n", result.Stdout)
		}
		fmt.Fprintln(out, "  verificationCommands:")
		for _, verification := range result.Verification {
			fmt.Fprintf(out, "    - %s\n", verification)
		}
	}
}

func printExamplePlan(out io.Writer) {
	example := plan.Plan{
		ID:                   "example-check-only-plan",
		Platform:             "windows",
		Action:               "detect",
		Description:          "Example non-executing install plan. Use plan show, validate, run, or simulate with --file for v0.5.0.",
		RequiresAdmin:        false,
		RiskLevel:            "LOW",
		ConfirmationRequired: true,
		RollbackAvailable:    false,
		VerificationCommands: []string{"ai-local-deploy check"},
		AutoExecute:          false,
		Commands: []plan.Command{{
			ID:                   "example",
			Description:          "Print a placeholder",
			Shell:                "powershell",
			Command:              "Write-Output",
			Args:                 []string{"detection-only placeholder"},
			WorkingDirectory:     ".",
			RequiresAdmin:        false,
			RiskLevel:            "LOW",
			TimeoutSec:           5,
			DryRunOnly:           true,
			VerificationCommands: []string{"ai-local-deploy check"},
		}},
	}
	encoded, err := json.MarshalIndent(example, "", "  ")
	if err != nil {
		fmt.Fprintf(out, "failed to render plan: %v\n", err)
		return
	}
	fmt.Fprintln(out, string(encoded))
}

func printUsage(out io.Writer) {
	fmt.Fprintln(out, "Usage: ai-local-deploy <check|doctor|report|plan>")
	fmt.Fprintln(out, "Plan commands:")
	fmt.Fprintln(out, "  ai-local-deploy plan show --file <path>")
	fmt.Fprintln(out, "  ai-local-deploy plan validate --file <path>")
	fmt.Fprintln(out, "  ai-local-deploy plan run --file <path> --dry-run")
	fmt.Fprintln(out, "  ai-local-deploy plan run --file <path> --confirm")
	fmt.Fprintln(out, "  ai-local-deploy plan simulate --file <path>")
}
