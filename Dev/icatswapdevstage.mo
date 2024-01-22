import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import ICRC1 "mo:std/ICRC1";
import DIP20 "mo:std/DIP20";
import PlugWallet "mo:std/PlugWallet";
import TokenPriceOracle "mo:std/TokenPriceOracle"; // Replacing with real oracle or ICAT price feed + external validation.
import BigNat "mo:base/BigNat";
import Time "mo:base/Time";

actor BackendCanister {
    private let icatToken: DIP20.DIP20 = actor "vb2gd-xiaaa-aaaar-qac5q-cai";
    private let mcsToken: ICRC1.ICRC1 = actor "67mu5-maaaa-aaaar-qadca-cai";
    private let plugWalletInterface: PlugWallet.PlugWallet = actor "plugwallet.ooo";
    private let priceOracle: TokenPriceOracle.TokenPriceOracle = actor "oracle-canister-id";

    private var isSwapLocked: Bool = false;
    private var swapHistory: [SwapRequest] = [];
    private var rateLimitTracker: [(Principal, Int64)] = []; // Tracks user requests for rate limiting

    public type SwapRequest = {
        fromToken: Principal;
        toToken: Principal;
        amount: Nat;
        user: Principal;
    };

    private func startSwap() : Bool {
        if (isSwapLocked) {
            return false;
        }
        isSwapLocked := true;
        return true;
    }

    private func endSwap() : () {
        isSwapLocked := false;
    }

    private func isRateLimited(user: Principal) : Bool {
        let currentTime = Time.now();
        let limitWindow = 60 * 60 * 1000; // 1 hour in milliseconds
        let maxRequests = 5; // Max requests per user per hour

        rateLimitTracker := rateLimitTracker.filter((item) => (currentTime - item.1) < limitWindow);
        let userRequests = rateLimitTracker.filter((item) => item.0 == user);

        return userRequests.size() >= maxRequests;
    }

    private func updateRateLimitTracker(user: Principal) : () {
        rateLimitTracker := Array.append(rateLimitTracker, [(user, Time.now())]);
    }

    public func swapICATwithMCS(request: SwapRequest) : async Result.Result<Bool, Text> {
        if (!startSwap()) {
            return Result.Err("Swap operation is currently locked. Please try again later.");
        }

        if (isRateLimited(request.user)) {
            endSwap();
            return Result.Err("Rate limit exceeded. Please try again later.");
        }

        try {
            assert(request.fromToken == icatToken && request.toToken == mcsToken, "Invalid token addresses for swap");

            let icatPrice = await priceOracle.getPrice(icatToken);
            let mcsPrice = await priceOracle.getPrice(mcsToken);

            assert(icatPrice > 0 && mcsPrice > 0, "Unable to fetch token prices");

            let transferResult = await icatToken.transferFrom(request.user, this, request.amount);
            switch (transferResult) {
                case (#ok(_)) {
                    let swapAmount = calculateSwapAmount(request.amount, icatPrice, mcsPrice);
                    let sendResult = await mcsToken.transfer(request.user, swapAmount);
                    endSwap();
                    switch (sendResult) {
                        case (#ok(_)) {
                            swapHistory := Array.append(swapHistory, [request]);
                            updateRateLimitTracker(request.user);
                            return Result.Ok(true); 
                        };
                        case _ { throw "MCS Token transfer failed"; };
                    };
                };
                case _ { throw "ICAT Token transfer failed"; };
            };
        } catch (error) {
            endSwap();
            return Result.Err(error);
        };
    };

    private func calculateSwapAmount(amount: Nat, icatPrice: Nat, mcsPrice: Nat): Nat {
        let icatValue = BigNat.fromNat(amount) * BigNat.fromNat(icatPrice);
        return BigNat.toNat(icatValue / BigNat.fromNat(mcsPrice)); // Precision handling
    };

    public func calculateReceiveAmount(inputAmount: Nat, fromToken: Principal, toToken: Principal) : async Result.Result<Nat, Text> {
        if (fromToken != icatToken || toToken != mcsToken) {
            return Result.Err("Invalid token addresses");
        }

        let fromTokenPrice = await priceOracle.getPrice(fromToken);
        let toTokenPrice = await priceOracle.getPrice(toToken);

        if (fromTokenPrice == 0 || toTokenPrice == 0) {
            return Result.Err("Unable to fetch token prices");
        }

        let receiveAmount = (inputAmount * fromTokenPrice) / toTokenPrice;
        return Result.Ok(receiveAmount);
    };

    public func initiateSwapWithPlug(request: SwapRequest) : async Result.Result<Bool, Text> {
        if (!(await plugWalletInterface.isConnected()) || !(await plugWalletInterface.getPrincipal()) == request.user) {
            return Result.Err("Plug Wallet not connected or user mismatch");
        }
        return swapICATwithMCS(request);
    };

    public func getSwapHistory() : async [SwapRequest] {
        return swapHistory;
    };

    public func getRateLimitStatus(user: Principal) : async Bool {
        return isRateLimited(user);
    };

    // Automated Testing Functions
    public func testCalculateSwapAmount() : async Bool {
        // Example test case
        let testAmount: Nat = 100;
        let testIcatPrice: Nat = 10; // Example price
        let testMcsPrice: Nat = 20; // Example price
        let expectedOutput: Nat = 50;

        let result = calculateSwapAmount(testAmount, testIcatPrice, testMcsPrice);
        assert(result == expectedOutput, "Test failed: Incorrect swap amount calculation");

        return true;
    };

    // Additional utility functions needed.
}
