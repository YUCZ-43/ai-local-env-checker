import { describe, expect, it } from "vitest";
import {
  assertSafePreviewPlan,
  buildApprovalSummary,
  buildPlanSummary,
  getControlledExecutionState,
  parseInstallPlan,
} from "./planClient";

const safePlanJson = JSON.stringify({
  id: "safe-demo",
  platform: "windows",
  action: "detect",
  description: "Safe preview plan",
  riskLevel: "LOW",
  requiresAdmin: false,
  confirmationRequired: true,
  rollbackAvailable: false,
  verificationCommands: ["ai-local-deploy doctor"],
  autoExecute: false,
  dryRunOnly: true,
  commands: [
    {
      id: "check-node",
      description: "Check Node.js",
      shell: "powershell",
      command: "node",
      args: ["--version"],
      workingDirectory: ".",
      riskLevel: "LOW",
      requiresAdmin: false,
      dryRunOnly: true,
      timeoutSec: 10,
      verificationCommands: ["node --version"],
    },
  ],
});

describe("planClient", () => {
  it("parses an install plan and builds a GUI summary", () => {
    const plan = parseInstallPlan(safePlanJson);
    const summary = buildPlanSummary(plan);

    expect(summary.id).toBe("safe-demo");
    expect(summary.commandCount).toBe(1);
    expect(summary.riskLevel).toBe("LOW");
    expect(summary.requiresAdmin).toBe(false);
    expect(summary.confirmationRequired).toBe(true);
    expect(summary.blockedInGui).toBe(false);
  });

  it("blocks admin plans in safe preview mode", () => {
    const plan = parseInstallPlan(
      safePlanJson.replace('"requiresAdmin":false', '"requiresAdmin":true'),
    );

    expect(() => assertSafePreviewPlan(plan)).toThrow(/requires admin/i);
  });

  it("blocks medium and higher risk plans in safe preview mode", () => {
    const plan = parseInstallPlan(safePlanJson.replace('"LOW"', '"MEDIUM"'));

    expect(() => assertSafePreviewPlan(plan)).toThrow(/risk level MEDIUM/i);
  });

  it("requires explicit confirmation before controlled LOW-risk execution", () => {
    const plan = parseInstallPlan(safePlanJson.replaceAll('"dryRunOnly":true', '"dryRunOnly":false'));

    expect(getControlledExecutionState(plan, false)).toMatchObject({
      dryRunDefault: true,
      confirmedExecutionAllowed: false,
    });
    expect(getControlledExecutionState(plan, true)).toMatchObject({
      dryRunDefault: true,
      confirmedExecutionAllowed: true,
    });
  });

  it("keeps admin and medium-risk plans blocked even after confirmation", () => {
    const plan = parseInstallPlan(safePlanJson.replace('"LOW"', '"ADMIN_REQUIRED"'));

    expect(getControlledExecutionState(plan, true).confirmedExecutionAllowed).toBe(false);
  });

  it("builds the v0.9.0 approval summary with real run disabled by default", () => {
    const plan = parseInstallPlan(
      safePlanJson
        .replace('"requiresAdmin":false', '"requiresAdmin":true')
        .replace('"rollbackAvailable":false', '"rollbackAvailable":true'),
    );

    const approval = buildApprovalSummary(plan);

    expect(approval.realRunDisabled).toBe(true);
    expect(approval.dryRunDefault).toBe(true);
    expect(approval.requiresAdmin).toBe(true);
    expect(approval.adminState).toBe("blocked");
    expect(approval.commandApprovals[0]).toMatchObject({
      id: "check-node",
      approvalRequired: true,
      approvalState: "blocked",
      uiSeverity: "danger",
    });
    expect(approval.rollbackAvailable).toBe(true);
  });

  it("keeps low risk preview commands allowed for dry-run approval review", () => {
    const plan = parseInstallPlan(safePlanJson);

    const approval = buildApprovalSummary(plan);

    expect(approval.commandApprovals[0]).toMatchObject({
      approvalRequired: true,
      approvalState: "preview-only",
      uiSeverity: "success",
    });
  });
});
