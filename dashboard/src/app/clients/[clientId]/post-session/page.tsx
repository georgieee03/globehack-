import { PostSessionWorkspace } from "@/components/post-session/PostSessionWorkspace";

interface PostSessionPageProps {
  params: { clientId: string };
}

export default function PostSessionPage({ params }: PostSessionPageProps) {
  return <PostSessionWorkspace clientId={params.clientId} />;
}
