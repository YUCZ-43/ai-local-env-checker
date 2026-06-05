package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/audit"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/catalog"
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
	case "tools":
		return runTools(args[1:], out)
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

func runTools(args []string, out io.Writer) int {
	if len(args) == 0 {
		printToolsUsage(out)
		return 2
	}
	tools, err := catalog.LoadAll(toolCatalogDir())
	if err != nil {
		fmt.Fprintf(out, "failed to load tool catalog: %v\n", err)
		return 1
	}

	switch args[0] {
	case "list":
		for _, tool := range tools {
			fmt.Fprintf(out, "%s\t%s\t%s\t%s\n", tool.ID, tool.DisplayName, tool.Category, tool.Status)
		}
	case "show":
		id, err := requireID(args[1:])
		if err != nil {
			fmt.Fprintln(out, err)
			return 2
		}
		tool, ok := catalog.Find(tools, id)
		if !ok {
			fmt.Fprintf(out, "tool not found: %s\n", id)
			return 1
		}
		printTool(out, tool)
	case "validate":
		if errs := catalog.ValidateAll(tools); len(errs) > 0 {
			fmt.Fprintln(out, "tool catalog validation failed:")
			for _, item := range errs {
				fmt.Fprintf(out, "- %s\n", item)
			}
			return 1
		}
		fmt.Fprintf(out, "tool catalog is valid: %d tools\n", len(tools))
	case "detect":
		if !hasFlag(args[1:], "--dry-run") {
			fmt.Fprintln(out, "tools detect requires --dry-run")
			return 2
		}
		fmt.Fprintln(out, "tool detection preview; commands are not executed:")
		for _, tool := range tools {
			fmt.Fprintf(out, "%s (%s)\n", tool.ID, tool.DisplayName)
			for _, cmd := range tool.DetectionCommands {
				fmt.Fprintf(out, "- [%s/%s] %s\n", cmd.Platform, cmd.Shell, catalog.CommandLine(cmd))
			}
		}
	case "plan":
		if !hasFlag(args[1:], "--dry-run") {
			fmt.Fprintln(out, "tools plan requires --dry-run")
			return 2
		}
		id, err := requireID(args[1:])
		if err != nil {
			fmt.Fprintln(out, err)
			return 2
		}
		tool, ok := catalog.Find(tools, id)
		if !ok {
			fmt.Fprintf(out, "tool not found: %s\n", id)
			return 1
		}
		printToolPlanPreview(out, tool)
	default:
		fmt.Fprintf(out, "unknown tools command: %s\n", args[0])
		printToolsUsage(out)
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
		writeRunOutputs(out, path, p, policy.Decision{Allowed: true, Mode: "dry-run"}, results, "dry-run")
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
		writeRunOutputs(out, path, p, decision, results, "refused")
		return 1
	}
	results := runner.Run(context.Background(), p, runner.Options{Confirm: confirm})
	printRunResults(out, results)
	writeRunOutputs(out, path, p, decision, results, "execute")
	if hasFailedResults(results) {
		return 1
	}
	return 0
}

func hasFailedResults(results []runner.Result) bool {
	for _, result := range results {
		if result.Status == "FAILED" {
			return true
		}
	}
	return false
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
	auditPath, err := writeAuditRecords(path, p, results, "simulate", reportPath)
	if err != nil {
		fmt.Fprintf(out, "failed to write audit log: %v\n", err)
		return 1
	}
	fmt.Fprintf(out, "simulation complete for plan: %s\n", p.ID)
	fmt.Fprintf(out, "audit log written: %s\n", auditPath)
	fmt.Fprintf(out, "report written: %s\n", reportPath)
	printRunResults(out, results)
	return 0
}

