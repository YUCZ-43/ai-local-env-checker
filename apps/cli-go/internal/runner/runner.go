package runner

import (
	"context"
	"fmt"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"github.com/ai-local-env-checker/ai-local-deploy/internal/plan"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/platform"
	"github.com/ai-local-env-checker/ai-local-deploy/internal/policy"
)

type Options struct {
	DryRun  bool
	Confirm bool
}

type Result struct {
	ID               string   `json:"id"`
	Description      string   `json:"description"`
	Command          string   `json:"command"`
	Args             []string `json:"args,omitempty"`
	Shell            string   `json:"shell"`
	WorkingDirectory string   `json:"workingDirectory"`
	RiskLevel        string   `json:"riskLevel"`
	RequiresAdmin    bool     `json:"requiresAdmin"`
	Status           string   `json:"status"`
	Stdout           string   `json:"stdout,omitempty"`
	Stderr           string   `json:"stderr,omitempty"`
	ExitCode         int      `json:"exitCode"`
	Error            string   `json:"error,omitempty"`
	ElapsedMs        int64    `json:"elapsedMs"`
	Verification     []string `json:"verificationCommands,omitempty"`
}

func DryRun(p *plan.Plan) []Result {
	results := make([]Result, 0, len(p.Commands))
	for _, cmd := range p.Commands {
		result := baseResult(cmd)
		result.Status = "DRY_RUN"
		results = append(results, result)
	}
	return results
}

func Run(ctx context.Context, p *plan.Plan, opts Options) []Result {
	if opts.DryRun {
		return DryRun(p)
	}
	decision := policy.Evaluate(p, policy.Options{
		Confirm:  opts.Confirm,
		Elevated: platform.IsElevated(),
	})
	if !decision.Allowed {
		return refusedResults(p, strings.Join(decision.Reasons, "; "))
	}
	results := make([]Result, 0, len(p.Commands))
	for _, cmd := range p.Commands {
		results = append(results, runCommand(ctx, cmd, opts))
	}
	return results
}

func runCommand(ctx context.Context, cmd plan.Command, opts Options) Result {
	result := baseResult(cmd)
	if !opts.Confirm {
		result.Status = "REFUSED"
		result.Error = "confirmation is required before execution"
		return result
	}
	if cmd.DryRunOnly {
		result.Status = "REFUSED"
		result.Error = "command is marked dryRunOnly"
		return result
	}
	if cmd.RequiresAdmin && !platform.IsElevated() {
		result.Status = "REFUSED"
		result.Error = "administrator elevation is required; no auto-elevation is performed in v0.8.0"
		return result
	}
	if !isLowRisk(cmd.RiskLevel) {
		result.Status = "REFUSED"
		result.Error = "only LOW risk commands may execute in v0.8.0"
		return result
	}
	if !IsAllowedSafeCommand(cmd) {
		result.Status = "REFUSED"
		result.Error = "command is not in the v0.8.0 safe demo allowlist"
		return result
	}
	timeout := time.Duration(cmd.TimeoutSec) * time.Second
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	runCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	start := time.Now()
	execCmd := buildExecCommand(runCtx, cmd)
	execCmd.Dir = cmd.WorkingDirectory
	out, err := execCmd.CombinedOutput()
	result.ElapsedMs = time.Since(start).Milliseconds()
	result.Stdout = strings.TrimSpace(string(out))
	if err != nil {
		result.Status = "FAILED"
		result.Error = err.Error()
		if exitErr, ok := err.(*exec.ExitError); ok {
			result.ExitCode = exitErr.ExitCode()
		} else {
			result.ExitCode = 1
		}
		return result
	}
	result.Status = "SUCCEEDED"
	return result
}

func IsAllowedSafeCommand(cmd plan.Command) bool {
	name := strings.ToLower(strings.TrimSpace(cmd.Command))
	if strings.Contains(name, "install") || strings.Contains(name, "setx") || strings.Contains(name, "remove-") || strings.Contains(name, "start-process") {
		return false
	}
	switch name {
	case "write-output", "whoami", "$psversiontable.psversion", "git":
		if name == "git" {
			return len(cmd.Args) == 1 && cmd.Args[0] == "--version"
		}
		return true
	default:
		return false
	}
}

func buildExecCommand(ctx context.Context, cmd plan.Command) *exec.Cmd {
	name := strings.ToLower(strings.TrimSpace(cmd.Command))
	if name == "write-output" || name == "$psversiontable.psversion" {
		ps := "powershell"
		if runtime.GOOS != "windows" {
			ps = "pwsh"
		}
		command := cmd.Command
		if len(cmd.Args) > 0 {
			command = command + " " + strings.Join(quotePowerShellArgs(cmd.Args), " ")
		}
		return exec.CommandContext(ctx, ps, "-NoProfile", "-Command", command)
	}
	return exec.CommandContext(ctx, cmd.Command, cmd.Args...)
}

func quotePowerShellArgs(args []string) []string {
	quoted := make([]string, len(args))
	for i, arg := range args {
		quoted[i] = "'" + strings.ReplaceAll(arg, "'", "''") + "'"
	}
	return quoted
}

func refusedResults(p *plan.Plan, reason string) []Result {
	if p == nil || len(p.Commands) == 0 {
		return []Result{{Status: "REFUSED", Error: reason}}
	}
	results := make([]Result, 0, len(p.Commands))
	for _, cmd := range p.Commands {
		result := baseResult(cmd)
		result.Status = "REFUSED"
		result.Error = reason
		results = append(results, result)
	}
	return results
}

func baseResult(cmd plan.Command) Result {
	command := cmd.Command
	if len(cmd.Args) > 0 {
		command = fmt.Sprintf("%s %s", command, strings.Join(cmd.Args, " "))
	}
	return Result{
		ID:               cmd.ID,
		Description:      cmd.Description,
		Command:          command,
		Args:             cmd.Args,
		Shell:            cmd.Shell,
		WorkingDirectory: cmd.WorkingDirectory,
		RiskLevel:        cmd.RiskLevel,
		RequiresAdmin:    cmd.RequiresAdmin,
		ExitCode:         0,
		Verification:     cmd.VerificationCommands,
	}
}

func isLowRisk(risk string) bool {
	return strings.EqualFold(strings.TrimSpace(risk), "LOW")
}
