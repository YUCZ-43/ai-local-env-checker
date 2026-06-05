import "./styles.css";
import {
  buildApprovalSummary,
  buildPlanSummary,
  commandLine,
  getControlledExecutionState,
  parseInstallPlan,
  type ApprovalSummary,
  type CommandApproval,
  type InstallPlan,
  type PlanSummary,
} from "./services/planClient";
import {
  dryRunPlan,
  getAppInfo,
  listExamplePlans,
  readPlan,
  simulatePlan,
  validatePlan,
  type ExamplePlanInfo,
} from "./services/runnerClient";
import { loadReportPreview } from "./services/reportClient";
import {
  buildToolSummary,
  commandLine as toolCommandLine,
  listToolCatalog,
  previewToolDetection,
  previewToolPlan,
  type ToolManifest,
} from "./services/toolCatalogClient";

type SectionId =
  | "dashboard"
  | "environment"
  | "toolCatalog"
  | "plan"
  | "policy"
  | "adminReview"
  | "installerApproval"
  | "commandApproval"
  | "rollback"
  | "dryrun"
  | "controlledRun"
  | "progress"
  | "logs"
  | "reports"
  | "settings";

type ThemePreference = "light" | "dark" | "system";
type DisplayLanguage = "en-US" | "zh-CN";

interface AppState {
  section: SectionId;
  appName: string;
  appVersion: string;
  safetyMode: string;
  themePreference: ThemePreference;
  displayLanguage: DisplayLanguage;
  plans: ExamplePlanInfo[];
  selectedPath: string;
  rawPlan: string;
  plan: InstallPlan | null;
  summary: PlanSummary | null;
  approval: ApprovalSummary | null;
  log: string[];
  reportLocation: string;
  tools: ToolManifest[];
  selectedToolId: string;
  confirmationChecked: boolean;
  lastRunResult: string;
}

const labels = {
  "en-US": {
    dashboard: "Dashboard",
    environment: "Environment Check",
    toolCatalog: "Tool Catalog",
    plan: "Install Plan",
    policy: "Risk Review",
    adminReview: "Admin Permission Review",
    installerApproval: "Real Installer Approval",
    commandApproval: "Command Approval",
    rollback: "Rollback Strategy",
    dryrun: "Dry Run",
    controlledRun: "Controlled Run",
    progress: "Execution Progress",
    logs: "Logs",
    reports: "Reports",
    settings: "Settings",
    light: "Light Mode",
    dark: "Dark Mode",
    system: "System",
    language: "Language",
    realDisabled: "Real installation disabled",
    dryRunEnabled: "Dry-run enabled",
    adminRequired: "Admin permission required",
    commandRequired: "Command approval required",
    rollbackAvailable: "Rollback available",
    rollbackUnavailable: "Rollback unavailable",
    blocked: "Blocked",
    allowed: "Allowed",
    simulated: "Simulated",
  },
  "zh-CN": {
    dashboard: "仪表盘",
    environment: "环境检查",
    toolCatalog: "工具目录",
    plan: "安装计划",
    policy: "风险复核",
    adminReview: "管理员权限复核",
    installerApproval: "真实安装审批",
    commandApproval: "命令审批",
    rollback: "回滚策略",
    dryrun: "试运行",
    controlledRun: "受控运行",
    progress: "执行进度",
    logs: "日志",
    reports: "报告",
    settings: "设置",
    light: "浅色模式",
    dark: "深色模式",
    system: "跟随系统",
    language: "语言",
    realDisabled: "真实安装已禁用",
    dryRunEnabled: "试运行已启用",
    adminRequired: "需要管理员权限",
    commandRequired: "需要命令审批",
    rollbackAvailable: "可回滚",
    rollbackUnavailable: "不可回滚",
    blocked: "已阻止",
    allowed: "允许",
    simulated: "已模拟",
  },
} satisfies Record<DisplayLanguage, Record<string, string>>;

const state: AppState = {
  section: "dashboard",
  appName: "AI Local Environment Checker",
  appVersion: "0.9.0-alpha.1",
  safetyMode: "approval-preview",
  themePreference: readThemePreference(),
  displayLanguage: readDisplayLanguage(),
  plans: [],
  selectedPath: "",
  rawPlan: "",
  plan: null,
  summary: null,
  approval: null,
  log: ["v0.9.0-alpha.1 GUI initialized in local approval-preview mode."],
  reportLocation: "",
  tools: [],
  selectedToolId: "",
  confirmationChecked: false,
  lastRunResult: "No validation, simulation, or dry-run result yet.",
};

function t(key: keyof (typeof labels)["en-US"]): string {
  return labels[state.displayLanguage][key] ?? labels["en-US"][key] ?? key;
}

