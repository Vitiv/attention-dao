import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";

import CommonTypes "./CommonTypes";
import CT "./CommonTypes";
import DAO "./Dao";
import Ledger "./Ledger";
import PH "./ProposalHandler";
import Rewards "./RewardSystem";
import Test "./test";
import RT "./reward.test";

actor {
  
  type ProposalContent = CT.ProposalContent;

  type Member = DAO.Member;

  stable var daoStableData : DAO.StableData<ProposalContent> = {
    proposals = [];
    proposalDuration = #days(7);
    votingThreshold = #percent({ percent = 51; quorum = ?25 });
  };

  stable var membersEntries : [(Principal, Member)] = [];
  var members = HashMap.HashMap<Principal, Member>(10, Principal.equal, Principal.hash);

  system func preupgrade() {
    daoStableData := dao.toStableData();
    membersEntries := Iter.toArray(members.entries());
  };

  system func postupgrade() {
    members := HashMap.fromIter<Principal, Member>(membersEntries.vals(), 10, Principal.equal, Principal.hash);
    membersEntries := [];
  };

  func executeProposal(proposal : DAO.Proposal<CT.ProposalContent>) : async* Result.Result<(), Text> {
    switch (proposal.content) {
        case (#codeUpdate(update)) {
            // Implement code update logic
            #err("Code update not implemented yet")
        };
        case (#transferFunds(transfer)) {
            // Implement fund transfer logic
            let result = await Ledger.transfer(transfer.recipient, transfer.amount);
            switch (result) {
              case (true) { 
                #ok 
                };
              case (false) {
                #err("Fund transfer not implemented yet");
                };
            };
        };
        case (#adjustParameters(adjustment)) {
            // Implement parameter adjustment logic
            #err("Parameter adjustment not implemented yet")
        };
        case (#other(_)) {
          // Handle other proposal types
          #err("Other proposal type not implemented yet")
        }
    };
  };

  func rejectProposal(proposal : DAO.Proposal<ProposalContent>) : async* CT.CommonResult {
    await* PH.rejectProposal(proposal);
  };

  func validateProposal(content : ProposalContent) : async* Result.Result<(), [Text]> {
    // public func validateProposal(content : ProposalContent, proposerId : Principal) : async* Result.Result<(), [Text]> {
    await* PH.validateProposal(content);   
  };

  func getVotingPower(user : Principal) : async* Nat {
    switch (members.get(user)) {
      case (?member) {
        Debug.print("main.getVotingPower: Voting power for " # Principal.toText(user) # ": " # Nat.toText(member.votingPower));
        member.votingPower
      };
      case null {
        Debug.print("main.getVotingPower: Member not found for " # Principal.toText(user) # ". Returning 0 voting power.");
        0
      };
    }
    //await Ledger.getBalance(user);
  };


  let dao = DAO.Dao<system, ProposalContent>(
    daoStableData,
    executeProposal,
    rejectProposal,
    validateProposal,
    getVotingPower,
  );

  // Функции управления членством

  public shared(msg) func addMember(id: Principal, votingPower: Nat) : async DAO.AddMemberResult {
    if (not isAdmin(msg.caller)) {
      return #notAuthorized;
    };
    switch (members.get(id)) {
      case (null) {
        let newMember : Member = { id = id; votingPower = votingPower };
        members.put(id, newMember);
        #ok
      };
      case (?_) #alreadyExists;
    }
  };

  public shared(msg) func removeMember(id: Principal) : async Result.Result<(), Text> {
    if (not isAdmin(msg.caller)) {
      return #err("Not authorized");
    };
    switch (members.remove(id)) {
      case (null) #err("Member not found");
      case (?_) #ok();
    }
  };

  public query func getMember(id: Principal) : async ?Member {
    members.get(id)
  };

  public query func listMembers() : async [Member] {
    Iter.toArray(members.vals())
  };

  // Функции DAO

  public shared(msg) func createProposal(content : ProposalContent) : async Result.Result<Nat, DAO.CreateProposalError> {
    Debug.print("Creating proposal: " # debug_show(content));
    let currentMembers = Iter.toArray(members.vals());
    await* dao.createProposal(msg.caller, content, currentMembers)
};

  public shared(msg) func vote(proposalId : Nat, voter: Text, vote : Bool) : async Result.Result<(), DAO.VoteError> {
    Debug.print("Voting. Caller: " # Principal.toText(msg.caller));
    await* dao.vote(proposalId, Principal.fromText(voter), vote)
  };

  public query func getProposal(id : Nat) : async ?DAO.Proposal<ProposalContent> {
    dao.getProposal(id)
  };

  public query func getProposals(count : Nat, offset : Nat) : async CommonTypes.PagedResult<DAO.Proposal<ProposalContent>> {
    dao.getProposals(count, offset)
  };

  // Rewards
  let rewardSystem = Rewards.Rewards();

  public shared(msg) func processUserAction(action: Text, user : Text) : async Result.Result<Nat, Text> {
    let actionType = CT.textToActionType(action);
    Debug.print("Processing user action: " # action);
    
    // Step 1: Call the reward system
    let rewardResult = await rewardSystem.rewardAction(Principal.fromText(user), actionType);
    
    switch (rewardResult) {
      case (#err(e)) return #err("Error in reward system: " # e);
      case (#ok) {
        
        let reward = await rewardSystem.getUserReward(Principal.fromText(user));
        Debug.print("Got Reward for user " # user # ": " # debug_show(reward));
        let proposalContent : ProposalContent = #transferFunds({
          amount = reward;
          recipient = Principal.fromText(user); 
          purpose =  #toFund("Rewards Fund"); // e.g., "Rewards Fund", "Development Fund"               
        });
        
        let proposalResult = await createProposal(proposalContent);
        
        switch (proposalResult) {
          case (#err(e)) return #err("Error creating proposal: " # debug_show(e));
          case (#ok(proposalId)) {
            Debug.print("Proposal created with ID: " # debug_show(proposalId));
            let ?proposal = await getProposal(proposalId);
             // start auto voting and execution process
            let result = await* executeRewardProposal(proposal);
            return #ok(proposalId);
          };
        };
       
      };
    };
  };

  // Function to execute the proposal (mint tokens)
  func executeRewardProposal(proposal : DAO.Proposal<ProposalContent>) : async* Result.Result<(), Text> {
    Debug.print("Executing proposal: " # debug_show(proposal.id));
    // TODO auto voting rewards
    
    // Debug.print("Tokens minted as per proposal: " # proposal.content.action);
    #ok
  };
  
  public shared(msg) func executeCodeUpdate(proposalId : Nat) : async Result.Result<(), Text> {
      switch (await getProposal(proposalId)) {
          case (null) #err("Proposal not found");
          case (?proposal) {
              switch (proposal.content) {
                  case (#codeUpdate(update)) {
                      // Implement code update logic
                      #err("Code update not implemented yet")
                  };
                  case (_) #err("Invalid proposal type for code update");
              };
          };
      };
  };

  public shared(msg) func executeTransferFunds(proposalId : Nat) : async Result.Result<(), Text> {
      switch (await getProposal(proposalId)) {
          case (null) #err("Proposal not found");
          case (?proposal) {
              switch (proposal.content) {
                  case (#transferFunds(transfer)) {
                      // Implement fund transfer logic
                      #err("Fund transfer not implemented yet")
                  };
                  case (_) #err("Invalid proposal type for fund transfer");
              };
          };
      };
  };

  public shared(msg) func executeAdjustParameters(proposalId : Nat) : async Result.Result<(), Text> {
      switch (await getProposal(proposalId)) {
          case (null) #err("Proposal not found");
          case (?proposal) {
              switch (proposal.content) {
                  case (#adjustParameters(adjustment)) {
                      // Implement parameter adjustment logic
                      #err("Parameter adjustment not implemented yet")
                  };
                  case (_) #err("Invalid proposal type for parameter adjustment");
              };
          };
      };
  };

  // Вспомогательные функции

  func isAdmin(caller: Principal) : Bool {
    Debug.print("Checking if caller is admin. Caller: " # Principal.toText(caller));
    // В реальном приложении здесь должна быть более сложная логика проверки прав администратора
    true
  };

  public query func greet(name : Text) : async Text {
    return "Hello, " # name # "!";
  };

// Test part -----------------------------------------------------------------
// Test runner

 func getTestObject() : Test.TestActorInterface {
    {
      addMember = func (id: Principal, votingPower: Nat) : async DAO.AddMemberResult {
        await addMember(id, votingPower)
      };
      removeMember = func (id: Principal) : async Result.Result<(), Text> {
        await removeMember(id)
      };
      getMember = func (id: Principal) : async ?DAO.Member {
        await getMember(id)
      };
      listMembers = func () : async [DAO.Member] {
        await listMembers()
      };
      createProposal = func (content: ProposalContent) : async Result.Result<Nat, DAO.CreateProposalError> {
        await createProposal(content)
      };
      vote = func (proposalId: Nat, voter : Text, voteValue: Bool) : async Result.Result<(), DAO.VoteError> {
        await vote(proposalId, voter, voteValue)
      };
       getProposal = func (id: Nat) : async ?DAO.Proposal<ProposalContent> {
        await getProposal(id)
      };
      getProposals = func (count: Nat, offset: Nat) : async CommonTypes.PagedResult<DAO.Proposal<ProposalContent>> {
        await getProposals(count, offset)
      };
     // getVotingPower : Principal -> Nat,
     getVotingPower = func (id: Principal) : async Nat {
      await* getVotingPower(id)
     }
    }
  };

func getRewardTestObject() : RT.TestActorInterface {
  {
    processUserAction = func (action: Text, user : Text) : async Result.Result<Nat, Text> {
      await processUserAction(action, user)
    };
    
    getUserReward = func (user: Principal) : async Nat {
      await rewardSystem.getUserReward(user)
    };
    
    setReward = func (actionType: CommonTypes.ActionType, amount: Nat) : async Result.Result<(), Text> {
      await rewardSystem.setReward(actionType, amount)
    };
    
    getReward = func (actionType: CommonTypes.ActionType) : async Result.Result<Nat, Text> {
      await rewardSystem.getReward(actionType)
    };
    
    rewardVoting = func (user: Principal, proposalId: Nat) : async Nat {
      await rewardSystem.rewardVoting(user, proposalId)
    };
    
    distributeMonthlyVotingRewards = func () : async () {
      await rewardSystem.distributeMonthlyVotingRewards()
    };
    
    convertRewardToFocus = func (user: Principal) : async Result.Result<Nat, Text> {
      await rewardSystem.convertRewardToFocus(user)
    };
    
    stakeRewards = func (user: Principal, amount: Nat, period: Nat) : async Result.Result<(), Text> {
      await rewardSystem.stakeRewards(user, amount, period)
    };
    
    calculateStakingReward = func (user: Principal) : async Result.Result<Nat, Text> {
      await rewardSystem.calculateStakingReward(user)
    };
    
    unstake = func (user: Principal) : async Result.Result<Nat, Text> {
      await rewardSystem.unstake(user)
    };
  }
};

public func getRewards() : async [(Text, Nat)] {
  await rewardSystem.getRewards()
};

  // Test runners
  public func runTests() : async () {
    await Test.runTests(getTestObject());
    Debug.print("Tests from test.mo completed.");
    // await PHTests.runTests();
    Debug.print("---------------------------------------------------------------------");
    await RT.runTests(getRewardTestObject());
    Debug.print("---------------------------------------------------------------------");
  };
}
