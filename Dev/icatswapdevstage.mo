import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import ICRC1 "mo:std/ICRC1";
import DIP20 "mo:std/DIP20";
import PlugWallet "mo:std/PlugWallet";
import TokenPriceOracle "mo:std/TokenPriceOracle"; //Implementing internally with ICat Price Feed, Suitable Oracle, or both.

actor BackendCanister {
    private let icatToken: DIP20.DIP20 = actor "vb2gd-xiaaa-aaaar-qac5q-cai";
    private let mcsToken: ICRC1.ICRC1 = actor "67mu5-maaaa-aaaar-qadca-cai";
    private let plugWalletInterface: PlugWallet.PlugWallet = actor "plugwallet.ooo";
    private let priceOracle: TokenPriceOracle.TokenPriceOracle = actor "oracle-canister-id"; 

    private var isSwapLocked: Bool = false;
    private var lastFailedSwap: ?SwapRequest = null;
    private var swapHistory: [SwapRequest] = [];

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

    public func swapICATwithMCS(request: SwapRequest) : async Result.Result<Bool, Text> {
        if (!startSwap()) {
            return Result.Err("Swap operation is currently locked. Please try again later.");
        }

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
                        return Result.Ok(true); 
                    };
                    case _ {
                        lastFailedSwap := ?request;
                        return Result.Err("MCS Token transfer failed");
                    };
                };
            };
            case _ { 
                lastFailedSwap := ?request;
                endSwap();
                return Result.Err("ICAT Token transfer failed"); 
            };
        };
    };

    private func calculateSwapAmount(amount: Nat, icatPrice: Nat, mcsPrice: Nat): Nat {
        let icatValue = amount * icatPrice;
        return icatValue / mcsPrice; 
    };

    public func fallback() : async Result.Result<Bool, Text> {
        switch (lastFailedSwap) {
            case (?request) {
                if (request.fromToken == icatToken) {
                    let refundResult = await icatToken.transfer(request.user, request.amount);
                    switch (refundResult) {
                        case (#ok(_)) { lastFailedSwap := null; return Result.Ok(true); };
                        case _ { return Result.Err("Refund of ICAT tokens failed"); };
                    };
                }
                lastFailedSwap := null;
                return Result.Ok(true);
            };
            case null {
                return Result.Err("No recent failed swap to handle.");
            };
        };
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
}