const sections: Array<{ id: SectionId; labelKey: keyof (typeof labels)["en-US"] }> = [
  { id: "dashboard", labelKey: "dashboard" },
  { id: "environment", labelKey: "environment" },
  { id: "toolCatalog", labelKey: "toolCatalog" },
  { id: "plan", labelKey: "plan" },
  { id: "policy", labelKey: "policy" },
  { id: "adminReview", labelKey: "adminReview" },
  { id: "installerApproval", labelKey: "installerApproval" },
  { id: "commandApproval", labelKey: "commandApproval" },
  { id: "rollback", labelKey: "rollback" },
  { id: "dryrun", labelKey: "dryrun" },
  { id: "controlledRun", labelKey: "controlledRun" },
  { id: "progress", labelKey: "progress" },
  { id: "logs", labelKey: "logs" },
  { id: "reports", labelKey: "reports" },
  { id: "settings", labelKey: "settings" },
];

const repoUrl = "https://github.com/YUCZ-43/ai-local-env-checker";
const docsUrl = `${repoUrl}/tree/main/docs`;
const alphaUrl = `${repoUrl}/releases/tag/v0.9.0-alpha.1`;

const platformCards = [
  {
    title: "Windows Alpha Preview",
    detail: "Desktop package target for this app only. Third-party installers stay disabled.",
    tone: "ok" as const,
  },
  {
    title: "macOS Planned",
    detail: "Packaging requirements documented. No macOS installer is claimed in this alpha.",
    tone: "neutral" as const,
  },
  {
    title: "Linux Planned",
    detail: "Linux package route is planned after desktop validation and release review.",
    tone: "neutral" as const,
  },
  {
    title: "WSL Detection Preview",
    detail: "Check-first detection remains available without repair or install actions.",
    tone: "warn" as const,
  },
];

const safetyRails = [
  "No silent install",
  "No automatic UAC bypass",
  "No automatic PATH modification",
  "No automatic proxy modification",
  "Approval-first workflow",
  "Local logs and reports",
];

function readThemePreference(): ThemePreference {
  const stored = window.localStorage?.getItem("ai-local-theme");
  return stored === "light" || stored === "dark" || stored === "system" ? stored : "light";
}

function readDisplayLanguage(): DisplayLanguage {
  const stored = window.localStorage?.getItem("ai-local-language");
  return stored === "en-US" || stored === "zh-CN" ? stored : "en-US";
}

