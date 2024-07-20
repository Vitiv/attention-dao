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

module {
    public class Rewards() = Self {
        // Rewards in cents FOCUS
        var REACTION_REWARD : Nat = 1;
        var REVIEW_REWARD : Nat = 10;
        var REGISTRATION_REWARD : Nat = 20;
        let FOCUS_TO_CENTS : Nat = 100; // 1 FOCUS = 100 cents

        // Staking parameters
        let STAKING_PERIODS : [Nat] = [2, 4, 6, 8]; // in years
        let STAKING_MULTIPLIERS : [Float] = [1.0, 1.5, 2.0, 3.0];
        let BASE_STAKING_REWARD_RATE : Float = 0.05; // 5% per year

        type UserRewards = {
            var totalReward : Nat;
            var lastRewardTime : Time.Time;
            var votingParticipation : Nat;
            var stakedAmount : Nat;
            var stakingPeriod : Nat; // in years
            var stakingStartTime : Time.Time;
        };

        let userRewards = HashMap.HashMap<Principal, UserRewards>(10, Principal.equal, Principal.hash);

        public func setReward(rewardName : Text, amount : Nat) : Result.Result<(), Text> {
            switch (rewardName) {
                case "reaction" { REACTION_REWARD := amount; #ok(()) };
                case "review" { REVIEW_REWARD := amount; #ok(()) };
                case "registration" { REGISTRATION_REWARD := amount; #ok(()) };
                case _ { #err("Invalid reward name: " # rewardName) };
            };
        };

        public func getReward(user : Principal) : async Nat {
            switch (userRewards.get(user)) {
                case null 0;
                case (?reward) reward.totalReward;
            };
        };

        public func rewardAction(user : Principal, actionType : Text) : async Result.Result<(), Text> {
            let reward = switch (actionType) {
                case "reaction" REACTION_REWARD;
                case "review" REVIEW_REWARD;
                case "registration" REGISTRATION_REWARD;
                case _ return #err("Invalid action type");
            };

            await addReward(user, reward);
            #ok(());
        };

        public func rewardVoting(user : Principal, proposalId : Nat) : async Nat {
            Debug.print("Rewarding voting participation for user: " # Principal.toText(user) # " for proposal: " # Nat.toText(proposalId));
            let userReward = switch (userRewards.get(user)) {
                case null {
                    let newReward = {
                        var totalReward = 0;
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
                    reward;
                };
            };
            userReward.totalReward;
        };

        public func distributeMonthlyVotingRewards() : async () {
            let totalVotes = Array.foldLeft<UserRewards, Nat>(
                Iter.toArray(userRewards.vals()),
                0,
                func(acc, reward) { acc + reward.votingParticipation },
            );

            for ((user, reward) in userRewards.entries()) {
                let baseReward : Float = 0.005; // 0.5% per month
                let userVotingReward : Float = baseReward * (Float.fromInt(reward.votingParticipation) / Float.fromInt(totalVotes));
                let rewardInFocus : Nat = Nat32.toNat(Nat32.fromIntWrap(Float.toInt(userVotingReward * 100.0))); // Convert to cents FOCUS
                await addReward(user, rewardInFocus);
                reward.votingParticipation := 0; // Reset voting counter
            };
        };

        private func addReward(user : Principal, rewardCents : Nat) : async () {
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
                };
                case (?reward) {
                    reward.totalReward += rewardCents;
                    reward.lastRewardTime := Time.now();
                };
            };
        };

        public func convertRewardToFocus(user : Principal) : async Result.Result<Nat, Text> {
            switch (userRewards.get(user)) {
                case null #err("User not found");
                case (?reward) {
                    let focusTokens = reward.totalReward / FOCUS_TO_CENTS;
                    if (focusTokens == 0) {
                        return #err("Insufficient reward balance");
                    };
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
};
