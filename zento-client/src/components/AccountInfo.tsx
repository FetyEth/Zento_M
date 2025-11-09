// Internal components
import { LabelValueGrid, DisplayValue } from "@/components/LabelValueGrid";
import { useActiveAccount } from "thirdweb/react";

export function AccountInfo() {
  const account = useActiveAccount();
  return (
    <div className="flex flex-col gap-6">
      <h4 className="text-lg font-medium">Account Info</h4>
      <LabelValueGrid
        items={[
          {
            label: "Address",
            value: (
              <DisplayValue value={account?.address.toString() ?? "Not Present"} isCorrect={!!account?.address} />
            ),
          },
        ]}
      />
    </div>
  );
}
