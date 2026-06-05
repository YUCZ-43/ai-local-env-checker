export type RiskLevel = "LOW" | "MEDIUM" | "HIGH" | "DANGEROUS";

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
}

export interface InstallPlan {
  id: string;
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

const blockedRiskLevels = new Set(["MEDIUM", "HIGH", "DANGEROUS"]);

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
    reasons.push(`Plan risk level ${planRisk} is blocked in the v0.7.0 installer preview.`);
  }
  if (plan.requiresAdmin) {
    reasons.push("Plan requires admin privileges, which are disabled in the v0.7.0 installer preview.");
  }

  for (const command of plan.commands) {
    const commandRisk = normalizeRiskLevel(String(command.riskLevel ?? plan.riskLevel));
    if (blockedRiskLevels.has(commandRisk)) {
      reasons.push(`Command ${command.id} risk level ${commandRisk} is blocked in the v0.7.0 installer preview.`);
    }
    if (command.requiresAdmin) {
      reasons.push(`Command ${command.id} requires admin privileges.`);
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

export function commandLine(command: InstallCommand): string {
  return [command.command, ...(command.args ?? [])].join(" ");
}
