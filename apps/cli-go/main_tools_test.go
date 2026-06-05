package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestToolsListShowValidateAndDryRun(t *testing.T) {
	tests := []struct {
		name string
		args []string
		want string
	}{
		{name: "list", args: []string{"tools", "list"}, want: "claude-code"},
		{name: "show", args: []string{"tools", "show", "--id", "claude-code"}, want: "Claude Code"},
		{name: "validate", args: []string{"tools", "validate"}, want: "tool catalog is valid"},
		{name: "detect dry-run", args: []string{"tools", "detect", "--dry-run"}, want: "detection preview"},
		{name: "plan dry-run", args: []string{"tools", "plan", "--id", "claude-code", "--dry-run"}, want: "dry-run plan template"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var out bytes.Buffer
			code := run(tt.args, &out)
			if code != 0 {
				t.Fatalf("run returned %d, output:\n%s", code, out.String())
			}
			if !strings.Contains(out.String(), tt.want) {
				t.Fatalf("expected output to contain %q, got:\n%s", tt.want, out.String())
			}
		})
	}
}