func writeRunOutputs(out io.Writer, planFile string, p *plan.Plan, decision policy.Decision, results []runner.Result, mode string) {
	lines := []string{
		"ai-local-deploy v0.8.0 controlled runner",
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
	auditPath, err := writeAuditRecords(planFile, p, results, mode, reportPath)
	if err != nil {
		fmt.Fprintf(out, "failed to write audit log: %v\n", err)
		return
	}
	fmt.Fprintf(out, "log written: %s\n", logPath)
	fmt.Fprintf(out, "audit log written: %s\n", auditPath)
	fmt.Fprintf(out, "report written: %s\n", reportPath)
}

func writeAuditRecords(planFile string, p *plan.Plan, results []runner.Result, mode string, reportPath string) (string, error) {
	records := make([]audit.Record, 0, len(results))
	toolID := ""
	if p != nil {
		toolID = p.ToolID
		if toolID == "" {
			toolID = p.ID
		}
	}
	for _, result := range results {
		records = append(records, audit.Record{
			Platform:       runtime.GOOS + "/" + runtime.GOARCH,
			ToolID:         toolID,
			PlanFile:       planFile,
			CommandPreview: result.Command,
			Mode:           mode,
			RiskLevel:      result.RiskLevel,
			Allowed:        result.Status == "SUCCEEDED" || result.Status == "DRY_RUN",
			Reason:         auditReason(result),
			ExitCode:       result.ExitCode,
			StdoutSummary:  safeSummary(result.Stdout),
			StderrSummary:  safeSummary(result.Stderr),
			ReportPath:     reportPath,
		})
	}
	return audit.Write(outputDir("logs"), records)
}

func auditReason(result runner.Result) string {
	if result.Error != "" {
		return result.Error
	}
	switch result.Status {
	case "DRY_RUN":
		return "dry-run preview; command was not executed"
	case "SUCCEEDED":
		return "allowlisted LOW-risk command executed after explicit confirmation"
	default:
		return result.Status
	}
}

func safeSummary(value string) string {
	value = strings.TrimSpace(value)
	if len(value) > 500 {
		return value[:500] + "...(truncated)"
	}
	return value
}

func outputDir(name string) string {
	if root := configuredOutputRoot(); root != "" {
		return filepath.Join(root, name)
	}
	root, err := findRepoRoot()
	if err != nil {
		return name
	}
	return filepath.Join(root, name)
}

func findRepoRoot() (string, error) {
	if root := configuredContentRoot(); root != "" {
		return root, nil
	}
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

func configuredContentRoot() string {
	root := strings.TrimSpace(os.Getenv("AI_LOCAL_DEPLOY_CONTENT_ROOT"))
	if root == "" {
		return ""
	}
	if _, err := os.Stat(filepath.Join(root, "core", "schema", "install-plan.schema.json")); err == nil {
		return root
	}
	return ""
}

func configuredOutputRoot() string {
	return strings.TrimSpace(os.Getenv("AI_LOCAL_DEPLOY_OUTPUT_ROOT"))
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

func requireID(args []string) (string, error) {
	for i := 0; i < len(args)-1; i++ {
		if args[i] == "--id" {
			if strings.TrimSpace(args[i+1]) == "" {
				return "", fmt.Errorf("--id requires a value")
			}
			return args[i+1], nil
		}
	}
	return "", fmt.Errorf("--id <tool-id> is required")
}

func hasFlag(args []string, flag string) bool {
	for _, arg := range args {
		if arg == flag {
			return true
		}
	}
	return false
}

func toolCatalogDir() string {
	root, err := findRepoRoot()
	if err != nil {
		return filepath.Join("core", "tool-catalog")
	}
	return filepath.Join(root, "core", "tool-catalog")
}

func printTool(out io.Writer, tool catalog.Tool) {
	fmt.Fprintf(out, "Tool: %s\n", tool.DisplayName)
	fmt.Fprintf(out, "ID: %s\n", tool.ID)
	fmt.Fprintf(out, "Category: %s\n", tool.Category)
	fmt.Fprintf(out, "Status: %s\n", tool.Status)
	fmt.Fprintf(out, "Risk level: %s\n", tool.RiskLevel)
	fmt.Fprintf(out, "Requires admin: %v\n", tool.RequiresAdmin)
	fmt.Fprintf(out, "Recommended install mode: %s\n", tool.RecommendedInstallMode)
	fmt.Fprintf(out, "Platforms: %s\n", strings.Join(tool.SupportedPlatforms, ", "))
	fmt.Fprintf(out, "Description: %s\n", tool.Description)
	fmt.Fprintln(out, "Detection commands:")
	for _, cmd := range tool.DetectionCommands {
		fmt.Fprintf(out, "- [%s/%s] %s\n", cmd.Platform, cmd.Shell, catalog.CommandLine(cmd))
	}
	fmt.Fprintln(out, "Install plan templates:")
	for _, template := range tool.InstallPlanTemplates {
		fmt.Fprintf(out, "- %s %s dryRunOnly=%v riskLevel=%s\n", template.ID, template.Path, template.DryRunOnly, template.RiskLevel)
	}
}

func printToolPlanPreview(out io.Writer, tool catalog.Tool) {
	if len(tool.InstallPlanTemplates) == 0 {
		fmt.Fprintf(out, "tool has no dry-run plan template: %s\n", tool.ID)
		return
	}
	fmt.Fprintf(out, "dry-run plan template preview for %s (%s)\n", tool.ID, tool.DisplayName)
	for _, template := range tool.InstallPlanTemplates {
		fmt.Fprintf(out, "- template: %s\n", template.ID)
		fmt.Fprintf(out, "  path: %s\n", template.Path)
		fmt.Fprintf(out, "  dryRunOnly: %v\n", template.DryRunOnly)
		fmt.Fprintf(out, "  riskLevel: %s\n", template.RiskLevel)
		path := template.Path
		if root, err := findRepoRoot(); err == nil {
			path = filepath.Join(root, filepath.FromSlash(template.Path))
		}
		p, err := plan.Load(path)
		if err != nil {
			fmt.Fprintf(out, "  loadError: %v\n", err)
			continue
		}
		fmt.Fprintf(out, "  planID: %s\n", p.ID)
		fmt.Fprintf(out, "  commandCount: %d\n", len(p.Commands))
		fmt.Fprintf(out, "  requiresAdmin: %v\n", p.RequiresAdmin)
	}
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
	fmt.Fprintln(out, "Usage: ai-local-deploy <check|doctor|report|plan|tools>")
	fmt.Fprintln(out, "Plan commands:")
	fmt.Fprintln(out, "  ai-local-deploy plan show --file <path>")
	fmt.Fprintln(out, "  ai-local-deploy plan validate --file <path>")
	fmt.Fprintln(out, "  ai-local-deploy plan run --file <path> --dry-run")
	fmt.Fprintln(out, "  ai-local-deploy plan run --file <path> --confirm")
	fmt.Fprintln(out, "  ai-local-deploy plan simulate --file <path>")
	printToolsUsage(out)
}

func printToolsUsage(out io.Writer) {
	fmt.Fprintln(out, "Tool catalog commands:")
	fmt.Fprintln(out, "  ai-local-deploy tools list")
	fmt.Fprintln(out, "  ai-local-deploy tools show --id <tool-id>")
	fmt.Fprintln(out, "  ai-local-deploy tools validate")
	fmt.Fprintln(out, "  ai-local-deploy tools detect --dry-run")
	fmt.Fprintln(out, "  ai-local-deploy tools plan --id <tool-id> --dry-run")
}
