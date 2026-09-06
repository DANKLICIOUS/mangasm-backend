import { createClient } from "@supabase/supabase-js";

// SupabaseClient defaults its schema generic to "public"; explicitly typing
// the singleton off createClient<any, "ganesh">'s own return type keeps it
// correctly scoped instead of silently widening back to "public".
type GaneshClient = ReturnType<typeof createClient<any, "ganesh">>;

let client: GaneshClient | null = null;

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

// Singleton, schema-scoped to `ganesh` so every `.from()` call below resolves
// against ganesh.* without repeating the schema name at every call site.
export function getServiceClient(): GaneshClient {
  if (client) return client;
  const url = requireEnv("SUPABASE_URL");
  const key = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  client = createClient<any, "ganesh">(url, key, {
    db: { schema: "ganesh" },
    auth: { persistSession: false },
  });
  return client;
}
