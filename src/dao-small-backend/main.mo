import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import DAO "./Dao";
import CommonTypes "./CommonTypes";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";

actor {
  type ProposalContent = {
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
    let currentMembers = Iter.toArray(members.vals());
    await* dao.createProposal(msg.caller, content, currentMembers)
  };

  public shared(msg) func vote(proposalId : Nat, vote : Bool) : async Result.Result<(), DAO.VoteError> {
    await* dao.vote(proposalId, msg.caller, vote)
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
}
