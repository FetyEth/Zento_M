"use client";
import { ConnectButton } from "thirdweb/react";
import { client, chain } from "@/lib/thirdweb";
import { createWallet, inAppWallet } from "thirdweb/wallets";

export default function ConnectWalletButton() {
  const wallets = [
    // In-App Wallet 
    inAppWallet({
      auth: {
        options: [
          "email",
          "google",
          "apple",
          "facebook",
          "phone",
          "passkey", 
        ],
      },
    }),
    // Traditional wallet options
    createWallet("io.metamask"),
    createWallet("com.coinbase.wallet"),
    createWallet("me.rainbow"),
    createWallet("walletConnect"),
  ];

  return (
    <ConnectButton
      client={client}
      chain={chain}
      wallets={wallets}
      connectButton={{
        label: "Connect Wallet",
      }}
      accountAbstraction={{
        chain: chain,
        sponsorGas: true, 
      }}
    />
  );
}