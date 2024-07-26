import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
// import Nat8 "mo:base/Nat8";
// import Token "mo:icrc1/ICRC1/Canisters/Token";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
// import Error "mo:base/Error";
import Cycles "mo:base/ExperimentalCycles";

import CommonTypes "./CommonTypes";
import CT "./CommonTypes";
import DAO "./Dao";
import Ledger "./Ledger";
import PH "./ProposalHandler";
import Rewards "./RewardSystem";
import Test "./test";
import RT "./reward.test";


actor Main {
  
  type ProposalContent = CT.ProposalContent;

  type Member = DAO.Member;

  stable var daoStableData : DAO.StableData<ProposalContent> = {
    proposals = [];
    proposalDuration = #days(7);
    votingThreshold = #percent({ percent = 51; quorum = ?25 });
  };

  stable var membersEntries : [(Principal, Member)] = [];
  var members = HashMap.HashMap<Principal, Member>(10, Principal.equal, Principal.hash);

  var ledger : ?Ledger.Ledger = null;

    public shared(msg) func initLedger() : async Result.Result<(Nat, Text, Text), Text> {
       switch (ledger) {
        case (?l) {
          #err("Ledger already initialized");
          };
          case (null) {       
            Cycles.add<system>(30_000_000_000);        
            ledger := ?Ledger.Ledger();
            switch (ledger) {
                case (?l) await l.createToken("FOCUS", "FOCUS", Principal.toText(msg.caller));
                case (null) #err("Failed to initialize ledger");
            };
        };
       };
    };

    //--------------------------------------------------------------

    func getVotingPower(user : Principal) : async* Nat {
        switch (ledger) {
            case (?l) { 
                Cycles.add<system>(100_000);
                let balance = await l.getBalance(user);
                Debug.print("main.getVotingPower: l.getBalance result: " # Nat.toText(balance));
                balance;
               };
            case null {
                ignore await initLedger();
                Debug.print("main.getVotingPower: Ledger initialized");
                0
            };
        };
    };

    func executeTransferFunds(proposalId : Nat) : async Result.Result<(), Text> {
        switch (await getProposal(proposalId)) {
            case (null) #err("Proposal not found");
            case (?proposal) {
                switch (proposal.content) {
                    case (#transferFunds(transfer)) {
                      Debug.print("main.executeTransferFunds: transfer.amount: " # Nat.toText(transfer.amount));
                      Debug.print("main.executeTransferFunds: transfer.recipient: " # Principal.toText(transfer.recipient));
                        switch (ledger) {
                            case (?l) {
                                Cycles.add<system>(500_000);
                                let transferResult = await l.transfer(transfer.recipient, transfer.amount);
                                if (transferResult) {
                                    #ok()
                                } else {
                                    #err("Transfer failed")
                                }
                            };
                            case null #err("LedgerManager not initialized");
                        };
                    };
                    case (_) #err("Invalid proposal type for fund transfer");
                };
            };
        };
    };
    
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
          switch (ledger) {
            case (?l) {
              Cycles.add<system>(500_000);
              let result = await l.transfer(transfer.recipient, transfer.amount);
              switch (result) {
                case (true) { 
                  #ok 
                  };
                case (false) {
                  #err("Error during fund transfer");
                  };
              };
            };
            case null #err("Ledger not initialized");
          }           
            
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

  let dao = DAO.Dao<system, ProposalContent>(
    daoStableData,
    executeProposal,
    rejectProposal,
    validateProposal,
    getVotingPower,
  );

  // Membership management

  public shared(msg) func addMember(id: Principal, votingPower: Nat) : async DAO.AddMemberResult {
    if (not isAdmin(msg.caller)) {
      return #notAuthorized;
    };
    switch (members.get(id)) {
      case (null) {
        let newMember : Member = { id = id; votingPower = votingPower };
        members.put(id, newMember);
        switch (ledger) {
            case (?l) { 
              Cycles.add<system>(500_000);
              let res = l.transfer(id, votingPower);
            };
            case (null) return #otherError("Error when adding tokens");
        };
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

  // Proposal management

  public shared(msg) func createProposal(content : ProposalContent) : async Result.Result<Nat, DAO.CreateProposalError> {
    Debug.print("Creating proposal: " # debug_show(content));
    let currentMembers = Iter.toArray(members.vals());
    await* dao.createProposal(msg.caller, content, currentMembers)
};

  public shared(msg) func vote(proposalId : Nat, voter: Text, vote : Bool) : async Result.Result<(), DAO.VoteError> {
    Debug.print("Voting.  Voter: " # voter  # " ; Caller: " # Principal.toText(msg.caller));
    let voting_result = await* dao.vote(proposalId, Principal.fromText(voter), vote);
    switch (voting_result) {
      case (#err(err)) {
        Debug.print("Error voting: " # debug_show(err));
        return #err(err)
        };
        case (#ok()) {
          Debug.print("Vote successful");
          ignore await processVotingRewards(Principal.fromText(voter));
        };        
      };
    #ok()
  };

  public query func getProposal(id : Nat) : async ?DAO.Proposal<ProposalContent> {
    dao.getProposal(id)
  };

  public query func getProposals(count : Nat, offset : Nat) : async CommonTypes.PagedResult<DAO.Proposal<ProposalContent>> {
    dao.getProposals(count, offset)
  };

  //----------------------------------------------------------------------------------------

  // Rewards
  let rewardSystem = Rewards.Rewards();

  func processUserAction(action: Text, user : Text) : async Result.Result<Nat, Text> {
    let actionType = CT.textToActionType(action);
    Debug.print("Processing user action: " # action);
    
    // Step 1: Call the reward system
    let rewardResult = await rewardSystem.rewardAction(Principal.fromText(user), actionType);
    
    switch (rewardResult) {
      case (#err(e)) return #err("Error in reward system: " # e);
      case (#ok) {
        
        let reward = await rewardSystem.getUserReward(Principal.fromText(user));
        Debug.print("processUserAction: Got Reward for user from RewardSystem " # user # ": " # debug_show(reward));
        let user_balance = await* getVotingPower(Principal.fromText(user));
        Debug.print("processUserAction: User balance from ledger before proposal: " # debug_show(user_balance));
        let proposalContent : ProposalContent = #transferFunds({
          amount = reward;
          recipient = Principal.fromText(user); 
          purpose =  #toFund("Rewards Fund"); // e.g., "Rewards Fund", "Development Fund"               
        });
        
        let proposalResult = await createProposal(proposalContent);
        
        switch (proposalResult) {
          case (#err(e)) return #err("Error creating proposal: " # debug_show(e));
          case (#ok(proposalId)) {
            Debug.print("processUserAction: Proposal created with ID: " # debug_show(proposalId));
            // let ?proposal = await getProposal(proposalId);
             // TODO start auto voting and execution process
            let result = await* executeRewardProposal(proposalId);
            Debug.print("processUserAction: Proposal executed successfully, " # debug_show(result));
            let resetRewarding = await rewardSystem.resetUserReward(Principal.fromText(user));
            Debug.print("processUserAction: Reward reset for user: " # debug_show(Principal.fromText(user)) # ", result: " # debug_show(resetRewarding));
            return #ok(proposalId);
          };
        };
       
      };
    };
  };

  func processVotingRewards(user : Principal) : async Result.Result<(), Text> {
    switch (ledger) {
      case (?l) {   
        Cycles.add<system>(100_000); 
        let userbalance = await l.getBalance(user);
        Debug.print("User balance: " # debug_show(userbalance));
        let resultRewarding = await rewardSystem.addReward(user, userbalance);         
            Debug.print("processVotingRewards:Rewarded user: " # Principal.toText(user));
            Debug.print("processVotingRewards:Result rewarding: " # debug_show(resultRewarding));
            // create a proposal to distribute the rewards
            let resultCreatingPropsal = await createVotingRewardsProposal(user, userbalance);
            switch (resultCreatingPropsal) {
              case (#err(e)) return #err("processVotingRewards: Error creating proposal: " # debug_show(e));
              case (#ok(proposalId)) {
                Debug.print("processVotingRewards: Proposal created with ID: " # debug_show(proposalId));
                // start auto voting and execution process
                let result = await* executeRewardProposal(proposalId);
                Debug.print("processVotingRewards: Proposal executed successfully, " # debug_show(result));
                let resetRewarding = await rewardSystem.resetUserReward(user);
                Debug.print("processVotingRewards: Reward reset for user: " # Principal.toText(user));
                Debug.print("processVotingRewards: Result reseting: " # debug_show(resetRewarding));
                return #ok;
              };   
            };
        };
      case (null) return #err("Ledger not initialized");
    };
  };
         

  public func createVotingRewardsProposal(user : Principal, amount : Nat) : async Result.Result<Nat, DAO.CreateProposalError> {
    let votingRewards = await rewardSystem.getVotingRewards();
    let proposalContent : ProposalContent = #transferFunds({
      amount = amount;
      recipient = user; 
      purpose = #toFund("Voting Rewards Distribution");
    });
    
    await createProposal(proposalContent)
  };

  // Function to execute the proposal (mint tokens)
  func executeRewardProposal(proposalId : Nat) : async* Result.Result<(), Text> {
    Debug.print("executeRewardProposal: Executing proposal: " # debug_show(proposalId));
    // TODO auto voting rewards
    
    let transfer_result = await executeTransferFunds(proposalId);
    Debug.print("executeRewardProposal: Transfer result: " # debug_show(transfer_result));
    #ok
  };
  
  func executeCodeUpdate(proposalId : Nat) : async Result.Result<(), Text> {
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

  func executeAdjustParameters(proposalId : Nat) : async Result.Result<(), Text> {
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

  func executeVotingRewardsProposal(proposal : DAO.Proposal<ProposalContent>) : async* Result.Result<(), Text> {
    Debug.print("Executing voting rewards proposal: " # debug_show(proposal.id));
    
    let votingRewards = await rewardSystem.getVotingRewards();
    
    for ((user, reward) in votingRewards.rewards.vals()) {
      switch (ledger) {
            case (?l) {
              Cycles.add<system>(500_000);
              let transferResult = await l.transfer(user, reward);
              // switch (transferResult) {
              //   case (true) {                   
              //     };
              //   case (false) {
              //     #err("Error during fund transfer");
              //     };
              // };
            };
            case null {};
          };  
           
      
    };
    
    await rewardSystem.resetVotingRewards();
    
    #ok
  };

   public func distributeMonthlyVotingRewards() : async Result.Result<(), Text> {
      // for (user in members.keys()) {
      //     let proposalResult = await createVotingRewardsProposal(user, amount);
      //     switch (proposalResult) {
      //         case (#err(e)) return #err("Error creating voting rewards proposal: " # debug_show (e));
      //         case (#ok(proposalId)) {
      //             Debug.print("Voting rewards proposal created with ID: " # debug_show (proposalId));
      //             let ?proposal = await getProposal(proposalId);
      //             // Here you would typically wait for the voting period to end
      //             // For simplicity, we'll execute it immediately in this example
      //             ignore await* executeVotingRewardsProposal(proposal);
      //         };
      //     };           
      //   };
         #ok;
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
      distributeMonthlyVotingRewards = func() : async Result.Result<(), Text> {
        await distributeMonthlyVotingRewards()
      };
      createVotingRewardsProposal = func (id : Principal, amount : Nat) : async Result.Result<Nat, DAO.CreateProposalError>{
        await createVotingRewardsProposal(id, amount)
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
    
    // distributeMonthlyVotingRewards = func () : async () {
    //   await rewardSystem.distributeMonthlyVotingRewards()
    // };
    
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
    Debug.print("All proposals: " # debug_show(await getProposals(100, 0)));
  };
}
