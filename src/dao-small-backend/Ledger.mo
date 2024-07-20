import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

module {
    public func getBalance(user : Principal) : async Nat {
        let userText = Principal.toText(user);
        Debug.print("Ledger.getBalance: " # userText);
        // TODO get balance by userText from real ledger
        1;
    };
};
