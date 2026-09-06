export type Severity = "INFO" | "WARNING" | "CRITICAL";

export interface SignalInput {
  source: string;
  external_id: string;
  event_type: string;
  severity: Severity;
  payload: Record<string, unknown>;
}

export interface CollectorResult {
  source: string;
  ok: boolean;
  signalsIngested: number;
  error?: string;
}
