package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestCheckCommandPrintsDetectionPlaceholder(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"check"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "will call existing detection scripts later") {
		t.Fatalf("expected detection placeholder, got %q", out.String())
	}
}

func TestDoctorCommandPrintsPlatform(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"doctor"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "platform=") {
		t.Fatalf("expected platform diagnostic, got %q", out.String())
	}
}

func TestReportCommandPrintsReportsDirectory(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"report"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	if !strings.Contains(out.String(), "reports") {
		t.Fatalf("expected reports directory output, got %q", out.String())
	}
}

func TestPlanCommandPrintsNonExecutingInstallPlanJSON(t *testing.T) {
	var out bytes.Buffer

	code := run([]string{"plan"}, &out)

	if code != 0 {
		t.Fatalf("expected exit code 0, got %d", code)
	}
	got := out.String()
	for _, want := range []string{`"confirmationRequired": true`, `"commands"`, `"riskLevel": "LOW"`} {
		if !strings.Contains(got, want) {
			t.Fatalf("expected %s in plan output, got %q", want, got)
		}
	}
}
