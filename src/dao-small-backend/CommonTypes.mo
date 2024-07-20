module {
    public type PagedResult<T> = {
        data : [T];
        offset : Nat;
        count : Nat;
        // isNext : Bool; // TODO
        // totalItems : ?Nat;
    };

    public type CommonResult = {
        #ok;
        #err : Text;
    };

    public type ProposalContent = {
        #codeUpdate : {
            description : Text;
            wasmModule : Blob;
        };
        #transferFunds : {
            amount : Nat;
            recipient : Principal;
            purpose : {
                #toFund : Text; // e.g., "Rewards Fund", "Development Fund"
                #grantPayment : Text; // Description or ID of the grant
                #serviceBill : Text; // Description of the service or bill ID
            };
        };
        #adjustParameters : {
            parameterName : Text;
            newValue : Text;
            description : Text;
        };
        #other : {
            description : Text;
            action : Text;
        };
    };
};
