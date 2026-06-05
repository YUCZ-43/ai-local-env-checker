import "./styles.css";
import {
  buildPlanSummary,
  commandLine,
  parseInstallPlan,
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
  | "dryrun"
  | "logs"
  | "reports"
  | "settings";

interface AppState {
  section: SectionId;
  appName: string;
  appVersion: string;
  safetyMode: string;
  plans: ExamplePlanInfo[];
  selectedPath: string;
  rawPlan: string;
  plan: InstallPlan | null;
  summary: PlanSummary | null;
  log: string[];
  reportLocation: string;
  tools: ToolManifest[];
  selectedToolId: string;
}

const state: AppState = {
  section: "dashboard",
  appName: "AI Local Environment Checker",
  appVersion: "0.6.0",
  safetyMode: "safe-preview",
  plans: [],
  selectedPath: "",
  rawPlan: "",
  plan: null,
  summary: null,
  log: ["GUI initialized in safe preview mode."],
  reportLocation: "",
  tools: [],
  selectedToolId: "",
};

const sections: Array<{ id: SectionId; label: string }> = [
  { id: "dashboard", label: "Dashboard" },
  { id: "environment", label: "Environment Check" },
  { id: "toolCatalog", label: "Tool Catalog" },
  { id: "plan", label: "Install Plan Viewer" },
  { id: "policy", label: "Policy / Risk Review" },
  { id: "dryrun", label: "Dry Run / Simulate" },
  { id: "logs", label: "Logs" },
  { id: "reports", label: "Reports" },
  { id: "settings", label: "Settings" },
];

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
  appendLog("Running safe CLI validation.");
  const result = await validatePlan(state.selectedPath);
  appendLog(formatRunnerResult(result.stdout, result.stderr));
}

async function runSimulate(): Promise<void> {
  if (!state.selectedPath || !state.plan) return;
  try {
    appendLog("Running safe CLI simulation.");
    const result = await simulatePlan(state.selectedPath, state.plan);
    appendLog(formatRunnerResult(result.stdout, result.stderr));
    if (result.reportPath) state.reportLocation = result.reportPath;
  } catch (error) {
    appendLog(`Simulation blocked: ${formatError(error)}`);
  }
}

async function runDryRun(): Promise<void> {
  if (!state.selectedPath || !state.plan) return;
  try {
    appendLog("Running safe CLI dry-run.");
    const result = await dryRunPlan(state.selectedPath, state.plan);
    appendLog(formatRunnerResult(result.stdout, result.stderr));
    if (result.reportPath) state.reportLocation = result.reportPath;
  } catch (error) {
    appendLog(`Dry-run blocked: ${formatError(error)}`);
  }
}

async function runToolDetectionPreview(): Promise<void> {
  appendLog("Running tool detection preview. No detection commands are executed by the GUI.");
  try {
    const output = await previewToolDetection();
    appendLog(output);
  } catch (error) {
    appendLog(`Tool detection preview failed: ${formatError(error)}`);
  }
}

