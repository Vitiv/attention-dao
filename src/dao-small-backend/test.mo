import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import DAO "./Dao";
import CommonTypes "./CommonTypes";
import Array "mo:base/Array";

module {
    public type ProposalContent = {
    description: Text;
    action: Text;
  };
  
   public type TestActorInterface = {
    addMember : (Principal, Nat) -> async DAO.AddMemberResult;
    removeMember : (Principal) -> async Result.Result<(), Text>;
    getMember : (Principal) -> async ?DAO.Member;
    listMembers : () -> async [DAO.Member];
    createProposal : (ProposalContent) -> async Result.Result<Nat, DAO.CreateProposalError>;
    vote : (Nat, Text, Bool) -> async Result.Result<(), DAO.VoteError>;
    getProposal : (Nat) -> async ?DAO.Proposal<ProposalContent>;
    getProposals : (Nat, Nat) -> async CommonTypes.PagedResult<DAO.Proposal<ProposalContent>>;
  };

  public func runTests(testActor: TestActorInterface) : async () {
    Debug.print("Running DAO tests...");

    let testPrincipal1 = Principal.fromText("aaaaa-aa");
    let testPrincipal2 = Principal.fromText("2vxsx-fae");
    let testPrincipal3 = Principal.fromText("mls5s-5qaaa-aaaal-qi6rq-cai");

    // Test 1: Add members
    await testAddMembers(testActor, testPrincipal1, testPrincipal2, testPrincipal3);

    // Test 2: List members
    await testListMembers(testActor);

    // Test 3: Remove member
    await testRemoveMember(testActor, testPrincipal2);

    // Test 4: Create proposal
    let proposalId = await testCreateProposal(testActor, testPrincipal1);

    // Test 5: Get proposal
    await testGetProposal(testActor, proposalId);

    // Test 6: Vote on proposal
    await testVote(testActor, proposalId, testPrincipal1, testPrincipal3);

    // Test 7: Get proposals (paged)
    await testGetProposals(testActor);

    // Test 8: Negative cases
    await testNegativeCases(testActor, testPrincipal2, proposalId);

    Debug.print("All tests completed!");
  };

  // Вспомогательные функции тестирования

  private func testAddMembers(testActor: TestActorInterface, p1: Principal, p2: Principal, p3: Principal) : async () {
    Debug.print("Test 1: Adding members");

    // Add first member
    let result1 = await testActor.addMember(p1, 1);
    assert(result1 == #ok);

    // Add second member
    let result2 = await testActor.addMember(p2, 2);
    assert(result2 == #ok);

    // Add third member
    let result3 = await testActor.addMember(p3, 3);
    assert(result3 == #ok);

    // Try to add existing member
    let result4 = await testActor.addMember(p1, 1);
    assert(result4 == #alreadyExists);

    // Verify members were added
    let member1 = await testActor.getMember(p1);
    switch (member1) {
      case (?m) assert(m.votingPower == 1);
      case null assert(false);
    };

    let member2 = await testActor.getMember(p2);
    switch (member2) {
      case (?m) assert(m.votingPower == 2);
      case null assert(false);
    };

    let member3 = await testActor.getMember(p3);
    switch (member3) {
      case (?m) assert(m.votingPower == 3);
      case null assert(false);
    };

    Debug.print("Test 1 passed: Members added successfully");
  };

  private func testListMembers(testActor: TestActorInterface) : async () {
    Debug.print("Test 2: Listing members");

    let members = await testActor.listMembers();
    assert(members.size() == 3);

    Debug.print("Test 2 passed: Listed members correctly");
  };

  private func testRemoveMember(testActor: TestActorInterface, p: Principal) : async () {
    Debug.print("Test 3: Removing member");

    let result = await testActor.removeMember(p);
    assert(Result.isOk(result));

    let member = await testActor.getMember(p);
    assert(member == null);

    Debug.print("Test 3 passed: Member removed successfully");
  };

  private func testCreateProposal(testActor: TestActorInterface, p: Principal) : async Nat {
    Debug.print("Test 4: Creating proposal");

    let content : ProposalContent = {
      description = "Test proposal";
      action = "Do nothing";
    };

    Debug.print("Creating proposal with principal: " # Principal.toText(p));
    let result = await testActor.createProposal(content);
    switch (result) {
      case (#ok(id)) {
        Debug.print("Test 4 passed: Proposal created successfully with ID: " # debug_show(id));
        
        // Проверяем состояние предложения после создания
        let proposal = await testActor.getProposal(id);
        switch (proposal) {
          case (?p) {
            Debug.print("Proposal state after creation:");
            Debug.print("Proposal ID: " # debug_show(p.id));
            Debug.print("Proposer ID: " # Principal.toText(p.proposerId));
            Debug.print("Total votes: " # debug_show(p.votes.size()));
            let yesVotes = Array.filter<(Principal, DAO.Vote)>(p.votes, func (vote) { vote.1.value == ?true });
            let noVotes = Array.filter<(Principal, DAO.Vote)>(p.votes, func (vote) { vote.1.value == ?false });
            Debug.print("Yes votes: " # debug_show(yesVotes.size()) # ", No votes: " # debug_show(noVotes.size()));
          };
          case (null) {
            Debug.print("Failed to retrieve proposal after creation");
          };
        };
        
        id
      };
      case (#err(e)) {
        Debug.print("Test 4 failed: Could not create proposal. Error: " # debug_show(e));
        assert(false);
        0 // This line will never be reached due to the assert, but is needed for type checking
      };
    };
  };

  private func testGetProposal(testActor: TestActorInterface, id: Nat) : async () {
    Debug.print("Test 5: Getting proposal");

    let proposal = await testActor.getProposal(id);
    switch (proposal) {
      case (?p) {
        assert(p.id == id);
        assert(p.content.description == "Test proposal");
        Debug.print("Test 5 passed: Retrieved proposal correctly");
      };
      case (null) {
        Debug.print("Test 5 failed: Could not retrieve proposal");
        assert(false);
      };
    };
  };

   private func testVote(testActor: TestActorInterface, proposalId: Nat, p1: Principal, p2: Principal) : async () {
    Debug.print("Test 6: Voting on proposal");
    func calculateVotingPower(votes: [(Principal, DAO.Vote)], predicate: (DAO.Vote) -> Bool) : Nat {
      Array.foldLeft<(Principal, DAO.Vote), Nat>(
        Array.filter<(Principal, DAO.Vote)>(votes, func (vote: (Principal, DAO.Vote)) : Bool { predicate(vote.1) }),
        0,
        func (acc: Nat, vote: (Principal, DAO.Vote)) : Nat { acc + vote.1.votingPower }
      )
    };

    // Проверка членства перед голосованием
    Debug.print("Checking membership for " # Principal.toText(p1));
    let member1 = await testActor.getMember(p1);
    switch (member1) {
      case (?m) Debug.print("Member 1 found with voting power: " # debug_show(m.votingPower));
      case null Debug.print("Member 1 not found!");
    };

    // Проверяем состояние предложения перед голосованием
    let proposalBeforeVote = await testActor.getProposal(proposalId);
    switch (proposalBeforeVote) {
      case (?p) {
        Debug.print("Proposal state before voting:");
        Debug.print("Proposal ID: " # debug_show(p.id));
        Debug.print("Proposer ID: " # Principal.toText(p.proposerId));
        Debug.print("Total votes: " # debug_show(p.votes.size()));
        Debug.print("Votes: " # debug_show(p.votes));
        let yesVotes = Array.filter<(Principal, DAO.Vote)>(p.votes, func (vote) { vote.1.value == ?true });
        let noVotes = Array.filter<(Principal, DAO.Vote)>(p.votes, func (vote) { vote.1.value == ?false });
        let yesVotingPower = calculateVotingPower(p.votes, func (vote) = vote.value == ?true);
        let noVotingPower = calculateVotingPower(p.votes, func (vote) = vote.value == ?false);
        Debug.print("Yes voting power: " # debug_show(yesVotingPower) # ", No voting power: " # debug_show(noVotingPower)); 
        Debug.print("Yes votes: " # debug_show(yesVotes.size()) # ", No votes: " # debug_show(noVotes.size()));
      };
      case (null) {
        Debug.print("Failed to retrieve proposal before voting");
      };
    };

    // Vote with the first member
    Debug.print("Voting with first member: " # Principal.toText(p1));
    let voteResult1 = await testActor.vote(proposalId, Principal.toText(p1), true);
    switch(voteResult1) {
      case (#ok) Debug.print("First vote successful");
      case (#err(e)) Debug.print("First vote failed: " # debug_show(e));
    };
   
    assert(Result.isOk(voteResult1));

    // Проверка членства перед голосованием
    Debug.print("Checking membership for " # Principal.toText(p2));
    let member2 = await testActor.getMember(p2);
    switch (member2) {
      case (?m) Debug.print("Member 2 found with voting power: " # debug_show(m.votingPower));
      case null Debug.print("Member 2 not found!");
    };  

    // Vote with the second member
    Debug.print("Voting with second member: " # Principal.toText(p2));
    let voteResult2 = await testActor.vote(proposalId, Principal.toText(p2), false);
    switch(voteResult2) {
      case (#ok) Debug.print("Second vote successful");
      case (#err(e)) Debug.print("Second vote failed: " # debug_show(e));
    };
    assert(Result.isOk(voteResult2));

    // Check the votes
    let proposal = await testActor.getProposal(proposalId);
    switch (proposal) {
      case (?p) {
        Debug.print("Proposal found. Total votes: " # debug_show(p.votes.size()));
        let yesVotes = Array.filter<(Principal, DAO.Vote)>(p.votes, func (vote) { vote.1.value == ?true });
        let noVotes = Array.filter<(Principal, DAO.Vote)>(p.votes, func (vote) { vote.1.value == ?false });
        let yesVotingPower = calculateVotingPower(p.votes, func (vote) = vote.value == ?true);
        let noVotingPower = calculateVotingPower(p.votes, func (vote) = vote.value == ?false);
        Debug.print("Yes voting power: " # debug_show(yesVotingPower) # ", No voting power: " # debug_show(noVotingPower)); 
        Debug.print("Yes votes: " # debug_show(yesVotes.size()) # ", No votes: " # debug_show(noVotes.size()));
        assert(yesVotes.size() == 1 and noVotes.size() == 1);
        Debug.print("Test 6 passed: Votes recorded correctly");
      };
      case (null) {
        Debug.print("Test 6 failed: Could not retrieve proposal after voting");
        assert(false);
      };
    };
  };

  private func testGetProposals(testActor: TestActorInterface) : async () {
    Debug.print("Test 7: Getting proposals (paged)");

    let result = await testActor.getProposals(10, 0);
    assert(result.data.size() == 1);
    assert(result.offset == 0);
    assert(result.count == 10);

    Debug.print("Test 7 passed: Retrieved paged proposals correctly");
  };

  private func testNegativeCases(testActor: TestActorInterface, nonExistentMember: Principal, proposalId: Nat) : async () {
    Debug.print("Test 8: Negative cases");
    let testPrincipal2 = Principal.fromText("2vxsx-fae");


    // Try to remove non-existent member
    let removeResult = await testActor.removeMember(nonExistentMember);
    assert(Result.isErr(removeResult));

    // Try to vote with non-existent member
    let voteResult = await testActor.vote(proposalId, Principal.toText(testPrincipal2), true);
    assert(Result.isErr(voteResult));

    // Try to vote on non-existent proposal
    let voteResult2 = await testActor.vote(999,Principal.toText(testPrincipal2), true);
    assert(Result.isErr(voteResult2));

    Debug.print("Test 8 passed: Negative cases handled correctly");
  };
};
