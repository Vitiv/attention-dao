/*
* Based on Ethan Celletti's code https://github.com/edjCase/daoball/blob/main/src/backend/Dao.mo
*/

import Principal "mo:base/Principal";
import Nat32 "mo:base/Nat32";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Order "mo:base/Order";
import IterTools "mo:itertools/Iter";
import CommonTypes "./CommonTypes";
import Result "mo:base/Result";

module {
    public type StableData<TProposalContent> = {
        proposals : [Proposal<TProposalContent>];
        proposalDuration : Duration;
        votingThreshold : VotingThreshold;
    };

    public type VotingThreshold = {
        #percent : { percent : Percent; quorum : ?Percent };
    };

    public type Duration = {
        #days : Nat;
        #nanoseconds : Nat;
    };

    public type Percent = Nat; // 0-100

    public type Member = {
        votingPower : Nat;
        id : Principal;
    };

    public type Proposal<TProposalContent> = {
        id : Nat;
        proposerId : Principal;
        timeStart : Int;
        timeEnd : Int;
        endTimerId : ?Nat;
        content : TProposalContent;
        votes : [(Principal, Vote)];
        statusLog : [ProposalStatusLogEntry];
    };

    public type ProposalStatusLogEntry = {
        #executing : {
            time : Time.Time;
        };
        #executed : {
            time : Time.Time;
        };
        #failedToExecute : {
            time : Time.Time;
            error : Text;
        };
        #rejected : {
            time : Time.Time;
        };
    };

    public type Vote = {
        value : ?Bool;
        votingPower : Nat;
    };

    type MutableProposal<TProposalContent> = {
        id : Nat;
        proposerId : Principal;
        timeStart : Int;
        timeEnd : Int;
        var endTimerId : ?Nat;
        content : TProposalContent;
        votes : HashMap.HashMap<Principal, Vote>;
        statusLog : Buffer.Buffer<ProposalStatusLogEntry>;
        votingSummary : VotingSummary;
    };

    type VotingSummary = {
        var yes : Nat;
        var no : Nat;
        var notVoted : Nat;
    };

    public type AddMemberResult = {
        #ok;
        #alreadyExists;
        #notAuthorized;
        #otherError : Text;
    };

    public type CreateProposalError = {
        #notAuthorized;
        #invalid : [Text];
    };

    public type VoteError = {
        #notAuthorized;
        #alreadyVoted;
        #votingClosed;
        #proposalNotFound;
        // #insufficientVotingPower;
        #wrongVotingPower;
    };

    public class Dao<system, TProposalContent>(
        data : StableData<TProposalContent>,
        onProposalExecute : Proposal<TProposalContent> -> async* Result.Result<(), Text>,
        onProposalReject : Proposal<TProposalContent> -> async* CommonTypes.CommonResult,
        onProposalValidate : TProposalContent -> async* Result.Result<(), [Text]>,
        getVotingPower : Principal -> async* Nat,
    ) {
        func hashNat(n : Nat) : Nat32 = Nat32.fromNat(n); // TODO

        let proposalsIter = data.proposals.vals()
        |> Iter.map<Proposal<TProposalContent>, (Nat, MutableProposal<TProposalContent>)>(
            _,
            func(proposal : Proposal<TProposalContent>) : (Nat, MutableProposal<TProposalContent>) {
                let mutableProposal = toMutableProposal(proposal);
                (
                    proposal.id,
                    mutableProposal,
                );
            },
        );

        var proposals = HashMap.fromIter<Nat, MutableProposal<TProposalContent>>(proposalsIter, 0, Nat.equal, hashNat);
        var nextProposalId = data.proposals.size() + 1; // TODO make last proposal + 1

        var proposalDuration = data.proposalDuration;
        var votingThreshold = data.votingThreshold;

        private func resetEndTimers<system>() {
            for (proposal in proposals.vals()) {
                switch (proposal.endTimerId) {
                    case (null) ();
                    case (?id) Timer.cancelTimer(id);
                };
                proposal.endTimerId := null;
                let currentStatus = getProposalStatus(proposal.statusLog);
                if (currentStatus == #open) {
                    let proposalDurationNanoseconds = durationToNanoseconds(proposalDuration);
                    let endTimerId = createEndTimer<system>(proposal.id, proposalDurationNanoseconds);
                    proposal.endTimerId := ?endTimerId;
                };
            };
        };

        public func getProposal(id : Nat) : ?Proposal<TProposalContent> {
            let ?proposal = proposals.get(id) else return null;
            ?{
                proposal with
                endTimerId = proposal.endTimerId;
                votes = Iter.toArray(proposal.votes.entries());
                statusLog = Buffer.toArray(proposal.statusLog);
                votingSummary = {
                    yes = proposal.votingSummary.yes;
                    no = proposal.votingSummary.no;
                    notVoted = proposal.votingSummary.notVoted;
                };
            };
        };

        public func getProposals(count : Nat, offset : Nat) : CommonTypes.PagedResult<Proposal<TProposalContent>> {
            let vals = proposals.vals()
            |> Iter.map(
                _,
                func(proposal : MutableProposal<TProposalContent>) : Proposal<TProposalContent> = fromMutableProposal(proposal),
            )
            |> IterTools.sort(
                _,
                func(proposalA : Proposal<TProposalContent>, proposalB : Proposal<TProposalContent>) : Order.Order {
                    Int.compare(proposalA.timeStart, proposalB.timeStart);
                },
            )
            |> IterTools.skip(_, offset)
            |> IterTools.take(_, count)
            |> Iter.toArray(_);
            {
                data = vals;
                offset = offset;
                count = count;
            };
        };

        public func vote(proposalId : Nat, voterId : Principal, vote : Bool) : async* Result.Result<(), VoteError> {
            let ?proposal = proposals.get(proposalId) else return #err(#proposalNotFound);
            let now = Time.now();
            let currentStatus = getProposalStatus(proposal.statusLog);
            if (proposal.timeStart > now or proposal.timeEnd < now or currentStatus != #open) {
                return #err(#votingClosed);
            };
            let ?existingVote = proposal.votes.get(voterId) else return #err(#notAuthorized); // Only allow members to vote who existed when the proposal was created
            if (existingVote.value != null) {
                return #err(#alreadyVoted);
            };
            // set user voting power

            let votingPower = await* getVotingPower(voterId);
            if (votingPower == 0 or votingPower > proposal.votingSummary.notVoted) {
                return #err(#wrongVotingPower);
            };
            Debug.print("Dao.vote: VotingSummary before vote: " # debug_show (proposal.votingSummary));
            Debug.print("Voting power: " # Nat.toText(votingPower));
            await* voteInternal(proposal, voterId, vote, votingPower);
            #ok;
        };

        public func createProposal<system>(
            proposerId : Principal,
            content : TProposalContent,
            members : [Member],
        ) : async* Result.Result<Nat, CreateProposalError> {

            switch (await* onProposalValidate(content)) {
                case (#ok) ();
                case (#err(errors)) {
                    return #err(#invalid(errors));
                };
            };

            let now = Time.now();
            let votes = HashMap.HashMap<Principal, Vote>(0, Principal.equal, Principal.hash);
            // Take snapshot of members at the time of proposal creation
            for (member in members.vals()) {
                votes.put(
                    member.id,
                    {
                        value = null;
                        votingPower = member.votingPower;
                    },
                );
            };
            let proposalId = nextProposalId;
            let proposalDurationNanoseconds = durationToNanoseconds(proposalDuration);
            let endTimerId = createEndTimer<system>(proposalId, proposalDurationNanoseconds);
            let proposal : MutableProposal<TProposalContent> = {
                id = proposalId;
                proposerId = proposerId;
                content = content;
                timeStart = now;
                timeEnd = now + proposalDurationNanoseconds;
                var endTimerId = ?endTimerId;
                votes = votes;
                statusLog = Buffer.Buffer<ProposalStatusLogEntry>(0);
                votingSummary = buildVotingSummary(votes);
            };
            proposals.put(nextProposalId, proposal);
            nextProposalId += 1;
            // Automatically vote yes for the proposer
            switch (IterTools.find(members.vals(), func(m : Member) : Bool { m.id == proposerId })) {
                case (null) (); // Skip if proposer is not a member
                case (?proposerMember) {
                    // Vote yes for proposer
                    await* voteInternal(proposal, proposerId, true, proposerMember.votingPower);
                };
            };
            #ok(proposalId);
        };

        private func voteInternal(
            proposal : MutableProposal<TProposalContent>,
            voterId : Principal,
            vote : Bool,
            votingPower : Nat,
        ) : async* () {
            proposal.votes.put(
                voterId,
                {
                    value = ?vote;
                    votingPower = votingPower;
                },
            );
            proposal.votingSummary.notVoted -= votingPower;
            if (vote) {
                proposal.votingSummary.yes += votingPower;
            } else {
                proposal.votingSummary.no += votingPower;
            };
            switch (calculateVoteStatus(proposal)) {
                case (#passed) {
                    await* executeOrRejectProposal(proposal, true);
                };
                case (#rejected) {
                    await* executeOrRejectProposal(proposal, false);
                };
                case (#undetermined) ();
            };
        };

        private func durationToNanoseconds(duration : Duration) : Nat {
            switch (duration) {
                case (#days(d)) d * 24 * 60 * 60 * 1_000_000_000;
                case (#nanoseconds(n)) n;
            };
        };

        private func createEndTimer<system>(
            proposalId : Nat,
            proposalDurationNanoseconds : Nat,
        ) : Nat {
            Timer.setTimer<system>(
                #nanoseconds(proposalDurationNanoseconds),
                func() : async () {
                    switch (await* onProposalEnd(proposalId)) {
                        case (#ok) ();
                        case (#alreadyEnded) {
                            Debug.print("EndTimer: Proposal already ended: " # Nat.toText(proposalId));
                        };
                    };
                },
            );
        };

        private func onProposalEnd(proposalId : Nat) : async* {
            #ok;
            #alreadyEnded;
        } {
            let ?mutableProposal = proposals.get(proposalId) else Debug.trap("Proposal not found for onProposalEnd: " # Nat.toText(proposalId));
            switch (getProposalStatus(mutableProposal.statusLog)) {
                case (#open) {
                    let passed = switch (calculateVoteStatus(mutableProposal)) {
                        case (#passed) true;
                        case (#rejected or #undetermined) false;
                    };
                    await* executeOrRejectProposal(mutableProposal, passed);
                    #ok;
                };
                case (_) #alreadyEnded;
            };
        };

        public func toStableData() : StableData<TProposalContent> {
            let proposalsArray = proposals.entries()
            |> Iter.map(
                _,
                func((_, v) : (Nat, MutableProposal<TProposalContent>)) : Proposal<TProposalContent> = fromMutableProposal<TProposalContent>(v),
            )
            |> Iter.toArray(_);

            {
                proposals = proposalsArray;
                proposalDuration = proposalDuration;
                votingThreshold = votingThreshold;
            };
        };

        private func executeOrRejectProposal(mutableProposal : MutableProposal<TProposalContent>, execute : Bool) : async* () {
            // TODO executing
            switch (mutableProposal.endTimerId) {
                case (null) ();
                case (?id) Timer.cancelTimer(id);
            };
            mutableProposal.endTimerId := null;
            let proposal = fromMutableProposal(mutableProposal);
            if (execute) {
                mutableProposal.statusLog.add(#executing({ time = Time.now() }));

                let newStatus : ProposalStatusLogEntry = try {
                    switch (await* onProposalExecute(proposal)) {
                        case (#ok) #executed({
                            time = Time.now();
                        });
                        case (#err(e)) #failedToExecute({
                            time = Time.now();
                            error = e;
                        });
                    };
                } catch (e) {
                    #failedToExecute({
                        time = Time.now();
                        error = Error.message(e);
                    });
                };
                mutableProposal.statusLog.add(newStatus);
            } else {
                mutableProposal.statusLog.add(#rejected({ time = Time.now() }));
                switch (await* onProposalReject(proposal)) {
                    case (#ok) ();
                    case (#err(e)) Debug.trap("onProposalReject failed: " # e);
                };

            };
        };

        private func calculateVoteStatus(proposal : MutableProposal<TProposalContent>) : {
            #undetermined;
            #passed;
            #rejected;
        } {
            let votedVotingPower = proposal.votingSummary.yes + proposal.votingSummary.no;
            let totalVotingPower = votedVotingPower + proposal.votingSummary.notVoted;
            switch (votingThreshold) {
                case (#percent({ percent; quorum })) {
                    let quorumThreshold = switch (quorum) {
                        case (null) 0;
                        case (?q) calculateFromPercent(q, totalVotingPower);
                    };
                    // The proposal must reach the quorum threshold in any case
                    if (votedVotingPower >= quorumThreshold) {
                        let hasEnded = proposal.timeEnd <= Time.now();
                        let voteThreshold = if (hasEnded) {
                            // If the proposal has reached the end time, it passes if the votes are above the threshold of the VOTED voting power
                            let votedPercent = votedVotingPower / totalVotingPower;
                            calculateFromPercent(percent, votedVotingPower);
                        } else {
                            // If the proposal has not reached the end time, it passes if votes are above the threshold (+1) of the TOTAL voting power
                            let votingThreshold = calculateFromPercent(percent, totalVotingPower) + 1;
                            if (votingThreshold >= totalVotingPower) {
                                // Safety with low total voting power to make sure the proposal can pass
                                totalVotingPower;
                            } else {
                                votingThreshold;
                            };
                        };
                        if (proposal.votingSummary.yes > proposal.votingSummary.no and proposal.votingSummary.yes >= voteThreshold) {
                            return #passed;
                        } else if (proposal.votingSummary.no > proposal.votingSummary.yes and proposal.votingSummary.no >= voteThreshold) {
                            return #rejected;
                        };
                    };
                };
            };
            return #undetermined;
        };
        resetEndTimers<system>();

    };

    private func getProposalStatus(proposalStatusLog : Buffer.Buffer<ProposalStatusLogEntry>) : ProposalStatusLogEntry or {
        #open;
    } {
        if (proposalStatusLog.size() < 1) {
            return #open;
        };
        proposalStatusLog.get(proposalStatusLog.size() - 1);
    };

    private func fromMutableProposal<TProposalContent>(proposal : MutableProposal<TProposalContent>) : Proposal<TProposalContent> = {
        proposal with
        endTimerId = proposal.endTimerId;
        votes = Iter.toArray(proposal.votes.entries());
        statusLog = Buffer.toArray(proposal.statusLog);
        votingSummary = {
            yes = proposal.votingSummary.yes;
            no = proposal.votingSummary.no;
            notVoted = proposal.votingSummary.notVoted;
        };
    };

    private func toMutableProposal<TProposalContent>(proposal : Proposal<TProposalContent>) : MutableProposal<TProposalContent> {
        let votes = HashMap.fromIter<Principal, Vote>(
            proposal.votes.vals(),
            proposal.votes.size(),
            Principal.equal,
            Principal.hash,
        );
        {
            proposal with
            var endTimerId = proposal.endTimerId;
            votes = votes;
            statusLog = Buffer.fromArray<ProposalStatusLogEntry>(proposal.statusLog);
            votingSummary = buildVotingSummary(votes);
        };
    };

    private func calculateFromPercent(percent : Percent, total : Nat) : Nat {
        Int.abs(Float.toInt(Float.ceil((Float.fromInt(percent) / 100.0) * Float.fromInt(total))));
    };

    private func buildVotingSummary(votes : HashMap.HashMap<Principal, Vote>) : VotingSummary {
        let votingSummary = {
            var yes = 0;
            var no = 0;
            var notVoted = 0;
        };

        for (vote in votes.vals()) {
            switch (vote.value) {
                case (null) {
                    votingSummary.notVoted += vote.votingPower;
                };
                case (?true) {
                    votingSummary.yes += vote.votingPower;
                };
                case (?false) {
                    votingSummary.no += vote.votingPower;
                };
            };
        };
        votingSummary;
    };

};
