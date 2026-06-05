import { describe, expect, it } from "vitest";
import { buildToolSummary, type ToolManifest } from "./toolCatalogClient";

describe("toolCatalogClient", () => {
  it("builds a safe GUI summary for a template-only agent tool", () => {
    const manifest: ToolManifest = {
      id: "hermes-agent",
      displayName: "Hermes Agent",
      category: "agent-tool",
      description: "Template-only agent setup.",
      supportedPlatforms: ["windows", "wsl"],
      recommendedInstallMode: "template-only",
      detectionCommands: [],
      installPlanTemplates: [],
      verificationCommands: [],
      requiresAdmin: false,
      riskLevel: "MEDIUM",
      networkRequirements: ["Repository access if configured by the user."],
      proxyRequirements: ["Use configured proxy settings only."],
      securityWarnings: ["Verify source repository before use."],
      notes: ["No automatic installation."],
      docs: [],
      status: "template-only",
    };

    const summary = buildToolSummary(manifest);

    expect(summary.id).toBe("hermes-agent");
    expect(summary.status).toBe("template-only");
    expect(summary.riskLevel).toBe("MEDIUM");
    expect(summary.installDisabled).toBe(true);
  });
});
