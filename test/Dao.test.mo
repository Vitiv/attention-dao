import { test; suite } "mo:test/async";
import DAO "../src/dao-small-backend/Dao";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import Result "mo:base/Result";
import CT "../src/dao-small-backend/CommonTypes";

let testPrincipal1 = Principal.fromText("aaaaa-aa");
let testPrincipal2 = Principal.fromText("2vxsx-fae");
let testPrincipal3 = Principal.fromText("mls5s-5qaaa-aaaal-qi6rq-cai");

type ProposalContent = {
    description: Text;
    action: Text;
};

let initialData : DAO.StableData<ProposalContent> = {
    proposals = [];
    proposalDuration = #days(1);
    votingThreshold = #percent({ percent = 51; quorum = ?25 });
};

func executeProposal(proposal : DAO.Proposal<ProposalContent>) : async* Result.Result<(), Text> {
    #ok
};

func rejectProposal(proposal : DAO.Proposal<ProposalContent>) : async* CT.CommonResult {
    #ok
};

func validateProposal(content : ProposalContent) : async* Result.Result<(), [Text]> {
    #ok
};

func getVotingPower(member : Principal) : async* Nat {
    10;
};

let dao = DAO.Dao<system, ProposalContent>(
    initialData,
    executeProposal,
    rejectProposal,
    validateProposal,
    getVotingPower
);

await suite(
    "DAO method tests",
    func() : async () {
        await test(
            "createProposal",
            func() : async () {
                let members = [
                    { id = testPrincipal1; votingPower = 1 },
                    { id = testPrincipal2; votingPower = 1 },
                    { id = testPrincipal3; votingPower = 1 }
                ];
                let content : ProposalContent = {
                    description = "Test proposal";
                    action = "Do nothing";
                };
                let result = await* dao.createProposal(testPrincipal1, content, members);
                switch (result) {
                    case (#ok(id)) {
                        Debug.print("createProposal result id: " # Nat.toText(id));
                        assert (id == 1);
                    };
                    case (#err(_)) {
                        Debug.print("createProposal failed");
                        assert (false);
                    };
                };
            },
        );

        await test(
            "getProposal",
            func() : async () {
                let proposal = dao.getProposal(1);
                switch (proposal) {
                    case (?p) {
                        Debug.print("getProposal result id: " # Nat.toText(p.id));
                        assert (p.id == 1);
                        assert (p.proposerId == testPrincipal1);
                        assert (p.content.description == "Test proposal");
                    };
                    case (null) {
                        Debug.print("getProposal failed");
                        assert (false);
                    };
                };
            },
        );

        await test(
            "vote",
            func() : async () {
                let result = await* dao.vote(1, testPrincipal2, true);
                switch (result) {
                    case (#ok) {
                        Debug.print("vote successful");
                        assert (true);
                    };
                    case (#err(_)) {
                        Debug.print("vote failed");
                        assert (false);
                    };
                };
            },
        );

        await test(
            "getProposals",
            func() : async () {
                let result = dao.getProposals(10, 0);
                Debug.print("getProposals result size: " # Nat.toText(result.data.size()));
                assert (result.data.size() == 1);
            },
        );

        // Негативные тесты

        await test(
            "vote on non-existent proposal",
            func() : async () {
                let result = await* dao.vote(999, testPrincipal2, true);
                switch (result) {
                    case (#ok) {
                        Debug.print("vote on non-existent proposal unexpectedly succeeded");
                        assert (false);
                    };
                    case (#err(error)) {
                        Debug.print("vote on non-existent proposal failed as expected");
                        assert (error == #proposalNotFound);
                    };
                };
            },
        );

        await test(
            "vote twice",
            func() : async () {
                let result = await* dao.vote(1, testPrincipal2, false);
                switch (result) {
                    case (#ok) {
                        Debug.print("second vote unexpectedly succeeded");
                        assert (false);
                    };
                    case (#err(error)) {
                        Debug.print("second vote failed as expected");
                        assert (error == #alreadyVoted);
                    };
                };
            },
        );
    },
);
/*
import { test; suite } "mo:test/async";
import DAO "../src/dao-small-backend/Dao";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import Result "mo:base/Result";

let testPrincipal1 = Principal.fromText("aaaaa-aa");
let testPrincipal2 = Principal.fromText("2vxsx-fae");
let testPrincipal3 = Principal.fromText("mls5s-5qaaa-aaaal-qi6rq-cai");

type ProposalContent = {
    description: Text;
    action: Text;
};

let initialData : DAO.StableData<ProposalContent> = {
    proposals = [];
    proposalDuration = #days(1);
    votingThreshold = #percent({ percent = 51; quorum = ?25 });
};

func executeProposal(proposal : DAO.Proposal<ProposalContent>) : async* Result.Result<(), Text> {
    #ok
};

func rejectProposal(proposal : DAO.Proposal<ProposalContent>) : async* () {
};

func validateProposal(content : ProposalContent) : async* Result.Result<(), [Text]> {
    if (content.description.size() < 10) {
        #err(["Description is too short"])
    } else if (content.action.size() < 5) {
        #err(["Action is too short"])
    } else {
        #ok
    }
};

func getVotingPower(member : Principal) : async* Nat {
    10;
};

let dao = DAO.Dao<system, ProposalContent>(
    initialData,
    executeProposal,
    rejectProposal,
    validateProposal,
    getVotingPower
);

await suite(
    "DAO method tests",
    func() : async () {
        // ... (предыдущие тесты остаются без изменений)

        await test(
            "validateProposal",
            func() : async () {
                // Тест валидного предложения
                let validContent : ProposalContent = {
                    description = "This is a valid description for a proposal";
                    action = "Valid action";
                };
                let validResult = await* dao.validateProposal(validContent);
                switch (validResult) {
                    case (#ok) {
                        Debug.print("Valid proposal passed validation");
                        assert true;
                    };
                    case (#err(errors)) {
                        Debug.print("Valid proposal failed validation unexpectedly");
                        Debug.print(debug_show(errors));
                        assert false;
                    };
                };

                // Тест предложения с коротким описанием
                let shortDescContent : ProposalContent = {
                    description = "Too short";
                    action = "Valid action";
                };
                let shortDescResult = await* dao.validateProposal(shortDescContent);
                switch (shortDescResult) {
                    case (#ok) {
                        Debug.print("Proposal with short description passed validation unexpectedly");
                        assert false;
                    };
                    case (#err(errors)) {
                        Debug.print("Proposal with short description failed validation as expected");
                        assert (errors == ["Description is too short"]);
                    };
                };

                // Тест предложения с коротким действием
                let shortActionContent : ProposalContent = {
                    description = "This is a valid description for a proposal";
                    action = "Short";
                };
                let shortActionResult = await* dao.validateProposal(shortActionContent);
                switch (shortActionResult) {
                    case (#ok) {
                        Debug.print("Proposal with short action passed validation unexpectedly");
                        assert false;
                    };
                    case (#err(errors)) {
                        Debug.print("Proposal with short action failed validation as expected");
                        assert (errors == ["Action is too short"]);
                    };
                };
            },
        );
    },
);

*/
