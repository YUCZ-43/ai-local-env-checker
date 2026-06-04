# Architecture

## 1. Current detection layer

The current detection layer uses platform-native scripts:

- Windows: PowerShell
- WSL/Linux/macOS: Bash

This keeps the current version transparent and easy to inspect. The scripts run local commands, apply timeouts, and write local reports.

## 2. Why scripts remain useful

Scripts remain useful because they provide:

- Direct system access
- Easy troubleshooting
- Transparent commands
- No compiled binary requirement

For early diagnostic tooling, transparency is important. Users and technicians can inspect the exact checks before running them.

## 3. Why future CLI may use Go

Go is a strong candidate for a future unified CLI because it provides:

- Single binary distribution
- Cross-platform builds
- Easy release packaging
- Good fit for customer diagnostics

A Go CLI can provide one entry point while still calling existing scripts during migration.

## 4. Why Rust may be considered

Rust may be considered for selected components because it provides:

- Strong safety guarantees
- High performance
- Good cross-platform support

Rust can also increase development complexity, so it may be better for later versions or for components that benefit from strict memory and type safety.

## 5. Why Python may be considered

Python may be considered for automation and report tooling because it provides:

- Fast development
- Rich ecosystem
- Good text, JSON, and HTML processing libraries

Python packaging can be heavier for end users, especially on machines that do not already have Python installed.

## 6. Why Tauri may be considered

Tauri may be considered for a future desktop GUI because it provides:

- Lightweight desktop applications
- Cross-platform GUI support
- Ability to call local scripts or a Go/Rust backend

A Tauri GUI can provide a local-first interface for running checks, reviewing reports, and exporting sanitized diagnostic output.

## 7. Suggested future architecture

Core:

- Platform detection engine
- Proxy detection engine
- Command runner
- Report writer
- Localization engine

Interfaces:

- PowerShell/Bash scripts
- Go CLI
- Tauri GUI
- Optional web dashboard

Reports:

- JSON
- Markdown
- Future HTML

Backend:

- Optional only
- Membership and licensing
- Must not be required for offline local checks

Any future backend or upload feature must require explicit user consent.
