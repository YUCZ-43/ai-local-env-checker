import { invoke } from "@tauri-apps/api/core";

export type ToolStatus = "installed" | "missing" | "unknown" | "template-only" | "preview" | "supported" | "manual-review";

export interface ToolCommand {
  platform: string;
  shell: string;
  command: string;
  args?: string[];
  riskLevel: string;
  requiresAdmin?: boolean;
  dryRunOnly?: boolean;
  description?: string;
}

export interface ToolPlanTemplate {
  id: string;
  path: string;
  dryRunOnly: boolean;
  riskLevel: string;
  description?: string;
}

export interface ToolManifest {
  id: string;
  displayName: string;
  category: string;
  description: string;
  supportedPlatforms: string[];
  recommendedInstallMode: string;
  detectionCommands: ToolCommand[];
  installPlanTemplates: ToolPlanTemplate[];
  verificationCommands: ToolCommand[];
  requiresAdmin: boolean;
  riskLevel: string;
  networkRequirements: string[];
  proxyRequirements: string[];
  securityWarnings: string[];
  notes: string[];
  docs: Array<{ label: string; path: string }>;
  status: ToolStatus;
}

export interface ToolSummary {
  id: string;
  displayName: string;
  category: string;
  platforms: string;
  status: ToolStatus;
  riskLevel: string;
  requiresAdmin: boolean;
  recommendedInstallMode: string;
  installDisabled: boolean;
  planCount: number;
}

export function buildToolSummary(tool: ToolManifest): ToolSummary {
  return {
    id: tool.id,
    displayName: tool.displayName,
    category: tool.category,
    platforms: tool.supportedPlatforms.join(", "),
    status: tool.status,
    riskLevel: tool.riskLevel,
    requiresAdmin: tool.requiresAdmin,
    recommendedInstallMode: tool.recommendedInstallMode,
    installDisabled: true,
    planCount: tool.installPlanTemplates.length,
  };
}

export function commandLine(command: ToolCommand): string {
  return [command.command, ...(command.args ?? [])].join(" ");
}

export async function listToolCatalog(): Promise<ToolManifest[]> {
  return invoke<ToolManifest[]>("list_tool_catalog");
}

export async function previewToolDetection(): Promise<string> {
  return invoke<string>("preview_tool_detection");
}

export async function previewToolPlan(toolId: string): Promise<string> {
  return invoke<string>("preview_tool_plan", { toolId });
}
