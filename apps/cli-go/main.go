package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
)

type installPlan struct {
	ID                    string   `json:"id"`
	Platform              string   `json:"platform"`
	Action                string   `json:"action"`
	Description           string   `json:"description"`
	Commands              []string `json:"commands"`
	RequiresAdmin         bool     `json:"requiresAdmin"`
	RiskLevel             string   `json:"riskLevel"`
	ConfirmationRequired  bool     `json:"confirmationRequired"`
	RollbackAvailable     bool     `json:"rollbackAvailable"`
	VerificationCommands  []string `json:"verificationCommands"`
	AutoExecute           bool     `json:"autoExecute"`
}

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
		fmt.Fprintf(out, "ai-local-deploy doctor: platform=%s/%s\n", runtime.GOOS, runtime.GOARCH)
		fmt.Fprintln(out, "basic diagnostic placeholder: CLI skeleton is available; detection engine integration is pending.")
	case "report":
		fmt.Fprintf(out, "ai-local-deploy report: expected reports directory: %s\n", filepath.Join(".", "reports"))
	case "plan":
		plan := installPlan{
			ID:                   "example-check-only-plan",
			Platform:             runtime.GOOS,
			Action:               "detect",
			Description:          "Example non-executing install plan. Future versions will generate plans before any repair or install action.",
			Commands:             []string{"echo detection-only placeholder"},
			RequiresAdmin:        false,
			RiskLevel:            "LOW",
			ConfirmationRequired: true,
			RollbackAvailable:    false,
			VerificationCommands: []string{"ai-local-deploy check"},
			AutoExecute:          false,
		}
		encoded, err := json.MarshalIndent(plan, "", "  ")
		if err != nil {
			fmt.Fprintf(out, "failed to render plan: %v\n", err)
			return 1
		}
		fmt.Fprintln(out, string(encoded))
	default:
		fmt.Fprintf(out, "unknown command: %s\n", args[0])
		printUsage(out)
		return 2
	}

	return 0
}

func printUsage(out io.Writer) {
	fmt.Fprintln(out, "Usage: ai-local-deploy <check|doctor|report|plan>")
}
