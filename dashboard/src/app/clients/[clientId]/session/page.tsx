import { SessionWorkspace } from "@/components/session/SessionWorkspace";

interface SessionPageProps {
  params: { clientId: string };
}

export default function SessionPage({ params }: SessionPageProps) {
  return <SessionWorkspace clientId={params.clientId} />;
}
