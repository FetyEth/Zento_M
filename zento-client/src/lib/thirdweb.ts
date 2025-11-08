import { createThirdwebClient } from "thirdweb";
import { bscTestnet } from "thirdweb/chains";
import { inAppWallet, createWallet } from "thirdweb/wallets";

export const client = createThirdwebClient({
  clientId: process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID!,
});


export const wallets = [
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

export const chain = bscTestnet;