package catalog

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type Tool struct {
	ID                     string         `json:"id"`
	DisplayName            string         `json:"displayName"`
	Category               string         `json:"category"`
	Description            string         `json:"description"`
	SupportedPlatforms     []string       `json:"supportedPlatforms"`
	RecommendedInstallMode string         `json:"recommendedInstallMode"`
	DetectionCommands      []Command      `json:"detectionCommands"`
	InstallPlanTemplates   []PlanTemplate `json:"installPlanTemplates"`
	VerificationCommands   []Command      `json:"verificationCommands"`
	RequiresAdmin          bool           `json:"requiresAdmin"`
	RiskLevel              string         `json:"riskLevel"`
	NetworkRequirements    []string       `json:"networkRequirements"`
	ProxyRequirements      []string       `json:"proxyRequirements"`
	SecurityWarnings       []string       `json:"securityWarnings"`
	Notes                  []string       `json:"notes"`
	Docs                   []DocLink      `json:"docs"`
	Status                 string         `json:"status"`
	SourcePath             string         `json:"-"`
}

type Command struct {
	Platform      string   `json:"platform"`
	Shell         string   `json:"shell"`
	Command       string   `json:"command"`
	Args          []string `json:"args,omitempty"`
	RiskLevel     string   `json:"riskLevel"`
	RequiresAdmin bool     `json:"requiresAdmin,omitempty"`
	DryRunOnly    bool     `json:"dryRunOnly,omitempty"`
	Description   string   `json:"description,omitempty"`
}

type PlanTemplate struct {
	ID          string `json:"id"`
	Path        string `json:"path"`
	DryRunOnly  bool   `json:"dryRunOnly"`
	RiskLevel   string `json:"riskLevel"`
	Description string `json:"description,omitempty"`
}

type DocLink struct {
	Label string `json:"label"`
	Path  string `json:"path"`
}

func LoadAll(dir string) ([]Tool, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read tool catalog: %w", err)
	}
	var tools []Tool
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".tool.json") {
			continue
		}
		path := filepath.Join(dir, entry.Name())
		tool, err := Load(path)
		if err != nil {
			return nil, err
		}
		tools = append(tools, tool)
	}
	sort.Slice(tools, func(i, j int) bool { return tools[i].ID < tools[j].ID })
	return tools, nil
}

func Load(path string) (Tool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Tool{}, fmt.Errorf("load tool manifest %s: %w", path, err)
	}
	var tool Tool
	if err := json.Unmarshal(data, &tool); err != nil {
		return Tool{}, fmt.Errorf("parse tool manifest %s: %w", path, err)
	}
	tool.RiskLevel = normalizeRisk(tool.RiskLevel)
	for i := range tool.DetectionCommands {
		tool.DetectionCommands[i].RiskLevel = normalizeRisk(tool.DetectionCommands[i].RiskLevel)
	}
	for i := range tool.VerificationCommands {
		tool.VerificationCommands[i].RiskLevel = normalizeRisk(tool.VerificationCommands[i].RiskLevel)
	}
	for i := range tool.InstallPlanTemplates {
		tool.InstallPlanTemplates[i].RiskLevel = normalizeRisk(tool.InstallPlanTemplates[i].RiskLevel)
	}
	tool.SourcePath = path
	return tool, nil
}

func Find(tools []Tool, id string) (Tool, bool) {
	for _, tool := range tools {
		if tool.ID == id {
			return tool, true
		}
	}
	return Tool{}, false
}

func Validate(tool Tool) []string {
	var errs []string
	required := map[string]string{
		"id":                     tool.ID,
		"displayName":            tool.DisplayName,
		"category":               tool.Category,
		"description":            tool.Description,
		"recommendedInstallMode": tool.RecommendedInstallMode,
		"riskLevel":              tool.RiskLevel,
		"status":                 tool.Status,
	}
	for name, value := range required {
		if strings.TrimSpace(value) == "" {
			errs = append(errs, name+" is required")
		}
	}
	if len(tool.SupportedPlatforms) == 0 {
		errs = append(errs, "supportedPlatforms must contain at least one platform")
	}
	if len(tool.DetectionCommands) == 0 {
		errs = append(errs, "detectionCommands must contain at least one command")
	}
	if len(tool.VerificationCommands) == 0 {
		errs = append(errs, "verificationCommands must contain at least one command")
	}
	if !validRisk(tool.RiskLevel) {
		errs = append(errs, "riskLevel must be LOW, MEDIUM, HIGH, or DANGEROUS")
	}
	for _, template := range tool.InstallPlanTemplates {
		if !template.DryRunOnly {
			errs = append(errs, "installPlanTemplates must be dry-run-only")
		}
		if !validRisk(template.RiskLevel) {
			errs = append(errs, "installPlanTemplates riskLevel must be LOW, MEDIUM, HIGH, or DANGEROUS")
		}
	}
	if tool.Category == "agent-tool" && len(tool.SecurityWarnings) == 0 {
		errs = append(errs, "agent tools must include supply-chain security warnings")
	}
	if len(tool.InstallPlanTemplates) > 0 && tool.RiskLevel == "LOW" {
		errs = append(errs, "tools with install plan templates must be MEDIUM risk or higher")
	}
	return errs
}

func ValidateAll(tools []Tool) []string {
	var errs []string
	seen := map[string]bool{}
	for _, tool := range tools {
		if seen[tool.ID] {
			errs = append(errs, "duplicate tool id: "+tool.ID)
		}
		seen[tool.ID] = true
		for _, err := range Validate(tool) {
			errs = append(errs, tool.ID+": "+err)
		}
	}
	return errs
}

func CommandLine(cmd Command) string {
	if len(cmd.Args) == 0 {
		return cmd.Command
	}
	return cmd.Command + " " + strings.Join(cmd.Args, " ")
}

func normalizeRisk(risk string) string {
	return strings.ToUpper(strings.TrimSpace(risk))
}

func validRisk(risk string) bool {
	switch normalizeRisk(risk) {
	case "LOW", "MEDIUM", "HIGH", "DANGEROUS":
		return true
	default:
		return false
	}
}
