import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Int "mo:base/Int";
import Text "mo:base/Text";
import CT "./CommonTypes";

module {
    type ActionType = CT.ActionType;

    public class Rewards() = Self {
        // Rewards in cents FOCUS
        let FOCUS_TO_CENTS : Nat = 100;
        private var actionRewards = HashMap.HashMap<ActionType, Nat>(10, actionTypeEqual, actionTypeHash);

        // Initialize default rewards
        actionRewards.put(#Reaction, 1);
        actionRewards.put(#Review, 10);
        actionRewards.put(#Registration, 20); // TODO 1 FOCUS = 100 cents

        // TODO Staking parameters
        let STAKING_PERIODS : [Nat] = [2, 4, 6, 8]; // in years
        let STAKING_MULTIPLIERS : [Float] = [1.0, 1.5, 2.0, 3.0];
        let BASE_STAKING_REWARD_RATE : Float = 0.05; // 5% per year

        type UserRewards = {
            var totalReward : Nat;
            // TODO actionRewards : HashMap<ActionType, Nat>;
            var lastRewardTime : Time.Time;
            var votingParticipation : Nat;
            var stakedAmount : Nat;
            var stakingPeriod : Nat; // in years
            var stakingStartTime : Time.Time;
        };

        let userRewards = HashMap.HashMap<Principal, UserRewards>(10, Principal.equal, Principal.hash);

        public func setReward(actionType : ActionType, amount : Nat) : async Result.Result<(), Text> {
            actionRewards.put(actionType, amount);
            #ok(());
        };

        public func getReward(actionType : ActionType) : async Result.Result<Nat, Text> {
            switch (actionRewards.get(actionType)) {
                case (?reward) #ok(reward);
                case null #err("Reward not found for action type");
            };
        };

        public func getRewards() : async [(Text, Nat)] {
            let rewards = Iter.toArray(actionRewards.entries());
            Array.map<(ActionType, Nat), (Text, Nat)>(rewards, func(entry) { (CT.actionTypeToString(entry.0), entry.1) });
        };

        public func getUserReward(user : Principal) : async Nat {
            switch (userRewards.get(user)) {
                case null 0;
                case (?reward) reward.totalReward;
            };
        };

        public func rewardAction(user : Principal, actionType : ActionType) : async Result.Result<(), Text> {
            switch (actionRewards.get(actionType)) {
                case (?reward) {
                    Debug.print("Rewarding action: " # CT.actionTypeToString(actionType) # " to user: " # Principal.toText(user) # " with reward: " # Nat.toText(reward));
                    await addReward(user, reward);
                    #ok(());
                };
                case null #err("Invalid action type");
            };
        };

        private var votingRewards = HashMap.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);

        public func rewardVoting(user : Principal, proposalId : Nat) : async Nat {
            Debug.print("Rewarding voting participation for user: " # Principal.toText(user) # " for proposal: " # Nat.toText(proposalId));
            let userReward = switch (userRewards.get(user)) {
                case null {
                    let newReward = {
                        var totalReward = 1;
                        var lastRewardTime = Time.now();
                        var votingParticipation = 1;
                        var stakedAmount = 0;
                        var stakingPeriod = 0;
                        var stakingStartTime = Time.now();
                    };
                    userRewards.put(user, newReward);

                    newReward;
                };
                case (?reward) {
                    reward.votingParticipation += 1;
                    reward.totalReward += 1;
                    reward;
                };
            };
            votingRewards.put(user, userReward.votingParticipation);
            userReward.votingParticipation;
        };

        public func getVotingRewards() : async {
            totalReward : Nat;
            rewards : [(Principal, Nat)];
        } {
            let rewards = Iter.toArray(votingRewards.entries());
            let totalReward = Array.foldLeft<(Principal, Nat), Nat>(rewards, 0, func(acc, entry) { acc + entry.1 });
            { totalReward; rewards };
        };

        public func resetVotingRewards() : async () {
            votingRewards := HashMap.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);
        };

        public func resetUserReward(user : Principal) : async Result.Result<(), Text> {
            switch (userRewards.get(user)) {
                case null #err("User not found");
                case (?reward) {
                    userRewards.put(
                        user,
                        {
                            var totalReward = 0;
                            var lastRewardTime = reward.lastRewardTime;
                            var votingParticipation = 0;
                            var stakedAmount = reward.stakedAmount;
                            var stakingPeriod = reward.stakingPeriod;
                            var stakingStartTime = reward.stakingStartTime;
                        },
                    );
                    #ok(());
                };
            };
        };

        public func addReward(user : Principal, rewardCents : Nat) : async () {
            Debug.print("RewardSystem.addReward: Adding reward of " # Nat.toText(rewardCents) # " cents FOCUS to user: " # Principal.toText(user));
            switch (userRewards.get(user)) {
                case null {
                    userRewards.put(
                        user,
                        {
                            var totalReward = rewardCents;
                            var lastRewardTime = Time.now();
                            var votingParticipation = 0;
                            var stakedAmount = 0;
                            var stakingPeriod = 0;
                            var stakingStartTime = Time.now();
                        },
                    );
                    Debug.print("RewardSystem.addReward: Added reward of " # Nat.toText(rewardCents) # " cents FOCUS to user: " # Principal.toText(user));
                };
                case (?reward) {
                    reward.totalReward += rewardCents;
                    reward.lastRewardTime := Time.now();
                    Debug.print("RewardSystem.addReward: Change reward to " # Nat.toText(reward.totalReward) # " cents FOCUS to user: " # Principal.toText(user));
                };
            };
        };

        public func convertRewardToFocus(user : Principal) : async Result.Result<Nat, Text> {
            switch (userRewards.get(user)) {
                case null #err("User not found");
                case (?reward) {
                    if (reward.totalReward < FOCUS_TO_CENTS) {
                        return #err("Insufficient reward balance for convertion");
                    };
                    Debug.print("RewardSystem.convertRewardToFocus: Converting reward of " # Nat.toText(reward.totalReward) # " cents FOCUS to user: " # Principal.toText(user));
                    let focusTokens = reward.totalReward / FOCUS_TO_CENTS;
                    // if (focusTokens == 0) {
                    //     return #err("Insufficient reward balance");
                    // };
                    reward.totalReward := reward.totalReward % FOCUS_TO_CENTS;
                    // Here should be logic for actual transfer of FOCUS tokens to the user
                    #ok(focusTokens);
                };
            };
        };

        public func stakeRewards(user : Principal, amount : Nat, period : Nat) : async Result.Result<(), Text> {
            switch (userRewards.get(user)) {
                case null return #err("User not found");
                case (?reward) {
                    if (reward.totalReward < amount * FOCUS_TO_CENTS) {
                        return #err("Insufficient reward balance");
                    };
                    if (not contains<Nat>(STAKING_PERIODS, period, Nat.equal)) {
                        return #err("Invalid staking period");
                    };
                    reward.totalReward -= amount * FOCUS_TO_CENTS;
                    reward.stakedAmount += amount;
                    reward.stakingPeriod := period;
                    reward.stakingStartTime := Time.now();
                    #ok(());
                };
            };
        };

        public func calculateStakingReward(user : Principal) : async Result.Result<Nat, Text> {
            switch (userRewards.get(user)) {
                case null #err("User not found");
                case (?reward) {
                    if (reward.stakedAmount == 0) {
                        return #err("No staked amount");
                    };
                    let stakingDuration = (Time.now() - reward.stakingStartTime) / (365 * 24 * 60 * 60 * 1_000_000_000);
                    if (stakingDuration < 1) {
                        return #err("Staking period not reached");
                    };
                    let multiplierIndex = Array.indexOf<Nat>(reward.stakingPeriod, STAKING_PERIODS, Nat.equal);
                    let multiplier = switch (multiplierIndex) {
                        case null 1.0;
                        case (?index) STAKING_MULTIPLIERS[index];
                    };
                    let annualReward = Float.fromInt(reward.stakedAmount) * BASE_STAKING_REWARD_RATE * multiplier;
                    let totalReward = annualReward * Float.fromInt(Int.min(stakingDuration, reward.stakingPeriod));
                    #ok(Nat32.toNat(Nat32.fromIntWrap(Float.toInt(totalReward * 100.0)))) // Convert to cents FOCUS
                };
            };
        };

        public func unstake(user : Principal) : async Result.Result<Nat, Text> {
            switch (userRewards.get(user)) {
                case null #err("User not found");
                case (?reward) {
                    if (reward.stakedAmount == 0) {
                        return #err("No staked amount");
                    };
                    let stakingReward = switch (await calculateStakingReward(user)) {
                        case (#ok(amount)) amount;
                        case (#err(e)) return #err(e);
                    };
                    let totalUnstaked = reward.stakedAmount * FOCUS_TO_CENTS + stakingReward;
                    reward.totalReward += totalUnstaked;
                    let unstakeAmount = reward.stakedAmount;
                    reward.stakedAmount := 0;
                    reward.stakingPeriod := 0;
                    #ok(unstakeAmount);
                };
            };
        };
    };

    private func contains<T>(array : [T], element : T, equal : (T, T) -> Bool) : Bool {
        for (item in array.vals()) {
            if (equal(item, element)) {
                return true;
            };
        };
        false;
    };

    func _validateRewardName(rewardName : Text) : Bool {
        switch (rewardName) {
            case "reaction" true;
            case "review" true;
            case "registration" true;
            case "voting" true;
            case _ false;
        };
    };

    private func actionTypeEqual(a : ActionType, b : ActionType) : Bool {
        switch (a, b) {
            case (#Reaction, #Reaction) true;
            case (#Review, #Review) true;
            case (#Registration, #Registration) true;
            case (#Custom(textA), #Custom(textB)) Text.equal(textA, textB);
            case _ false;
        };
    };

    private func actionTypeHash(a : ActionType) : Nat32 {
        switch (a) {
            case (#Reaction) 1;
            case (#Review) 2;
            case (#Registration) 3;
            case (#Custom(text)) Text.hash(text);
        };
    };

};
