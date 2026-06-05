# Desktop Tauri MVP Placeholder

This directory is reserved for the future Tauri desktop GUI.

The current v0.4.x MVP architecture keeps this as documentation and placeholders only. No Node dependencies, Rust target output, generated binaries, or installer artifacts are committed here.

## Future screens

- Dashboard
- System Check
- Problems Found
- Install Plan
- User Confirmation
- Execution Progress
- Report Export
- Advanced Logs
- Settings
- License / Membership

## Safety model

The desktop app will be check-first and plan-first. It must show an install plan and request user confirmation before any repair or install command is executed.

PowerShell and Bash remain the platform execution layer. The desktop app should call the same detector, plan, runner, report, proxy, and policy boundaries used by the CLI.
