import Nat "mo:base/Nat";
import Principal "mo:base/Principal"; // Plug Integration coming soon, see readme.
import Float "mo:stdlib/Float";
import Array "mo:stdlib/Array";
import Option "mo:stdlib/Option";
import Result "mo:stdlib/Result";

import ICAT "ICatToken"; // Change to .mo and method at later date.
import MCS "MCSToken";

actor AMM {

    type LiquidityPool = {
        icat: Nat;
        mcs: Nat;
        lpTokens: Nat
    };

    type LPTokenBalance = {
        owner: Principal;
        balance: Nat;
    };

    private var liquidityPool: LiquidityPool = { icat = 0; mcs = 0; lpTokens = 0 };
    private var lpTokenBalances: [LPTokenBalance] = [];

    public func initializeLiquidity(icatAmount: Nat, mcsAmount: Nat) : async () {
        liquidityPool.icat := icatAmount;
        liquidityPool.mcs := mcsAmount;
        liquidityPool.lpTokens := calculateLPTokens(icatAmount, mcsAmount);
    }

    public func addLiquidity(icatAmount: Nat, mcsAmount: Nat, user: Principal) : async () {
        let lpTokens = calculateLPTokens(icatAmount, mcsAmount);
        liquidityPool.icat += icatAmount;
        liquidityPool.mcs += mcsAmount;
        liquidityPool.lpTokens += lpTokens;
        updateLPTokenBalance(user, lpTokens);
    }

    public func removeLiquidity(lpTokenAmount: Nat, user: Principal) : async () {
        let (icatAmount, mcsAmount) = calculateWithdrawalAmounts(lpTokenAmount);
        liquidityPool.icat -= icatAmount;
        liquidityPool.mcs -= mcsAmount;
        liquidityPool.lpTokens -= lpTokenAmount;
        updateLPTokenBalance(user, -Nat.toInt(lpTokenAmount));
    }

    public func swapICATtoMCS(icatAmount: Nat, user: Principal) : async Nat {
        let mcsAmount = calculateMCSAmount(icatAmount);
        liquidityPool.icat += icatAmount;
        liquidityPool.mcs -= mcsAmount;
        return mcsAmount;
    }

    public func swapMCStoICAT(mcsAmount: Nat, user: Principal) : async Nat {
        let icatAmount = calculateICATAmount(mcsAmount);
        liquidityPool.mcs += mcsAmount;
        liquidityPool.icat -= icatAmount;
        return icatAmount;
    }

    private func calculateLPTokens(icatAmount: Nat, mcsAmount: Nat) : Nat {
        return Float.sqrt(Float.fromNat(icatAmount) * Float.fromNat(mcsAmount)).toNat();
    }

    private func calculateMCSAmount(icatAmount: Nat) : Nat {
        return (icatAmount * liquidityPool.mcs) / liquidityPool.icat;
    }

    private func calculateICATAmount(mcsAmount: Nat) : Nat {
        return (mcsAmount * liquidityPool.icat) / liquidityPool.mcs;
    }

    private func calculateWithdrawalAmounts(lpTokenAmount: Nat) : (Nat, Nat) {
        let icatAmount = (lpTokenAmount * liquidityPool.icat) / liquidityPool.lpTokens;
        let mcsAmount = (lpTokenAmount * liquidityPool.mcs) / liquidityPool.lpTokens;
        return (icatAmount, mcsAmount);
    }

    private func updateLPTokenBalance(user: Principal, delta: Int) {
        let index = Array.findIndex<LPTokenBalance>(lpTokenBalances, func (b) { b.owner == user });
        switch (index) {
            case (?idx): {
                let currentBalance = lpTokenBalances[idx].balance;
                let newBalance = Nat.max(0, Nat.toInt(currentBalance) + delta);
                lpTokenBalances[idx] := { owner = user; balance = newBalance };
            };
            case null: {
                if (delta > 0) {
                    lpTokenBalances.append({ owner = user; balance = Nat.fromInt(delta) });
                };
            };
        };
    }

    public query func getLiquidityPoolState() : LiquidityPool {
        return liquidityPool;
    }

    public query func getLPTokenBalance(user: Principal) : Nat {
        let index = Array.findIndex<LPTokenBalance>(lpTokenBalances, func (b) { b.owner == user });
        switch (index) {
            case (?idx): return lpTokenBalances[idx].balance;
            case null: return 0;
        };
    }
}
// Add price verification, error handling, etc. Fallback function under revision.
