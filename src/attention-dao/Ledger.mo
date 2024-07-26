import Principal "mo:base/Principal";
import Nat8 "mo:base/Nat8";
import Result "mo:base/Result";
import Token "mo:icrc1/ICRC1/Canisters/Token";
import Cycles "mo:base/ExperimentalCycles";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

module {
    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    public type Subaccount = Blob;

    public type Balance = Nat;

    public class Ledger() = Self {
        let decimals : Nat8 = 8;
        var token_canister : Token.Token = actor ("aaaaa-aa"); // Placeholder principal, will be updated in createToken
        var minter : Account = {
            owner = Principal.fromText("aaaaa-aa");
            subaccount = null;
        };

        private func add_decimals(n : Nat) : Nat {
            n * 10 ** Nat8.toNat(decimals);
        };

        public func createToken(name : Text, symbol : Text, owner : Text) : async Result.Result<(Nat, Text, Text), Text> {
            let pre_mint_account = {
                owner = Principal.fromText(owner);
                subaccount = null;
            };

            minter := pre_mint_account;

            Cycles.add<system>(30_000_000_000);
            let new_token_canister = await Token.Token({
                name = name;
                symbol = symbol;
                decimals = decimals;
                fee = add_decimals(1);
                max_supply = add_decimals(100_000_000);
                initial_balances = [(pre_mint_account, add_decimals(10_000_000))];
                min_burn_amount = add_decimals(10);
                minting_account = null;
                advanced_settings = null;
            });

            token_canister := new_token_canister;

            let result = await token_canister.icrc1_name();
            if (result == name) {
                let balance = await getBalance(Principal.fromText(owner));
                let ?mint = await token_canister.icrc1_minting_account();
                minter := mint;
                return #ok(balance, name, Principal.toText(minter.owner));
            };
            return #err("Failed to create token");
        };

        public func getBalance(user : Principal) : async Nat {
            await token_canister.icrc1_balance_of({
                owner = user;
                subaccount = null;
            });
        };

        public func get_minting_account() : async Account {
            minter;
        };

        public func transfer(to : Principal, amount : Nat) : async Bool {
            let transferArgs = {
                from_subaccount = null;
                to = {
                    owner = to;
                    subaccount = null;
                };
                amount = amount;
                fee = null;
                memo = null;
                created_at_time = null;
            };
            Debug.print("Ledger.transfer: transferArgs: " # debug_show (transferArgs));
            let result = await token_canister.icrc1_transfer(transferArgs);
            switch (result) {
                case (#Ok(_)) true;
                case (#Err(err)) {
                    Debug.print("Ledger.transfer: Error: " # debug_show (err));
                    false;
                };
            };
        };
    };
};