async function runToolPlanPreview(toolId: string): Promise<void> {
  appendLog(`Loading dry-run plan preview for tool: ${toolId}`);
  try {
    const output = await previewToolPlan(toolId);
    appendLog(output);
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

function badge(text: string, tone: "ok" | "warn" | "blocked" | "neutral" = "neutral"): string {
  return `<span class="badge ${tone}">${escapeHtml(text)}</span>`;
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
  const app = document.querySelector<HTMLDivElement>("#app");
  if (!app) return;

  app.innerHTML = `
    <aside class="sidebar">
      <div class="brand">
        <div class="brand-mark">AI</div>
        <div>
          <h1>${escapeHtml(state.appName)}</h1>
          <p>v${escapeHtml(state.appVersion)} desktop MVP</p>
        </div>
      </div>
      <nav>${sections
        .map(
          (section) =>
            `<button class="nav-item ${section.id === state.section ? "active" : ""}" data-section="${section.id}">${section.label}</button>`,
        )
        .join("")}</nav>
    </aside>
    <main class="workspace">
      <header class="topbar">
        <div>
          <p class="eyebrow">Safe preview version</p>
          <h2>${sections.find((section) => section.id === state.section)?.label ?? "Dashboard"}</h2>
        </div>
        <div class="status-row">
          ${badge("Real install disabled", "blocked")}
          ${badge("Dry-run allowed", "ok")}
          ${badge("Admin disabled", "warn")}
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
    case "dryrun":
      return renderDryRun();
    case "logs":
      return renderLogs();
    case "reports":
      return renderReports();
    case "settings":
      return renderSettings();
  }
}

function renderDashboard(): string {
  const summary = state.summary;
  return `
    <section class="panel-grid">
      <article class="panel">
        <h3>Safety model</h3>
        <p>The v0.6.0 GUI is a preview interface around the v0.5.0 Go CLI runner. It can load, validate, simulate, and dry-run plans, but cannot perform real installation or repair.</p>
        <div class="badge-row">
          ${badge("No UAC", "neutral")}
          ${badge("No PATH edits", "neutral")}
          ${badge("No global env edits", "neutral")}
          ${badge("No confirm run", "blocked")}
        </div>
      </article>
      <article class="panel">
        <h3>Current plan</h3>
        ${
          summary
            ? `<dl class="summary-list">
                <dt>ID</dt><dd>${escapeHtml(summary.id)}</dd>
                <dt>Risk</dt><dd>${badge(summary.riskLevel, summary.blockedInGui ? "blocked" : "ok")}</dd>
                <dt>Commands</dt><dd>${summary.commandCount}</dd>
                <dt>Requires admin</dt><dd>${summary.requiresAdmin ? "Yes" : "No"}</dd>
              </dl>`
            : `<p>No install plan loaded yet. Open Install Plan Viewer to load an example plan.</p>`
        }
      </article>
    </section>
  `;
}

function renderEnvironment(): string {
  return `
    <section class="panel">
      <h3>Environment check target</h3>
      <p>This screen is reserved for ` + "`ai-local-deploy doctor`" + ` output. v0.6.0 keeps the check-only posture and does not repair or install missing tools.</p>
      <button class="primary" id="doctor-button">Run doctor manually later</button>
    </section>
  `;
}

function renderPlanViewer(): string {
  const options = state.plans
    .map((plan) => `<option value="${escapeHtml(plan.path)}" ${plan.path === state.selectedPath ? "selected" : ""}>${escapeHtml(plan.name)}</option>`)
    .join("");

  return `
    <section class="split">
      <article class="panel">
        <h3>Example install plan</h3>
        <label class="field">
          <span>Plan file</span>
          <select id="plan-select">
            <option value="">Select an example plan</option>
            ${options}
          </select>
        </label>
        ${state.summary ? renderSummaryDetails(state.summary) : "<p>Select a plan to inspect its summary, commands, and policy gates.</p>"}
      </article>
      <article class="panel">
        <h3>Commands</h3>
        ${renderCommands()}
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
          <h3>Supported tools</h3>
          <button class="secondary" id="tool-detect-button">Run detection preview</button>
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
        <h3>Details</h3>
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
      <dt>Install</dt><dd>${summary.installDisabled ? "Disabled in v0.6.1" : "Unavailable"}</dd>
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
              <small>${escapeHtml(command.platform)} · ${escapeHtml(command.shell)} · risk=${escapeHtml(command.riskLevel)}</small>
            </div>
          `,
        )
        .join("")}
    </div>
    <h3>Security warnings</h3>
    <ul class="reason-list">${tool.securityWarnings.map((warning) => `<li>${escapeHtml(warning)}</li>`).join("")}</ul>
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
      <dt>GUI status</dt><dd>${summary.blockedInGui ? "Blocked for simulate/dry-run" : "Allowed for simulate/dry-run"}</dd>
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
              <small>requiresAdmin=${Boolean(command.requiresAdmin)} · confirmationRequired=${Boolean(command.confirmationRequired)}</small>
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
      <h3>Policy / risk review</h3>
      <p>v0.6.0 blocks MEDIUM, HIGH, and DANGEROUS plans, blocks admin plans, and never calls ` + "`plan run --confirm`" + `.</p>
      ${
        reasons.length
          ? `<ul class="reason-list">${reasons.map((reason) => `<li>${escapeHtml(reason)}</li>`).join("")}</ul>`
          : `<p class="empty-state">No blocking reason for the loaded plan. Only simulate and dry-run remain available.</p>`
      }
    </section>
  `;
}

function renderDryRun(): string {
  const disabled = state.selectedPath ? "" : "disabled";
  return `
    <section class="panel">
      <h3>Dry-run and simulate</h3>
      <p>These controls call the Go CLI in safe modes only. Real installation, repair, PATH changes, elevation, and confirm execution are not wired in this GUI.</p>
      <div class="actions">
        <button class="secondary" id="validate-button" ${disabled}>Validate plan</button>
        <button class="secondary" id="simulate-button" ${disabled}>Simulate plan</button>
        <button class="primary" id="dryrun-button" ${disabled}>Dry-run plan</button>
      </div>
    </section>
  `;
}

function renderLogs(): string {
  return `
    <section class="panel log-panel">
      <h3>Logs</h3>
      <pre>${escapeHtml(state.log.join("\n\n"))}</pre>
    </section>
  `;
}

function renderReports(): string {
  return `
    <section class="panel">
      <h3>Reports</h3>
      <p>Report path: <code>${escapeHtml(state.reportLocation || "No report generated in this session.")}</code></p>
      <p>Generated reports are local artifacts and must not be committed unless they are sanitized examples.</p>
    </section>
  `;
}

function renderSettings(): string {
  return `
    <section class="panel">
      <h3>Settings</h3>
      <dl class="summary-list">
        <dt>Safety mode</dt><dd>${escapeHtml(state.safetyMode)}</dd>
        <dt>CLI integration</dt><dd>Safe backend adapter, dry-run and simulate only</dd>
        <dt>Install execution</dt><dd>Disabled in v0.6.0</dd>
        <dt>Admin elevation</dt><dd>Not implemented</dd>
      </dl>
    </section>
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

  document.querySelector<HTMLButtonElement>("#validate-button")?.addEventListener("click", () => void runValidate());
  document.querySelector<HTMLButtonElement>("#simulate-button")?.addEventListener("click", () => void runSimulate());
  document.querySelector<HTMLButtonElement>("#dryrun-button")?.addEventListener("click", () => void runDryRun());
  document.querySelector<HTMLButtonElement>("#doctor-button")?.addEventListener("click", () => {
    appendLog("Doctor command adapter is documented for v0.6.0; UI execution will be expanded in v0.7.0.");
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
    state.appVersion = info.version;
    state.safetyMode = info.safetyMode;
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
