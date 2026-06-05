import { getReportLocation } from "./runnerClient";

export interface ReportPreview {
  location: string;
  message: string;
}

export async function loadReportPreview(): Promise<ReportPreview> {
  const location = await getReportLocation();
  return {
    location,
    message:
      "Reports are generated locally by safe simulate or dry-run actions. Review report contents before sharing.",
  };
}
