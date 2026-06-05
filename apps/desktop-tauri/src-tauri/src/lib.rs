use serde::{Deserialize, Serialize};
use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AppInfo {
    name: String,
    version: String,
    safety_mode: String,
}

#[derive(Debug, Serialize)]
struct ExamplePlanInfo {
    name: String,
    path: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RunnerResult {
    ok: bool,
    mode: String,
    stdout: String,
    stderr: String,
    report_path: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ToolManifest {
    id: String,
    display_name: String,
    category: String,
    description: String,
    supported_platforms: Vec<String>,
    recommended_install_mode: String,
    detection_commands: Vec<serde_json::Value>,
    install_plan_templates: Vec<serde_json::Value>,
    verification_commands: Vec<serde_json::Value>,
    requires_admin: bool,
    risk_level: String,
    network_requirements: Vec<String>,
    proxy_requirements: Vec<String>,
    security_warnings: Vec<String>,
    notes: Vec<String>,
    docs: Vec<serde_json::Value>,
    status: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct InstallPlan {
    id: String,
    #[serde(default)]
    commands: Vec<InstallCommand>,
    #[serde(default)]
    requires_admin: bool,
    risk_level: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct InstallCommand {
    id: String,
    #[serde(default)]
    requires_admin: bool,
    #[serde(default)]
    risk_level: String,
}

#[tauri::command]
fn get_app_info() -> AppInfo {
    AppInfo {
        name: "AI Local Environment Checker".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        safety_mode: "safe-preview".to_string(),
    }
}

#[tauri::command]
fn list_example_plans() -> Result<Vec<ExamplePlanInfo>, String> {
    let root = repo_root()?;
    let plan_dir = root.join("examples").join("install-plans");
    let mut plans = Vec::new();

    for entry in fs::read_dir(&plan_dir).map_err(|err| format!("read example plans: {err}"))? {
        let entry = entry.map_err(|err| format!("read example plan entry: {err}"))?;
        let path = entry.path();
        if path.extension().and_then(|value| value.to_str()) == Some("json") {
            plans.push(ExamplePlanInfo {
                name: path
                    .file_name()
                    .and_then(|value| value.to_str())
                    .unwrap_or("install-plan.json")
                    .to_string(),
                path: path.to_string_lossy().to_string(),
            });
        }
    }

    plans.sort_by(|left, right| left.name.cmp(&right.name));
    Ok(plans)
}

#[tauri::command]
fn read_plan(path: String) -> Result<String, String> {
    let safe_path = canonical_example_plan_path(&path)?;
    fs::read_to_string(&safe_path).map_err(|err| format!("read install plan: {err}"))
}

#[tauri::command]
fn validate_plan(path: String) -> Result<RunnerResult, String> {
    let safe_path = canonical_example_plan_path(&path)?;
    run_cli("validate", &["plan", "validate", "--file", safe_path.to_string_lossy().as_ref()])
}

#[tauri::command]
fn simulate_plan(path: String) -> Result<RunnerResult, String> {
    let safe_path = canonical_example_plan_path(&path)?;
    assert_safe_preview_plan(&safe_path)?;
    run_cli("simulate", &["plan", "simulate", "--file", safe_path.to_string_lossy().as_ref()])
}

#[tauri::command]
fn dry_run_plan(path: String) -> Result<RunnerResult, String> {
    let safe_path = canonical_example_plan_path(&path)?;
    assert_safe_preview_plan(&safe_path)?;
    run_cli(
        "dry-run",
        &[
            "plan",
            "run",
            "--file",
            safe_path.to_string_lossy().as_ref(),
            "--dry-run",
        ],
    )
}

#[tauri::command]
fn get_report_location() -> Result<String, String> {
    Ok(repo_root()?
        .join("reports")
        .to_string_lossy()
        .to_string())
}

#[tauri::command]
fn list_tool_catalog() -> Result<Vec<ToolManifest>, String> {
    let root = repo_root()?;
    let catalog_dir = root.join("core").join("tool-catalog");
    let mut tools = Vec::new();
    for entry in fs::read_dir(&catalog_dir).map_err(|err| format!("read tool catalog: {err}"))? {
        let entry = entry.map_err(|err| format!("read tool catalog entry: {err}"))?;
        let path = entry.path();
        if path.extension().and_then(|value| value.to_str()) == Some("json") {
            let raw = fs::read_to_string(&path).map_err(|err| format!("read tool manifest: {err}"))?;
            let tool: ToolManifest =
                serde_json::from_str(&raw).map_err(|err| format!("parse tool manifest: {err}"))?;
            tools.push(tool);
        }
    }
    tools.sort_by(|left, right| left.id.cmp(&right.id));
    Ok(tools)
}

#[tauri::command]
fn preview_tool_detection() -> Result<String, String> {
    let result = run_cli("tools-detect", &["tools", "detect", "--dry-run"])?;
    Ok(format_runner_text(result))
}

#[tauri::command]
fn preview_tool_plan(tool_id: String) -> Result<String, String> {
    let result = run_cli("tools-plan", &["tools", "plan", "--id", &tool_id, "--dry-run"])?;
    Ok(format_runner_text(result))
}

fn repo_root() -> Result<PathBuf, String> {
    let mut candidates = Vec::new();
    if let Ok(current_dir) = std::env::current_dir() {
        candidates.push(current_dir);
    }
    candidates.push(PathBuf::from(env!("CARGO_MANIFEST_DIR")));
    candidates.push(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("..").join(".."));

    for candidate in candidates {
        if let Some(root) = find_repo_root_from(&candidate) {
            return Ok(root);
        }
    }

    Err("repository root not found".to_string())
}

fn find_repo_root_from(start: &Path) -> Option<PathBuf> {
    let mut cursor = start.canonicalize().ok()?;
    loop {
        if cursor
            .join("core")
            .join("schema")
            .join("install-plan.schema.json")
            .is_file()
        {
            return Some(cursor);
        }
        if !cursor.pop() {
            return None;
        }
    }
}

fn canonical_example_plan_path(path: &str) -> Result<PathBuf, String> {
    let root = repo_root()?;
    let plan_dir = root
        .join("examples")
        .join("install-plans")
        .canonicalize()
        .map_err(|err| format!("resolve example plan directory: {err}"))?;
    let requested = PathBuf::from(path)
        .canonicalize()
        .map_err(|err| format!("resolve install plan path: {err}"))?;

    if !requested.starts_with(&plan_dir) {
        return Err("install plan must be under examples/install-plans".to_string());
    }
    if requested.extension().and_then(|value| value.to_str()) != Some("json") {
        return Err("install plan must be a JSON file".to_string());
    }
    Ok(requested)
}

fn assert_safe_preview_plan(path: &Path) -> Result<(), String> {
    let raw = fs::read_to_string(path).map_err(|err| format!("read install plan: {err}"))?;
    let plan: InstallPlan =
        serde_json::from_str(&raw).map_err(|err| format!("parse install plan JSON: {err}"))?;
    let plan_risk = normalize_risk(&plan.risk_level);

    if blocked_risk(&plan_risk) {
        return Err(format!(
            "plan {} risk level {} is blocked in the v0.7.0 installer preview",
            plan.id, plan_risk
        ));
    }
    if plan.requires_admin {
        return Err(format!(
            "plan {} requires admin privileges, which are disabled in the v0.7.0 installer preview",
            plan.id
        ));
    }

    for command in plan.commands {
        let command_risk = if command.risk_level.trim().is_empty() {
            plan_risk.clone()
        } else {
            normalize_risk(&command.risk_level)
        };
        if blocked_risk(&command_risk) {
            return Err(format!(
                "command {} risk level {} is blocked in the v0.7.0 installer preview",
                command.id, command_risk
            ));
        }
        if command.requires_admin {
            return Err(format!(
                "command {} requires admin privileges, which are disabled in the v0.7.0 installer preview",
                command.id
            ));
        }
    }

    Ok(())
}

fn normalize_risk(risk: &str) -> String {
    risk.trim().to_ascii_uppercase()
}

fn blocked_risk(risk: &str) -> bool {
    matches!(risk, "MEDIUM" | "HIGH" | "DANGEROUS")
}

fn run_cli(mode: &str, args: &[&str]) -> Result<RunnerResult, String> {
    let root = repo_root()?;
    let cli_dir = root.join("apps").join("cli-go");
    let output = if let Some(bundled_bin) = bundled_cli_binary() {
        Command::new(bundled_bin).args(args).current_dir(&root).output()
    } else if let Some(configured_bin) = configured_cli_binary() {
        Command::new(configured_bin).args(args).current_dir(&root).output()
    } else if let Some(local_bin) = local_cli_binary(&cli_dir) {
        Command::new(local_bin).args(args).current_dir(&root).output()
    } else {
        Command::new("go")
            .args(["run", "."])
            .args(args)
            .current_dir(&cli_dir)
            .output()
    }
    .map_err(|err| format!("run ai-local-deploy CLI: {err}"))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    let report_path = extract_report_path(&stdout);

    Ok(RunnerResult {
        ok: output.status.success(),
        mode: mode.to_string(),
        stdout,
        stderr,
        report_path,
    })
}

fn bundled_cli_binary() -> Option<PathBuf> {
    let file_name = if cfg!(windows) {
        "ai-local-deploy.exe"
    } else {
        "ai-local-deploy"
    };
    let exe_dir = std::env::current_exe().ok()?.parent()?.to_path_buf();
    [
        exe_dir.join(file_name),
        exe_dir.join("bin").join(file_name),
        exe_dir.join("resources").join(file_name),
        exe_dir.join("resources").join("bin").join(file_name),
    ]
    .into_iter()
    .find(|path| path.is_file())
}

fn configured_cli_binary() -> Option<PathBuf> {
    std::env::var("AI_LOCAL_DEPLOY_BIN")
        .ok()
        .map(PathBuf::from)
        .filter(|path| path.is_file())
}

fn local_cli_binary(cli_dir: &Path) -> Option<PathBuf> {
    let exe = cli_dir.join(if cfg!(windows) {
        "ai-local-deploy.exe"
    } else {
        "ai-local-deploy"
    });
    exe.is_file().then_some(exe)
}

fn extract_report_path(stdout: &str) -> Option<String> {
    stdout
        .lines()
        .find_map(|line| line.strip_prefix("report written: "))
        .map(|value| value.trim().to_string())
}

fn format_runner_text(result: RunnerResult) -> String {
    [result.stdout.trim(), result.stderr.trim()]
        .into_iter()
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_app_info,
            list_example_plans,
            read_plan,
            validate_plan,
            simulate_plan,
            dry_run_plan,
            get_report_location,
            list_tool_catalog,
            preview_tool_detection,
            preview_tool_plan
        ])
        .run(tauri::generate_context!())
        .expect("error while running Tauri application");
}

#[cfg(test)]
mod tests {
    use super::{blocked_risk, extract_report_path, normalize_risk};

    #[test]
    fn blocks_medium_and_higher_risk_levels() {
        assert!(!blocked_risk("LOW"));
        assert!(blocked_risk("MEDIUM"));
        assert!(blocked_risk("HIGH"));
        assert!(blocked_risk("DANGEROUS"));
    }

    #[test]
    fn normalizes_risk_levels() {
        assert_eq!(normalize_risk(" low "), "LOW");
    }

    #[test]
    fn extracts_report_path_from_cli_output() {
        let output = "simulation complete\nreport written: C:\\repo\\reports\\plan-report.json\n";
        assert_eq!(
            extract_report_path(output),
            Some("C:\\repo\\reports\\plan-report.json".to_string())
        );
    }
}
