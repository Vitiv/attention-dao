import DAO "./Dao";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Buffer "mo:base/Buffer";
import CT "./CommonTypes";

module {
  type ProposalContent = CT.ProposalContent;

  public type RejectResult = {
        #ok;
        #err : Text;
    };

    public func rejectProposal(proposal : DAO.Proposal<ProposalContent>) : async* RejectResult {
        try {
            let proposalId = proposal.id;
            let rejectionTime = Time.now();
            
            // 1. Update proposal status to "rejected"
            let updateResult = await* updateProposalStatus(proposalId, #rejected({ time = rejectionTime }));
            if (not updateResult) {
                return #err("Status update failed");
            };

            // 2. Return tokens to proposer
            let returnResult = await* returnTokens(proposalId);
            if (not returnResult) {
                return #err("Tokens return failed");
            };

            // 3. Notify participants
            await* notifyParticipants(proposalId, "Proposal rejected");

           
            // 4. Log the rejection
            Debug.print("Proposal #" # Nat.toText(proposalId) # " rejected at " # Int.toText(rejectionTime));

            #ok
        } catch (e) {
            return #err("Error while rejecting proposal: " # Error.message(e));
        }
    };

// Additional functions

    func updateProposalStatus(proposalId : Nat, status : DAO.ProposalStatusLogEntry) : async* Bool {
        // TODO if additional states are needed
        true
    };

    func returnTokens(proposalId : Nat) : async* Bool {
        // TODO if necessary
        true
    };

    func notifyParticipants(proposalId : Nat, message : Text) : async* () {
        // TODO Notify author if necessary
    };

    func updateReputation(userId : Principal, change : Int) : async* Bool {
        // TODO move to separate integration module
        // create publication for aVa reputation canister with correct namespace 
        true
    };

    func checkDuplicateProposal(content : ProposalContent) : async* Bool {
        // TODO
        false
    };

    func isValidProposalType(action : Text) : Bool {
        // TODO
        true
    };

    func checkComplianceWithDAORules(content : ProposalContent) : async* Bool {
        // TODO
        true
    };

// Validation

    public func validateProposal(content : ProposalContent) : async* Result.Result<(), [Text]> {
        let errorBuffer = Buffer.Buffer<Text>(0);

        // if (Text.size(content.description) < 4 or Text.size(content.description) > 1000) {
        //     errorBuffer.add("Description should be between 4 and 1000 characters");
        // };

        // if (Text.size(content.action) < 4 or Text.size(content.action) > 100) {
        //     errorBuffer.add("Action should be between 4 and 100 characters");
        // };

        // let isDuplicate = await* checkDuplicateProposal(content);
        // if (isDuplicate) {
        //     errorBuffer.add("Duplicate proposal");
        // };

        // if (not isValidProposalType(content.action)) {
        //     errorBuffer.add("Wrong proposal type");
        // };

        let isCompliant = await* checkComplianceWithDAORules(content);
        if (not isCompliant) {
            errorBuffer.add("Proposal violates DAO rules");
        };

        if (errorBuffer.size() > 0) {
            #err(Buffer.toArray(errorBuffer))
        } else {
            #ok()
        };
    };

    func getTokenBalance(userId : Principal) : async* Nat {
        //TODO 
        1
    };



    func getProposerReputation(userId : Principal) : async* Int {
        // TODO aVa reputation integration
        1
    };

}
