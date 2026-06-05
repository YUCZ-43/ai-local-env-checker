# Tool Manifest Schema

Tool manifests are validated by `core/schema/tool-manifest.schema.json`.

Required fields include:

- `id`
- `displayName`
- `category`
- `description`
- `supportedPlatforms`
- `recommendedInstallMode`
- `detectionCommands`
- `installPlanTemplates`
- `verificationCommands`
- `requiresAdmin`
- `riskLevel`
- `networkRequirements`
- `proxyRequirements`
- `securityWarnings`
- `notes`
- `docs`
- `status`

Install plan template links must be `dryRunOnly: true`. Tools with real installation templates should be marked at least `MEDIUM` risk. Third-party agent tools must include supply-chain warnings.
