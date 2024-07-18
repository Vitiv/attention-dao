import Principal "mo:base/Principal";
import Result "mo:base/Result";
import DAO "./Dao";
import CommonTypes "./CommonTypes";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Test "./test";

actor {
  public type ProposalContent = {
    description: Text;
    action: Text;
  };

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

  func executeProposal(proposal : DAO.Proposal<ProposalContent>) : async* Result.Result<(), Text> {
    // Здесь должна быть логика выполнения предложения
    #ok
  };

  func rejectProposal(proposal : DAO.Proposal<ProposalContent>) : async* () {
    // Здесь может быть логика, выполняемая при отклонении предложения
  };

  func validateProposal(content : ProposalContent) : async* Result.Result<(), [Text]> {
    // Здесь должна быть логика проверки предложения
    #ok
  };

  let dao = DAO.Dao<system, ProposalContent>(
    daoStableData,
    executeProposal,
    rejectProposal,
    validateProposal
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
    Debug.print("Creating proposal. ");
    let currentMembers = Iter.toArray(members.vals());
    await* dao.createProposal(msg.caller, content, currentMembers)
  };

  public shared(msg) func vote(proposalId : Nat, voter: Text, vote : Bool) : async Result.Result<(), DAO.VoteError> {
    Debug.print("Voting.");
    await* dao.vote(proposalId, Principal.fromText(voter), vote)
  };

  public query func getProposal(id : Nat) : async ?DAO.Proposal<ProposalContent> {
    dao.getProposal(id)
  };

  public query func getProposals(count : Nat, offset : Nat) : async CommonTypes.PagedResult<DAO.Proposal<ProposalContent>> {
    dao.getProposals(count, offset)
  };

  // Вспомогательные функции

  func isAdmin(caller: Principal) : Bool {
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
    }
  };

  // Test runner
  public func runTests() : async () {
    await Test.runTests(getTestObject());
  };
// let testPrincipal1 = Principal.fromText("aaaaa-aa");
// let testPrincipal2 = Principal.fromText("2vxsx-fae");
// let testPrincipal3 = Principal.fromText("mls5s-5qaaa-aaaal-qi6rq-cai");
// // type ProposalContent = {
// //     description: Text;
// //     action: Text;
// //   };

//   public func test() : async () {
//     Debug.print("Running DAO tests...");

//     // Создаем тестовые данные
//     let initialData : DAO.StableData<ProposalContent> = {
//       proposals = [];
//       proposalDuration = #days(1);
//       votingThreshold = #percent({ percent = 51; quorum = ?25 });
//     };

//     // Создаем экземпляр DAO
//     let dao = DAO.Dao<system, ProposalContent>(
//       initialData,
//       executeProposal,
//       rejectProposal,
//       validateProposal
//     );

//     // Тест 1: Создание предложения
//     let members = [
//       { id = testPrincipal1; votingPower = 1 },
//       { id = testPrincipal2; votingPower = 1 },
//       { id = testPrincipal3; votingPower = 1 }
//     ];
//     let content : ProposalContent = {
//       description = "Test proposal";
//       action = "Do nothing";
//     };
//     let createResult = await* dao.createProposal(testPrincipal1, content, members);
//     switch (createResult) {
//       case (#ok(id)) {
//         assert(id == 1);
//         Debug.print("Test 1 passed: Proposal created successfully");
//       };
//       case (#err(_)) {
//         Debug.print("Test 1 failed: Could not create proposal");
//         assert(false);
//       };
//     };

//     // Тест 2: Получение предложения
//     let proposal = dao.getProposal(1);
//     switch (proposal) {
//       case (?p) {
//         assert(p.id == 1);
//         assert(p.proposerId == testPrincipal1);
//         assert(p.content.description == "Test proposal");
//         Debug.print("Test 2 passed: Retrieved proposal correctly");
//       };
//       case (null) {
//         Debug.print("Test 2 failed: Could not retrieve proposal");
//         assert(false);
//       };
//     };

//     // Тест 3: Голосование
//     let voteResult = await* dao.vote(1, testPrincipal2, true);
//     switch (voteResult) {
//       case (#ok) {
//         Debug.print("Test 3 passed: Vote successful");
//       };
//       case (#err(_)) {
//         Debug.print("Test 3 failed: Could not vote");
//         assert(false);
//       };
//     };

//     // Тест 4: Проверка результатов голосования
//     let updatedProposal = dao.getProposal(1);
//     switch (updatedProposal) {
//       case (?p) {
//         let votes = Iter.toArray(Iter.filter(p.votes.vals(), func ((_, vote) : (Principal, DAO.Vote)) : Bool { vote.value == ?true }));
//         assert(votes.size() == 2); // Учитываем автоматический голос создателя предложения
//         Debug.print("Test 4 passed: Vote count correct");
//       };
//       case (null) {
//         Debug.print("Test 4 failed: Could not retrieve updated proposal");
//         assert(false);
//       };
//     };

//     Debug.print("All tests passed!");
//   };


}
