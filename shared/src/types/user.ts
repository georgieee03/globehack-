export type UserRole = "client" | "practitioner" | "admin";

export interface UserRecord {
  id: string;
  clinic_id: string;
  role: UserRole;
  email: string | null;
  full_name: string;
  phone: string | null;
  date_of_birth: string | null;
  auth_provider: string | null;
  avatar_url: string | null;
  created_at: string;
  updated_at: string;
}
