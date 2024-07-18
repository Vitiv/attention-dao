import Principal "mo:base/Principal";

module {
    public func getBalance(user : Principal) : async Nat {
        let userText = Principal.toText(user);
        // TODO get balance by userText from real ledger
        1;
    };
};