function applyTheme(): void {
  const resolved =
    state.themePreference === "system"
      ? window.matchMedia?.("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light"
      : state.themePreference;
  document.documentElement.dataset.theme = resolved;
  document.documentElement.dataset.themePreference = state.themePreference;
}

function appendLog(message: string): void {
  const stamp = new Date().toLocaleTimeString();
  state.log = [`[${stamp}] ${message}`, ...state.log].slice(0, 200);
  render();
}

function setPlan(raw: string, path: string): void {
  const plan = parseInstallPlan(raw);
  state.selectedPath = path;
  state.rawPlan = raw;
  state.plan = plan;
  state.summary = buildPlanSummary(plan);
  state.approval = buildApprovalSummary(plan);
  state.confirmationChecked = false;
  state.lastRunResult = "No validation, simulation, or dry-run result yet.";
}

async function loadSelectedPlan(path: string): Promise<void> {
  try {
    const raw = await readPlan(path);
    setPlan(raw, path);
    appendLog(`Loaded install plan: ${path}`);
  } catch (error) {
    appendLog(`Failed to load install plan: ${formatError(error)}`);
  }
}

async function runValidate(): Promise<void> {
  if (!state.selectedPath) return;
  appendLog("Running safe CLI validation. No installer command is executed.");
  const result = await validatePlan(state.selectedPath);
  appendLog(formatRunnerResult(result.stdout, result.stderr));
}

async function runSimulate(): Promise<void> {
  if (!state.selectedPath || !state.plan) return;
  try {
    appendLog("Running safe CLI simulation. Real installation remains disabled.");
    const result = await simulatePlan(state.selectedPath, state.plan);
    state.lastRunResult = formatRunnerResult(result.stdout, result.stderr);
    if (result.reportPath) state.reportLocation = result.reportPath;
    appendLog(state.lastRunResult);
  } catch (error) {
    appendLog(`Simulation blocked: ${formatError(error)}`);
  }
}

async function runDryRun(): Promise<void> {
  if (!state.selectedPath || !state.plan) return;
  try {
    appendLog("Running safe CLI dry-run. This does not install software.");
    const result = await dryRunPlan(state.selectedPath, state.plan);
    state.lastRunResult = formatRunnerResult(result.stdout, result.stderr);
    if (result.reportPath) state.reportLocation = result.reportPath;
    appendLog(state.lastRunResult);
  } catch (error) {
    appendLog(`Dry-run blocked: ${formatError(error)}`);
  }
}

async function runToolDetectionPreview(): Promise<void> {
  appendLog("Loading tool detection preview. The GUI does not execute detection commands directly.");
  try {
    appendLog(await previewToolDetection());
  } catch (error) {
    appendLog(`Tool detection preview failed: ${formatError(error)}`);
  }
}

async function runToolPlanPreview(toolId: string): Promise<void> {
  appendLog(`Loading dry-run plan preview for tool: ${toolId}`);
  try {
    appendLog(await previewToolPlan(toolId));
  } catch (error) {
    appendLog(`Tool plan preview failed: ${formatError(error)}`);
  }
}

function formatRunnerResult(stdout: string, stderr: string): string {
  return [stdout.trim(), stderr.trim()].filter(Boolean).join("\n") || "Command completed with no output.";
}

function formatError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function badge(text: string, tone: "ok" | "warn" | "high" | "blocked" | "neutral" = "neutral"): string {
  return `<span class="badge ${tone}">${escapeHtml(text)}</span>`;
}

function toneForSeverity(severity: string): "ok" | "warn" | "high" | "blocked" | "neutral" {
  if (severity === "success") return "ok";
  if (severity === "warning") return "warn";
  if (severity === "high") return "high";
  if (severity === "danger") return "blocked";
  return "neutral";
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function render(): void {
  applyTheme();
  const app = document.querySelector<HTMLDivElement>("#app");
  if (!app) return;
  const current = sections.find((section) => section.id === state.section);

  app.innerHTML = `
    <aside class="sidebar">
      <div class="brand">
        <div class="brand-mark">AI</div>
        <div>
          <h1>${escapeHtml(state.appName)}</h1>
          <p>v${escapeHtml(state.appVersion)} approval preview</p>
        </div>
      </div>
      <div class="sidebar-signal">
        <span>local-first</span>
        <strong>Approval archive</strong>
        <small>Check, plan, review, then dry-run.</small>
      </div>
      <nav>${sections
        .map(
          (section) =>
            `<button class="nav-item ${section.id === state.section ? "active" : ""}" data-section="${section.id}">${escapeHtml(t(section.labelKey))}</button>`,
        )
        .join("")}</nav>
    </aside>
    <main class="workspace">
      <header class="topbar">
        <div>
          <p class="eyebrow">v0.9.0-alpha.1 local self-test</p>
          <h2>${escapeHtml(current ? t(current.labelKey) : t("dashboard"))}</h2>
        </div>
        <div class="status-row">
          ${badge(t("realDisabled"), "blocked")}
          ${badge(t("dryRunEnabled"), "ok")}
          ${badge(t("adminRequired"), "warn")}
          ${badge(`${t("light")}/${t("dark")}: ${state.themePreference}`, "neutral")}
        </div>
      </header>
      ${renderSection()}
    </main>
  `;

  bindEvents();
}

function renderSection(): string {
  switch (state.section) {
    case "dashboard":
      return renderDashboard();
    case "environment":
      return renderEnvironment();
    case "toolCatalog":
      return renderToolCatalog();
    case "plan":
      return renderPlanViewer();
    case "policy":
      return renderPolicy();
    case "adminReview":
      return renderAdminReview();
    case "installerApproval":
      return renderInstallerApproval();
    case "commandApproval":
      return renderCommandApproval();
    case "rollback":
      return renderRollback();
    case "dryrun":
      return renderDryRun();
    case "controlledRun":
      return renderControlledRun();
    case "progress":
      return renderProgress();
    case "logs":
      return renderLogs();
    case "reports":
      return renderReports();
    case "settings":
      return renderSettings();
  }
}

function renderDashboard(): string {
  return `
    <section class="hero-panel product-hero">
      <div class="hero-copy">
        <p class="eyebrow">permission-first AI infrastructure</p>
        <h3>Premium local approval cockpit for AI development environments</h3>
        <p>AI Local Environment Checker turns machine readiness, install plans, admin sensitivity, command risk, rollback coverage, and audit reports into one calm review journey. Real third-party installation remains disabled for this alpha.</p>
        <div class="actions hero-actions">
          <a class="button-link primary-link" href="${repoUrl}" target="_blank" rel="noreferrer">GitHub</a>
          <a class="button-link secondary-link" href="${docsUrl}" target="_blank" rel="noreferrer">Docs</a>
          <a class="button-link secondary-link" href="${alphaUrl}" target="_blank" rel="noreferrer">Alpha preview</a>
        </div>
      </div>
      ${renderProductPreview()}
    </section>
    <section class="status-card-grid">
      ${statusCard(t("dryRunEnabled"), "Default execution posture", "ok")}
      ${statusCard(t("commandRequired"), "Every command is visible before approval.", "warn")}
      ${statusCard(t("realDisabled"), "Real installer controls are preview-only.", "blocked")}
      ${statusCard(state.approval?.rollbackAvailable ? t("rollbackAvailable") : t("rollbackUnavailable"), state.approval?.rollbackWarning ?? "Load a plan to review rollback state.", state.approval?.rollbackAvailable ? "ok" : "warn")}
    </section>
    ${renderPlatformCards()}
    ${renderSafetyRails()}
    <section class="panel-grid">
      <article class="panel">
        <h3>Current plan</h3>
        ${state.summary ? renderSummaryDetails(state.summary) : "<p>No install plan loaded yet. Open Install Plan to load an example plan.</p>"}
      </article>
      <article class="panel">
        <h3>Approval state</h3>
        ${state.approval ? renderApprovalSummary(state.approval) : "<p>Approval summary appears after a plan is loaded.</p>"}
      </article>
    </section>
  `;
}

function statusCard(title: string, detail: string, tone: "ok" | "warn" | "blocked" | "neutral"): string {
  return `
    <article class="status-card ${tone}">
      <div class="icon-box"><span class="signal-dot"></span></div>
      <div>
        <strong>${escapeHtml(title)}</strong>
        <span>${escapeHtml(detail)}</span>
      </div>
    </article>
  `;
}

function renderProductPreview(): string {
  return `
    <div class="product-preview" aria-label="Product workflow preview">
      <div class="preview-header">
        <span>alpha package</span>
        ${badge(t("realDisabled"), "blocked")}
      </div>
      <div class="preview-orbit">
        <div>
          <strong>Check</strong>
          <small>environment readiness</small>
        </div>
        <div>
          <strong>Plan</strong>
          <small>commands visible</small>
        </div>
        <div>
          <strong>Review</strong>
          <small>admin and rollback</small>
        </div>
      </div>
      <div class="approval-banner">
        <strong>${escapeHtml(t("realDisabled"))}</strong>
        <span>No UAC, no PATH edits, no proxy changes, no global environment mutation.</span>
      </div>
    </div>
  `;
}

function renderPlatformCards(): string {
  return `
    <section class="platform-grid">
      ${platformCards
        .map(
          (platform) => `
            <article class="platform-card ${platform.tone}">
              <span class="platform-rail"></span>
              <strong>${escapeHtml(platform.title)}</strong>
              <p>${escapeHtml(platform.detail)}</p>
            </article>
          `,
        )
        .join("")}
    </section>
  `;
}

function renderSafetyRails(): string {
  return `
    <section class="safety-rail" aria-label="Safety guardrails">
      ${safetyRails.map((rail) => `<span>${escapeHtml(rail)}</span>`).join("")}
    </section>
  `;
}

function renderEnvironment(): string {
  return `
    <section class="split">
      <article class="panel">
        <p class="eyebrow">doctor surface</p>
        <h3>${escapeHtml(t("environment"))}</h3>
        <p>This screen stays check-first. It is reserved for safe doctor output and does not repair, install, elevate, modify PATH, change proxy settings, or write global environment variables.</p>
        <button class="secondary" id="doctor-button">Record doctor preview note</button>
      </article>
      <article class="panel">
        <h3>Platform readiness</h3>
        <div class="mini-grid">
          ${platformCards.map((platform) => statusCard(platform.title, platform.detail, platform.tone)).join("")}
        </div>
      </article>
    </section>
  `;
}

function renderToolCatalog(): string {
  const selected = state.tools.find((tool) => tool.id === state.selectedToolId) ?? state.tools[0];
  const summaries = state.tools.map(buildToolSummary);
  return `
    <section class="split wide">
      <article class="panel">
        <div class="panel-heading">
          <h3>${escapeHtml(t("toolCatalog"))}</h3>
          <button class="secondary" id="tool-detect-button">Detection preview</button>
        </div>
        <div class="tool-list">
          ${
            summaries.length
              ? summaries
                  .map(
                    (tool) => `
                      <button class="tool-row ${selected?.id === tool.id ? "active" : ""}" data-tool-id="${escapeHtml(tool.id)}">
                        <strong>${escapeHtml(tool.displayName)}</strong>
                        <span>${escapeHtml(tool.category)}</span>
                        ${badge(tool.status, tool.status === "template-only" ? "warn" : "neutral")}
                        ${badge(tool.riskLevel, tool.riskLevel === "LOW" ? "ok" : "warn")}
                      </button>
                    `,
                  )
                  .join("")
              : "<p>No tool manifests loaded.</p>"
          }
        </div>
      </article>
      <article class="panel">
        <h3>Tool details</h3>
        ${selected ? renderToolDetails(selected) : "<p>Select a tool to view details.</p>"}
      </article>
    </section>
  `;
}

function renderToolDetails(tool: ToolManifest): string {
  const summary = buildToolSummary(tool);
  return `
    <dl class="summary-list">
      <dt>Name</dt><dd>${escapeHtml(summary.displayName)}</dd>
      <dt>Status</dt><dd>${badge(summary.status, summary.status === "template-only" ? "warn" : "neutral")}</dd>
      <dt>Platforms</dt><dd>${escapeHtml(summary.platforms)}</dd>
      <dt>Risk</dt><dd>${badge(summary.riskLevel, summary.riskLevel === "LOW" ? "ok" : "warn")}</dd>
      <dt>Requires admin</dt><dd>${summary.requiresAdmin ? "Yes" : "No"}</dd>
      <dt>Install mode</dt><dd>${escapeHtml(summary.recommendedInstallMode)}</dd>
      <dt>Install</dt><dd>Disabled in approval preview</dd>
    </dl>
    <p>${escapeHtml(tool.description)}</p>
    <div class="actions">
      <button class="secondary" id="tool-details-button">View details</button>
      <button class="secondary" id="tool-plan-button" ${summary.planCount === 0 ? "disabled" : ""}>View dry-run plan</button>
    </div>
    <h3>Detection preview commands</h3>
    <div class="command-list compact">
      ${tool.detectionCommands
        .map(
          (command) => `
            <div class="command-item">
              <code>${escapeHtml(toolCommandLine(command))}</code>
              <small>${escapeHtml(command.platform)} / ${escapeHtml(command.shell)} / risk=${escapeHtml(command.riskLevel)}</small>
            </div>
          `,
        )
        .join("")}
    </div>
  `;
}

function renderPlanViewer(): string {
  const options = state.plans
    .map((plan) => `<option value="${escapeHtml(plan.path)}" ${plan.path === state.selectedPath ? "selected" : ""}>${escapeHtml(plan.name)}</option>`)
    .join("");

  return `
    <section class="split">
      <article class="panel">
        <h3>${escapeHtml(t("plan"))}</h3>
        <label class="field">
          <span>Plan file</span>
          <select id="plan-select">
            <option value="">Select an example plan</option>
            ${options}
          </select>
        </label>
        ${state.summary ? renderSummaryDetails(state.summary) : "<p>Select a plan to inspect risk, commands, approval gates, and rollback coverage.</p>"}
      </article>
      <article class="panel">
        <h3>Command previews</h3>
        ${renderCommands()}
      </article>
    </section>
  `;
}

function renderSummaryDetails(summary: PlanSummary): string {
  return `
    <dl class="summary-list">
      <dt>Description</dt><dd>${escapeHtml(summary.description)}</dd>
      <dt>Platform</dt><dd>${escapeHtml(summary.platform)}</dd>
      <dt>Action</dt><dd>${escapeHtml(summary.action)}</dd>
      <dt>Risk</dt><dd>${badge(summary.riskLevel, summary.blockedInGui ? "blocked" : "ok")}</dd>
      <dt>Confirmation</dt><dd>${summary.confirmationRequired ? "Required" : "Not required"}</dd>
      <dt>GUI status</dt><dd>${summary.blockedInGui ? t("blocked") : t("allowed")}</dd>
    </dl>
  `;
}

function renderCommands(): string {
  if (!state.plan) return "<p>No commands loaded.</p>";
  return `
    <div class="command-list">
      ${state.plan.commands
        .map(
          (command) => `
            <div class="command-item">
              <div class="command-title">
                <strong>${escapeHtml(command.id)}</strong>
                ${badge(String(command.riskLevel ?? state.plan?.riskLevel ?? "LOW"), command.riskLevel === "LOW" ? "ok" : "warn")}
              </div>
              <p>${escapeHtml(command.description ?? "")}</p>
              <code>${escapeHtml(commandLine(command))}</code>
              <small>requiresAdmin=${Boolean(command.requiresAdmin)} / dryRunOnly=${Boolean(command.dryRunOnly)} / confirmationRequired=${Boolean(command.confirmationRequired)}</small>
            </div>
          `,
        )
        .join("")}
    </div>
  `;
}

function renderPolicy(): string {
  const reasons = state.summary?.blockReasons ?? [];
  return `
    <section class="panel">
      <h3>${escapeHtml(t("policy"))}</h3>
      <p>Policy-driven UI states block real installation by default. MEDIUM, HIGH, ADMIN_REQUIRED, DANGEROUS, and admin-required commands are blocked in the desktop approval preview.</p>
      ${renderSafetyRails()}
      ${
        reasons.length
          ? `<ul class="reason-list">${reasons.map((reason) => `<li>${escapeHtml(reason)}</li>`).join("")}</ul>`
          : `<p class="empty-state">No loaded-plan block reason. Real installation is still disabled; only validation, simulation, and dry-run are available.</p>`
      }
    </section>
  `;
}

function renderAdminReview(): string {
  const approval = state.approval;
  return `
    <section class="panel">
      <h3>${escapeHtml(t("adminReview"))}</h3>
      ${
        approval
          ? `<dl class="summary-list">
              <dt>State</dt><dd>${badge(approval.adminState, approval.adminState === "blocked" ? "blocked" : "warn")}</dd>
              <dt>Requires admin</dt><dd>${approval.requiresAdmin ? "Yes" : "No"}</dd>
              <dt>Reason</dt><dd>${escapeHtml(approval.adminReason)}</dd>
              <dt>Review</dt><dd>${escapeHtml(approval.permissionReview)}</dd>
            </dl>`
          : "<p>Load a plan to review admin permission sensitivity.</p>"
      }
      <p class="blocked-note">The desktop app does not auto-elevate, does not trigger UAC, and does not request administrator rights in v0.9.0.</p>
    </section>
  `;
}

function renderInstallerApproval(): string {
  const approval = state.approval;
  return `
    <section class="panel">
      <h3>${escapeHtml(t("installerApproval"))}</h3>
      ${
        approval
          ? `<dl class="summary-list">
              <dt>Real run</dt><dd>${badge(approval.realRunDisabled ? t("realDisabled") : t("allowed"), approval.realRunDisabled ? "blocked" : "ok")}</dd>
              <dt>Dry-run default</dt><dd>${approval.dryRunDefault ? "Yes" : "No"}</dd>
              <dt>Approval</dt><dd>${badge(approval.approvalState, approval.approvalState === "blocked" ? "blocked" : "warn")}</dd>
              <dt>Summary</dt><dd>${escapeHtml(approval.approvalSummary)}</dd>
              <dt>Blocked reason</dt><dd>${escapeHtml(approval.blockedReason)}</dd>
            </dl>`
          : "<p>Load a plan to inspect real installer approval state.</p>"
      }
      <div class="actions">
        <button class="danger" disabled>Real installer unavailable</button>
        <button class="secondary" disabled>Approval persistence future work</button>
      </div>
    </section>
  `;
}

function renderCommandApproval(): string {
  const commands = state.approval?.commandApprovals ?? [];
  return `
    <section class="panel">
      <h3>${escapeHtml(t("commandApproval"))}</h3>
      <p>Every command preview stays visible. Blocked commands remain visible so operators can understand why the approval model refused them.</p>
      <div class="command-list timeline">
        ${
          commands.length
            ? commands.map(renderCommandApprovalItem).join("")
            : "<p>Load a plan to inspect command approvals.</p>"
        }
      </div>
    </section>
  `;
}

function renderCommandApprovalItem(command: CommandApproval): string {
  return `
    <div class="command-item approval-${escapeHtml(command.uiSeverity)}">
      <span class="timeline-node"></span>
      <div class="command-title">
        <strong>${escapeHtml(command.id)}</strong>
        <span class="badge-row">
          ${badge(command.riskLevel, toneForSeverity(command.uiSeverity))}
          ${badge(command.approvalState, command.approvalState === "blocked" ? "blocked" : "warn")}
        </span>
      </div>
      <p>${escapeHtml(command.description)}</p>
      <code>${escapeHtml(command.commandPreview)}</code>
      <small>approvalRequired=${command.approvalRequired} / requiresAdmin=${command.requiresAdmin} / rollback=${command.rollbackAvailable}</small>
      <p class="blocked-note">${escapeHtml(command.blockedReason)}</p>
    </div>
  `;
}

function renderRollback(): string {
  const approval = state.approval;
  return `
    <section class="panel">
      <h3>${escapeHtml(t("rollback"))}</h3>
      ${
        approval
          ? `<dl class="summary-list">
              <dt>Status</dt><dd>${badge(approval.rollbackAvailable ? t("rollbackAvailable") : t("rollbackUnavailable"), approval.rollbackAvailable ? "ok" : "warn")}</dd>
              <dt>Plan</dt><dd>${escapeHtml(approval.rollbackPlan)}</dd>
              <dt>Warning</dt><dd>${escapeHtml(approval.rollbackWarning)}</dd>
            </dl>`
          : "<p>Load a plan to review rollback state.</p>"
      }
    </section>
  `;
}

function renderDryRun(): string {
  const disabled = state.selectedPath ? "" : "disabled";
  return `
    <section class="panel">
      <h3>${escapeHtml(t("dryrun"))} / ${escapeHtml(t("simulated"))}</h3>
      <p>These controls call safe CLI modes only. They do not install software, repair tools, modify PATH, elevate, or run hidden commands.</p>
      <div class="actions">
        <button class="secondary" id="validate-button" ${disabled}>Validate plan</button>
        <button class="secondary" id="simulate-button" ${disabled}>Simulate plan</button>
        <button class="primary" id="dryrun-button" ${disabled}>Dry-run plan</button>
      </div>
    </section>
  `;
}

function renderControlledRun(): string {
  if (!state.plan) return `<section class="panel"><h3>${escapeHtml(t("controlledRun"))}</h3><p>Load a plan before reviewing controlled run state.</p></section>`;
  const execution = getControlledExecutionState(state.plan, state.confirmationChecked);
  return `
    <section class="panel">
      <h3>${escapeHtml(t("controlledRun"))}</h3>
      <p>Controlled run is a future approval surface in the desktop app. In this local self-test version, real run controls remain disabled even after review.</p>
      <dl class="summary-list">
        <dt>Dry-run default</dt><dd>${execution.dryRunDefault ? "Yes" : "No"}</dd>
        <dt>Review checkbox</dt><dd>${execution.confirmationChecked ? "Checked" : "Not checked"}</dd>
        <dt>CLI eligibility</dt><dd>${execution.confirmedExecutionAllowed ? "LOW-risk CLI only" : t("blocked")}</dd>
      </dl>
      <label class="check-field">
        <input type="checkbox" id="confirmation-checkbox" ${state.confirmationChecked ? "checked" : ""} />
        <span>I reviewed admin need, command previews, risk badges, rollback notes, dry-run state, and audit/report visibility.</span>
      </label>
      <div class="actions">
        <button class="secondary" id="simulate-button">Simulate plan</button>
        <button class="primary" id="dryrun-button">Dry-run plan</button>
        <button class="danger" id="real-run-button" disabled>${escapeHtml(t("realDisabled"))}</button>
      </div>
      <p class="blocked-note">${escapeHtml(execution.disabledReason || "Desktop real run remains disabled.")}</p>
    </section>
  `;
}

function renderProgress(): string {
  return `
    <section class="panel log-panel">
      <h3>${escapeHtml(t("progress"))}</h3>
      <p>Progress remains tied to validation, simulation, and dry-run output for v0.9.0. No real installer progress is emitted.</p>
      <pre>${escapeHtml(state.lastRunResult)}</pre>
    </section>
  `;
}

function renderLogs(): string {
  return `
    <section class="panel log-panel">
      <h3>${escapeHtml(t("logs"))}</h3>
      <pre>${escapeHtml(state.log.join("\n\n"))}</pre>
    </section>
  `;
}

function renderReports(): string {
  return `
    <section class="panel">
      <h3>${escapeHtml(t("reports"))}</h3>
      <p>Report path: <code>${escapeHtml(state.reportLocation || "No report generated in this session.")}</code></p>
      <p>Reports are local artifacts. They may contain machine data and must not be committed unless they are sanitized examples.</p>
      <div class="report-grid">
        ${statusCard("Audit viewer structure", "Events should show timestamp, mode, risk, approval state, and report path.", "neutral")}
        ${statusCard("Report preview", "Generated reports remain local and should be reviewed before sharing.", "warn")}
        ${statusCard("Never log secrets", "Tokens, keys, passwords, raw proxy credentials, and private file content are forbidden.", "blocked")}
      </div>
    </section>
  `;
}

function renderSettings(): string {
  return `
    <section class="split settings-layout">
      <article class="panel settings-panel">
        <div class="settings-heading">
          <div>
            <p class="eyebrow">display preferences</p>
            <h3>${escapeHtml(t("settings"))}</h3>
          </div>
          ${badge("Display only", "neutral")}
        </div>
        <div class="settings-control">
          <div>
            <strong>Theme</strong>
            <span>Changes the app surface only.</span>
          </div>
          <div class="segmented-control" role="group" aria-label="Theme preference">
            ${renderSegment("theme", "light", t("light"), state.themePreference === "light")}
            ${renderSegment("theme", "dark", t("dark"), state.themePreference === "dark")}
            ${renderSegment("theme", "system", t("system"), state.themePreference === "system")}
          </div>
        </div>
        <div class="settings-control">
          <div>
            <strong>${escapeHtml(t("language"))}</strong>
            <span>UI labels only; policy does not change.</span>
          </div>
          <div class="segmented-control language-control" role="group" aria-label="Display language">
            ${renderSegment("language", "en-US", "English", state.displayLanguage === "en-US")}
            ${renderSegment("language", "zh-CN", "简体中文", state.displayLanguage === "zh-CN")}
          </div>
        </div>
      </article>
      <article class="panel">
        <h3>Runtime policy</h3>
        <dl class="summary-list">
          <dt>Safety mode</dt><dd>${escapeHtml(state.safetyMode)}</dd>
          <dt>Install execution</dt><dd>${escapeHtml(t("realDisabled"))}</dd>
          <dt>Admin elevation</dt><dd>Not implemented</dd>
          <dt>Persistence</dt><dd>Theme and language use local UI state with localStorage when available.</dd>
        </dl>
      </article>
    </section>
  `;
}

function renderSegment(kind: "theme" | "language", value: string, label: string, active: boolean): string {
  const dataAttribute = kind === "theme" ? "data-theme-option" : "data-language-option";
  return `<button class="control-option ${active ? "active" : ""}" ${dataAttribute}="${escapeHtml(value)}" aria-pressed="${active}">${escapeHtml(label)}</button>`;
}

function renderApprovalSummary(approval: ApprovalSummary): string {
  return `
    <dl class="summary-list">
      <dt>Approval</dt><dd>${badge(approval.approvalState, approval.approvalState === "blocked" ? "blocked" : "warn")}</dd>
      <dt>Real run</dt><dd>${approval.realRunDisabled ? t("realDisabled") : t("allowed")}</dd>
      <dt>Admin</dt><dd>${approval.requiresAdmin ? t("adminRequired") : "Not required"}</dd>
      <dt>Commands</dt><dd>${approval.commandApprovals.length}</dd>
      <dt>Rollback</dt><dd>${approval.rollbackAvailable ? t("rollbackAvailable") : t("rollbackUnavailable")}</dd>
    </dl>
  `;
}

function bindEvents(): void {
  document.querySelectorAll<HTMLButtonElement>("[data-section]").forEach((button) => {
    button.addEventListener("click", () => {
      state.section = button.dataset.section as SectionId;
      render();
    });
  });

  document.querySelector<HTMLSelectElement>("#plan-select")?.addEventListener("change", (event) => {
    const target = event.currentTarget as HTMLSelectElement;
    if (target.value) void loadSelectedPlan(target.value);
  });

  document.querySelectorAll<HTMLButtonElement>("[data-theme-option]").forEach((button) => {
    button.addEventListener("click", () => {
      state.themePreference = button.dataset.themeOption as ThemePreference;
      window.localStorage?.setItem("ai-local-theme", state.themePreference);
      appendLog(`Theme preference changed to ${state.themePreference}.`);
    });
  });

  document.querySelectorAll<HTMLButtonElement>("[data-language-option]").forEach((button) => {
    button.addEventListener("click", () => {
      state.displayLanguage = button.dataset.languageOption as DisplayLanguage;
      window.localStorage?.setItem("ai-local-language", state.displayLanguage);
      appendLog(`Display language changed to ${state.displayLanguage}.`);
    });
  });

  document.querySelector<HTMLButtonElement>("#validate-button")?.addEventListener("click", () => void runValidate());
  document.querySelector<HTMLButtonElement>("#simulate-button")?.addEventListener("click", () => void runSimulate());
  document.querySelector<HTMLButtonElement>("#dryrun-button")?.addEventListener("click", () => void runDryRun());
  document.querySelector<HTMLInputElement>("#confirmation-checkbox")?.addEventListener("change", (event) => {
    state.confirmationChecked = (event.currentTarget as HTMLInputElement).checked;
    render();
  });
  document.querySelector<HTMLButtonElement>("#doctor-button")?.addEventListener("click", () => {
    appendLog("Doctor preview noted. v0.9.0 does not repair or install from the desktop UI.");
  });
  document.querySelector<HTMLButtonElement>("#tool-detect-button")?.addEventListener("click", () => void runToolDetectionPreview());
  document.querySelector<HTMLButtonElement>("#tool-plan-button")?.addEventListener("click", () => {
    const selected = state.selectedToolId || state.tools[0]?.id;
    if (selected) void runToolPlanPreview(selected);
  });
  document.querySelector<HTMLButtonElement>("#tool-details-button")?.addEventListener("click", () => {
    const selected = state.tools.find((tool) => tool.id === (state.selectedToolId || state.tools[0]?.id));
    if (selected) appendLog(`${selected.displayName}: ${selected.description}`);
  });
  document.querySelectorAll<HTMLButtonElement>("[data-tool-id]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedToolId = button.dataset.toolId ?? "";
      render();
    });
  });
}

async function bootstrap(): Promise<void> {
  render();
  try {
    const [info, plans, report, tools] = await Promise.all([getAppInfo(), listExamplePlans(), loadReportPreview(), listToolCatalog()]);
    state.appName = info.name;
    state.appVersion = "0.9.0-alpha.1";
    state.safetyMode = "approval-preview";
    state.plans = plans;
    state.reportLocation = report.location;
    state.tools = tools;
    state.selectedToolId = tools[0]?.id ?? "";
    appendLog(`Loaded ${plans.length} example install plan(s) and ${tools.length} tool manifest(s).`);
  } catch (error) {
    appendLog(`Backend initialization failed: ${formatError(error)}`);
  }
}

void bootstrap();
