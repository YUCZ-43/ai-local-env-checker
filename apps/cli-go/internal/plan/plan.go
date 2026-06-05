package plan

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
)

type Plan struct {
	ID                   string    `json:"id"`
	Platform             string    `json:"platform"`
	Action               string    `json:"action"`
	Description          string    `json:"description"`
	Commands             []Command `json:"commands"`
	RequiresAdmin        bool      `json:"requiresAdmin"`
	RiskLevel            string    `json:"riskLevel"`
	ConfirmationRequired bool      `json:"confirmationRequired"`
	RollbackAvailable    bool      `json:"rollbackAvailable"`
	VerificationCommands []string  `json:"verificationCommands"`
	AutoExecute          bool      `json:"autoExecute"`
	DryRunOnly           bool      `json:"dryRunOnly"`
	Notes                []string  `json:"notes,omitempty"`
}

type Command struct {
	ID                    string   `json:"id"`
	Description           string   `json:"description"`
	Shell                 string   `json:"shell"`
	Command               string   `json:"command"`
	Args                  []string `json:"args"`
	WorkingDirectory      string   `json:"workingDirectory"`
	RequiresAdmin         bool     `json:"requiresAdmin"`
	RiskLevel             string   `json:"riskLevel"`
	TimeoutSec            int      `json:"timeoutSec"`
	DryRunOnly            bool     `json:"dryRunOnly"`
	VerificationCommands  []string `json:"verificationCommands"`
	ConfirmationRequired  bool     `json:"confirmationRequired"`
	OriginalCommandString string   `json:"-"`
}

type rawPlan struct {
	ID                   string            `json:"id"`
	Platform             string            `json:"platform"`
	Action               string            `json:"action"`
	Description          string            `json:"description"`
	Commands             []json.RawMessage `json:"commands"`
	RequiresAdmin        bool              `json:"requiresAdmin"`
	RiskLevel            string            `json:"riskLevel"`
	ConfirmationRequired bool              `json:"confirmationRequired"`
	RollbackAvailable    bool              `json:"rollbackAvailable"`
	VerificationCommands []string          `json:"verificationCommands"`
	AutoExecute          bool              `json:"autoExecute"`
	DryRunOnly           bool              `json:"dryRunOnly"`
	Notes                []string          `json:"notes,omitempty"`
}

func Load(path string) (*Plan, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("load install plan: %w", err)
	}
	var raw rawPlan
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("parse install plan JSON: %w", err)
	}
	p := &Plan{
		ID:                   raw.ID,
		Platform:             raw.Platform,
		Action:               raw.Action,
		Description:          raw.Description,
		RequiresAdmin:        raw.RequiresAdmin,
		RiskLevel:            normalizeRisk(raw.RiskLevel),
		ConfirmationRequired: raw.ConfirmationRequired,
		RollbackAvailable:    raw.RollbackAvailable,
		VerificationCommands: raw.VerificationCommands,
		AutoExecute:          raw.AutoExecute,
		DryRunOnly:           raw.DryRunOnly,
		Notes:                raw.Notes,
	}
	for i, item := range raw.Commands {
		cmd, err := parseCommand(i, item, p)
		if err != nil {
			return nil, err
		}
		p.Commands = append(p.Commands, cmd)
	}
	return p, nil
}

func Validate(p *Plan) []string {
	if p == nil {
		return []string{"plan is nil"}
	}
	var errs []string
	required := map[string]string{
		"id":          p.ID,
		"platform":    p.Platform,
		"action":      p.Action,
		"description": p.Description,
		"riskLevel":   p.RiskLevel,
	}
	for name, value := range required {
		if strings.TrimSpace(value) == "" {
			errs = append(errs, name+" is required")
		}
	}
	if len(p.Commands) == 0 {
		errs = append(errs, "commands must contain at least one command")
	}
	if len(p.VerificationCommands) == 0 {
		errs = append(errs, "verificationCommands must contain at least one command")
	}
	if !validRisk(p.RiskLevel) {
		errs = append(errs, "riskLevel must be LOW, MEDIUM, HIGH, or DANGEROUS")
	}
	for i, cmd := range p.Commands {
		if strings.TrimSpace(cmd.ID) == "" {
			errs = append(errs, fmt.Sprintf("commands[%d].id is required", i))
		}
		if strings.TrimSpace(cmd.Command) == "" {
			errs = append(errs, fmt.Sprintf("commands[%d].command is required", i))
		}
		if !validRisk(cmd.RiskLevel) {
			errs = append(errs, fmt.Sprintf("commands[%d].riskLevel must be LOW, MEDIUM, HIGH, or DANGEROUS", i))
		}
	}
	return errs
}

func parseCommand(index int, item json.RawMessage, p *Plan) (Command, error) {
	var legacy string
	if err := json.Unmarshal(item, &legacy); err == nil {
		text := strings.TrimSpace(legacy)
		if text == "" {
			return Command{}, errors.New("legacy command string cannot be empty")
		}
		return normalizeCommand(index, Command{
			ID:                    fmt.Sprintf("command-%d", index+1),
			Description:           text,
			Command:               text,
			Shell:                 "powershell",
			RiskLevel:             p.RiskLevel,
			RequiresAdmin:         p.RequiresAdmin,
			DryRunOnly:            p.DryRunOnly,
			VerificationCommands:  p.VerificationCommands,
			OriginalCommandString: text,
		}, p), nil
	}
	var cmd Command
	if err := json.Unmarshal(item, &cmd); err != nil {
		return Command{}, fmt.Errorf("parse commands[%d]: %w", index, err)
	}
	return normalizeCommand(index, cmd, p), nil
}

func normalizeCommand(index int, cmd Command, p *Plan) Command {
	if strings.TrimSpace(cmd.ID) == "" {
		cmd.ID = fmt.Sprintf("command-%d", index+1)
	}
	if strings.TrimSpace(cmd.RiskLevel) == "" {
		cmd.RiskLevel = p.RiskLevel
	}
	cmd.RiskLevel = normalizeRisk(cmd.RiskLevel)
	if strings.TrimSpace(cmd.Shell) == "" {
		cmd.Shell = "powershell"
	}
	if strings.TrimSpace(cmd.WorkingDirectory) == "" {
		cmd.WorkingDirectory = "."
	}
	if cmd.TimeoutSec <= 0 {
		cmd.TimeoutSec = 30
	}
	if len(cmd.VerificationCommands) == 0 {
		cmd.VerificationCommands = p.VerificationCommands
	}
	return cmd
}

func validRisk(risk string) bool {
	switch normalizeRisk(risk) {
	case "LOW", "MEDIUM", "HIGH", "DANGEROUS":
		return true
	default:
		return false
	}
}

func normalizeRisk(risk string) string {
	return strings.ToUpper(strings.TrimSpace(risk))
}
