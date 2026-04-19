export interface RecoveryGraphRecord {
  id: string;
  client_id: string;
  clinic_id: string;
  body_region: string;
  metric_type: string;
  value: number;
  source: string;
  source_id: string | null;
  recorded_at: string;
  created_at?: string;
}
