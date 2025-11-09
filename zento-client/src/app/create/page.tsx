import { Suspense } from 'react';
import CreateMarket from "../../components/CreateMarket";

export default function CreatePage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gradient-to-br from-[#232328] via-[#1a1a1f] to-[#0f0f14] flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-8 h-8 border-4 border-[#d5a514] border-t-transparent rounded-full animate-spin"></div>
        </div>
      </div>
    }>
      <CreateMarket />
    </Suspense>
  );
}