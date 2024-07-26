import Text "mo:base/Text";

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

    public type ActionType = {
        #Reaction;
        #Review;
        #Registration;
        #Custom : Text;
    };

    public func textToActionType(text : Text) : ActionType {
        switch (text) {
            case ("reaction" or "Reaction" or "REACTION") #Reaction;
            case ("review" or "Review" or "REVIEW") #Review;
            case ("registration" or "Registration" or "REGISTRATION") #Registration;
            case _ #Custom(text);
        };
    };

    public func actionTypeToString(actionType : ActionType) : Text {
        switch (actionType) {
            case (#Reaction) "reaction";
            case (#Review) "review";
            case (#Registration) "registration";
            case (#Custom(text)) text;
            case _ "unknown";
        };
    };
};
