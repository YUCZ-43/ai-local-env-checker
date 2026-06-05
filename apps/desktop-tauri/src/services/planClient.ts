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
  approvalRequired?: boolean;
  approvalState?: ApprovalState;
  blockedReason?: string;
  uiSeverity?: UiSeverity;
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
  adminReason?: string;
  approvalRequired?: boolean;
  approvalState?: ApprovalState;
  approvalSummary?: string;
  rollbackPlan?: string;
  rollbackWarning?: string;
  realRunDisabled?: boolean;
  dryRunDefault?: boolean;
  permissionReview?: string;
  userConfirmed?: boolean;
  blockedReason?: string;
  uiSeverity?: UiSeverity;
  displayLanguage?: string;
  themePreference?: string;
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

export type ApprovalState = "allowed" | "preview-only" | "blocked";
export type UiSeverity = "success" | "warning" | "high" | "danger" | "neutral";

export interface CommandApproval {
  id: string;
  description: string;
  approvalRequired: boolean;
  approvalState: ApprovalState;
  requiresAdmin: boolean;
  riskLevel: string;
  uiSeverity: UiSeverity;
  blockedReason: string;
  rollbackAvailable: boolean;
  rollbackNote: string;
  commandPreview: string;
}

export interface ApprovalSummary {
  requiresAdmin: boolean;
  adminReason: string;
  adminState: ApprovalState;
  approvalRequired: boolean;
  approvalState: ApprovalState;
  approvalSummary: string;
  commandApprovals: CommandApproval[];
  rollbackAvailable: boolean;
  rollbackPlan: string;
  rollbackWarning: string;
  realRunDisabled: boolean;
  dryRunDefault: boolean;
  permissionReview: string;
  userConfirmed: boolean;
  blockedReason: string;
  uiSeverity: UiSeverity;
  displayLanguage: string;
  themePreference: string;
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

export function buildApprovalSummary(plan: InstallPlan): ApprovalSummary {
  const blockReasons = getSafePreviewBlockReasons(plan);
  const commandApprovals = plan.commands.map((command) => buildCommandApproval(command, plan));
  const hasBlockedCommands = commandApprovals.some((command) => command.approvalState === "blocked");
  const adminState: ApprovalState = plan.requiresAdmin ? "blocked" : "preview-only";
  const approvalState: ApprovalState = blockReasons.length > 0 || hasBlockedCommands ? "blocked" : "preview-only";
  const blockedReason =
    plan.blockedReason ||
    blockReasons.join(" ") ||
    "Real installation is disabled by default. This version supports approval review, dry-run, and simulation only.";

  return {
    requiresAdmin: Boolean(plan.requiresAdmin),
    adminReason: plan.adminReason || (plan.requiresAdmin ? "Admin permission is required by the selected plan and must be reviewed outside automatic execution." : "No admin permission is required for this preview plan."),
    adminState,
    approvalRequired: plan.approvalRequired ?? true,
    approvalState: plan.approvalState ?? approvalState,
    approvalSummary:
      plan.approvalSummary ||
      "v0.9.0 separates permission review, command approval, rollback review, and execution state before any controlled installation can be considered.",
    commandApprovals,
    rollbackAvailable: Boolean(plan.rollbackAvailable),
    rollbackPlan: plan.rollbackPlan || plan.rollbackNote || "Rollback is represented as a review item; no rollback command is executed by the desktop UI.",
    rollbackWarning:
      plan.rollbackWarning ||
      (plan.rollbackAvailable
        ? "Rollback is available as a documented operator step and must be verified before real execution."
        : "Rollback is unavailable or not proven; real execution remains blocked."),
    realRunDisabled: plan.realRunDisabled ?? true,
    dryRunDefault: plan.dryRunDefault ?? true,
    permissionReview:
      plan.permissionReview ||
      "Review admin need, command risk, rollback coverage, dry-run output, and audit visibility before approving any future controlled run.",
    userConfirmed: Boolean(plan.userConfirmed),
    blockedReason,
    uiSeverity: plan.uiSeverity || severityForRisk(plan.riskLevel, plan.requiresAdmin),
    displayLanguage: plan.displayLanguage || "en-US",
    themePreference: plan.themePreference || "system",
  };
}

function buildCommandApproval(command: InstallCommand, plan: InstallPlan): CommandApproval {
  const riskLevel = normalizeRiskLevel(String(command.riskLevel ?? plan.riskLevel));
  const requiresAdmin = Boolean(command.requiresAdmin || plan.requiresAdmin);
  const blockedByRisk = blockedRiskLevels.has(riskLevel);
  const approvalState: ApprovalState = command.approvalState ?? (requiresAdmin || blockedByRisk ? "blocked" : "preview-only");
  const blockedReason =
    command.blockedReason ||
    (requiresAdmin
      ? `Command ${command.id} requires admin permission and is blocked in the desktop approval preview.`
      : blockedByRisk
        ? `Command ${command.id} risk level ${riskLevel} is blocked in the desktop approval preview.`
        : "Command is eligible for dry-run approval review only; real execution remains disabled.");

  return {
    id: command.id,
    description: command.description || command.id,
    approvalRequired: command.approvalRequired ?? command.confirmationRequired ?? true,
    approvalState,
    requiresAdmin,
    riskLevel,
    uiSeverity: command.uiSeverity || severityForRisk(riskLevel, requiresAdmin),
    blockedReason,
    rollbackAvailable: Boolean(plan.rollbackAvailable),
    rollbackNote: command.rollbackNote || plan.rollbackNote || "No rollback note supplied.",
    commandPreview: commandLine(command),
  };
}

export function severityForRisk(riskLevel: string | undefined, requiresAdmin = false): UiSeverity {
  const normalized = normalizeRiskLevel(riskLevel);
  if (requiresAdmin || normalized === "ADMIN_REQUIRED" || normalized === "DANGEROUS") return "danger";
  if (normalized === "HIGH") return "high";
  if (normalized === "MEDIUM") return "warning";
  if (normalized === "LOW") return "success";
  return "neutral";
}

export function commandLine(command: InstallCommand): string {
  return [command.command, ...(command.args ?? [])].join(" ");
}
