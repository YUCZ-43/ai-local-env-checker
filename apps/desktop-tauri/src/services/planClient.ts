export type RiskLevel = "LOW" | "MEDIUM" | "HIGH" | "ADMIN_REQUIRED" | "DANGEROUS";

export interface InstallCommand {
  id: string;
  description?: string;
  shell?: string;
  command: string;
  args?: string[];
  workingDirectory?: string;
  requiresAdmin?: boolean;
  riskLevel?: RiskLevel | string;
  timeoutSec?: number;
  dryRunOnly?: boolean;
  confirmationRequired?: boolean;
  verificationCommands?: string[];
  expectedResult?: string;
  rollbackNote?: string;
}

export interface InstallPlan {
  id: string;
  toolId?: string;
  platform: string;
  action: string;
  description: string;
  commands: InstallCommand[];
  requiresAdmin: boolean;
  riskLevel: RiskLevel | string;
  confirmationRequired: boolean;
  rollbackAvailable?: boolean;
  verificationCommands: string[];
  autoExecute?: boolean;
  dryRunOnly?: boolean;
  expectedResult?: string;
  rollbackNote?: string;
  notes?: string[];
}

export interface PlanSummary {
  id: string;
  platform: string;
  action: string;
  description: string;
  commandCount: number;
  riskLevel: string;
  requiresAdmin: boolean;
  confirmationRequired: boolean;
  blockedInGui: boolean;
  blockReasons: string[];
}

export interface ControlledExecutionState {
  dryRunDefault: boolean;
  confirmationChecked: boolean;
  confirmedExecutionAllowed: boolean;
  disabledReason: string;
}

const blockedRiskLevels = new Set(["MEDIUM", "HIGH", "ADMIN_REQUIRED", "DANGEROUS"]);

export function normalizeRiskLevel(riskLevel: string | undefined): string {
  return (riskLevel ?? "").trim().toUpperCase();
}

export function parseInstallPlan(rawJson: string): InstallPlan {
  const parsed = JSON.parse(rawJson) as InstallPlan;
  if (!parsed || typeof parsed !== "object") {
    throw new Error("Install plan JSON must be an object.");
  }
  if (!Array.isArray(parsed.commands)) {
    throw new Error("Install plan commands must be an array.");
  }
  return parsed;
}

export function getSafePreviewBlockReasons(plan: InstallPlan): string[] {
  const reasons: string[] = [];
  const planRisk = normalizeRiskLevel(String(plan.riskLevel));

  if (blockedRiskLevels.has(planRisk)) {
    reasons.push(`Plan risk level ${planRisk} is blocked in the v0.8.0 controlled installation preview.`);
  }
  if (plan.requiresAdmin) {
    reasons.push("Plan requires admin privileges, which are blocked in v0.8.0.");
  }
  for (const command of plan.commands) {
    const commandRisk = normalizeRiskLevel(String(command.riskLevel ?? plan.riskLevel));
    if (blockedRiskLevels.has(commandRisk)) {
      reasons.push(`Command ${command.id} risk level ${commandRisk} is blocked in the v0.8.0 controlled installation preview.`);
    }
    if (command.requiresAdmin) {
      reasons.push(`Command ${command.id} requires admin privileges and is blocked in v0.8.0.`);
    }
  }

  return reasons;
}

export function assertSafePreviewPlan(plan: InstallPlan): void {
  const reasons = getSafePreviewBlockReasons(plan);
  if (reasons.length > 0) {
    throw new Error(reasons.join(" "));
  }
}

export function buildPlanSummary(plan: InstallPlan): PlanSummary {
  const blockReasons = getSafePreviewBlockReasons(plan);
  return {
    id: plan.id,
    platform: plan.platform,
    action: plan.action,
    description: plan.description,
    commandCount: plan.commands.length,
    riskLevel: normalizeRiskLevel(String(plan.riskLevel)),
    requiresAdmin: Boolean(plan.requiresAdmin),
    confirmationRequired: Boolean(plan.confirmationRequired),
    blockedInGui: blockReasons.length > 0,
    blockReasons,
  };
}

export function getControlledExecutionState(plan: InstallPlan, confirmationChecked: boolean): ControlledExecutionState {
  const reasons = getSafePreviewBlockReasons(plan);
  if (plan.dryRunOnly) {
    reasons.push("Plan is marked dryRunOnly.");
  }
  for (const command of plan.commands) {
    if (command.dryRunOnly) {
      reasons.push(`Command ${command.id} is marked dryRunOnly.`);
    }
  }
  if (!confirmationChecked) {
    reasons.push("Explicit confirmation checkbox is required before any controlled LOW-risk execution.");
  }
  const confirmedExecutionAllowed = confirmationChecked && reasons.length === 0;
  return {
    dryRunDefault: true,
    confirmationChecked,
    confirmedExecutionAllowed,
    disabledReason: confirmedExecutionAllowed
      ? ""
      : reasons.join(" ") ||
        "Real installation is not enabled in this preview. v0.8.0 supports controlled simulation and LOW-risk allowlisted execution only.",
  };
}

export function commandLine(command: InstallCommand): string {
  return [command.command, ...(command.args ?? [])].join(" ");
}
