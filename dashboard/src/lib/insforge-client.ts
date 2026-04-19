import { createClient } from "@insforge/sdk";

function readEnv(name: string) {
  const processLike = globalThis as { process?: { env?: Record<string, string | undefined> } };
  return processLike.process?.env?.[name] ?? "";
}

const insforgeBaseUrl = readEnv("NEXT_PUBLIC_INSFORGE_URL");
const insforgeAnonKey = readEnv("NEXT_PUBLIC_INSFORGE_ANON_KEY");

const rawClient = createClient({
  baseUrl: insforgeBaseUrl,
  anonKey: insforgeAnonKey,
});

const database = rawClient.database;
const auth = rawClient.auth;

export const insforge = {
  from: database.from.bind(database),
  rpc: database.rpc.bind(database),
  auth: {
    getUser: auth.getCurrentUser.bind(auth),
  },
  functions: rawClient.functions,
  realtime: rawClient.realtime,
};
