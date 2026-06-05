# Report Schema

`core/schema/report.schema.json` supports both current script-generated reports and the future product-oriented report model.

## Supported formats

Current Windows scripts generate reports with uppercase top-level fields. The install flow writes fields such as `Meta`, `Results`, `CommandResults`, `InstallResults`, `Errors`, `Warnings`, and `FixSuggestions`. The verify flow writes fields such as `Meta`, `Status`, `Commands`, `Locations`, and `CommandDetails`.

These formats are supported for backward compatibility because existing users and automation may already consume them.

Future product reports use a lowercase model with fields such as `meta`, `checks`, `installPlan`, `execution`, and `summary`. This shape is intended for the product CLI, desktop UI, and shared report tooling.

## Permissive platform sections

The schema intentionally allows additional properties and optional platform-specific sections. Different operating systems and execution modes may produce different result sections, and a report should not be rejected only because an optional tool section is absent.

Examples are available in:

- `examples/reports/install-report.example.json`
- `examples/reports/verify-report.example.json`
- `examples/reports/product-report.example.json`

## Sensitive data

Reports are local by default, but they may contain usernames, computer names, local paths, proxy settings, command output, and system details. Sensitive fields must be masked or removed before reports are shared outside the local machine.

Do not commit generated reports from `reports/`. Commit only sanitized examples that use fake sample values.

## Local validation

Run the development validation script from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\validate-report-schema.ps1
```

The script checks that the schema and examples are valid JSON and performs lightweight structural checks without installing validator packages, using network access, or modifying files.
