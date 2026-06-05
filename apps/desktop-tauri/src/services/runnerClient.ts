import { invoke } from "@tauri-apps/api/core";
import { assertSafePreviewPlan, type InstallPlan } from "./planClient";

export interface RunnerResult {
  ok: boolean;
  mode: string;
  stdout: string;
  stderr: string;
  reportPath?: string;
}

export interface ExamplePlanInfo {
  name: string;
  path: string;
}

export interface AppInfo {
  name: string;
  version: string;
  safetyMode: string;
}

export async function getAppInfo(): Promise<AppInfo> {
  return invoke<AppInfo>("get_app_info");
}

export async function listExamplePlans(): Promise<ExamplePlanInfo[]> {
  return invoke<ExamplePlanInfo[]>("list_example_plans");
}

export async function readPlan(path: string): Promise<string> {
  return invoke<string>("read_plan", { path });
}

export async function validatePlan(path: string): Promise<RunnerResult> {
  return invoke<RunnerResult>("validate_plan", { path });
}

export async function simulatePlan(path: string, plan: InstallPlan): Promise<RunnerResult> {
  assertSafePreviewPlan(plan);
  return invoke<RunnerResult>("simulate_plan", { path });
}

export async function dryRunPlan(path: string, plan: InstallPlan): Promise<RunnerResult> {
  assertSafePreviewPlan(plan);
  return invoke<RunnerResult>("dry_run_plan", { path });
}

export async function getReportLocation(): Promise<string> {
  return invoke<string>("get_report_location");
}
