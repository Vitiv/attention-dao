import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

module {
    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    public type Subaccount = Blob;

    public type Balance = Nat;

    public func getBalance(user : Principal) : async Nat {
        let userText = Principal.toText(user);
        Debug.print("Ledger.getBalance: " # userText);
        // TODO get balance by userText from real ledger
        1;
    };
    public func transfer(to : Principal, amount : Nat) : async Bool {
        let minter = Principal.fromText("aaaaa-aa");
        // TODO transfer from user to user
        // let result - transfer_icrc1(minter, to, amount);
        true;
    };

};
