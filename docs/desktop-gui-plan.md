# Desktop GUI Plan

The future desktop GUI will use Tauri.

## Screens

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

## MVP behavior

The desktop app should start with read-only checks and local report display. Install and repair execution should wait until the install-plan, policy, runner, logging, and confirmation model is implemented.

## Integration

The GUI should call core contracts rather than shelling out directly from UI components. PowerShell and Bash remain the platform execution layer behind detector and runner boundaries.
