# ICatSwap Overview

This will code bridge the gap between DIP20 and ICRC-1 token standards, specifically for DIP20 $ICAT and $MCS tokens. It will include features for accurate price action and token swaps based on current comparative prices.

Features

DIP20 and ICRC-1 Token Support: Integration of $ICAT (DIP20) and $MCS (ICRC-1) tokens.
Price-Based Token Swapping: Tokens are swapped based on their current price relative to one another.
Plug Wallet Integration: Users can interact with the AMM through the Plug Wallet extension. Removed for now.
Prerequisites

Internet Computer Protocol (ICP) SDK
Node.js and npm
DFINITY Canister SDK (dfx)
Plug Wallet browser extension

Usage

Interacting with the AMM:
Ensure the Plug Wallet extension is installed and set up in your browser.
Interact with the AMM through the provided frontend interface or directly via the command line.
Token Swapping:
The AMM backend canister allows swapping between $ICAT and $MCS tokens.
Swap actions are based on the current relative prices of these tokens.
Querying Balances and Making Transactions:
Use the an API to query balances and initiate transactions.

Connecting to Plug Wallet:
Use the window.ic.plug.requestConnect() method to connect to Plug Wallet.
Ensure proper handling of mobile and desktop environments as per Plug Wallet's documentation.
Making Calls to Canisters:
Utilize the createActor method for safe interactions with the AMM canister.

Support

For any issues or contributions, please open an issue or pull request in the repository. For detailed guidance on the Plug Wallet integration, refer to the official Plug documentation.

License

This project is licensed under the Apache License 2.0.
