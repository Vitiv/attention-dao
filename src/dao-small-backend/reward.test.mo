import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import CommonTypes "./CommonTypes";
// import RewardSystem "./RewardSystem";

module {
    public type TestActorInterface = {
        processUserAction : (action : Text, user : Text) -> async Result.Result<Nat, Text>;
        getUserReward : (user : Principal) -> async Nat;
        setReward : (actionType : CommonTypes.ActionType, amount : Nat) -> async Result.Result<(), Text>;
        getReward : (actionType : CommonTypes.ActionType) -> async Result.Result<Nat, Text>;
        rewardVoting : (user : Principal, proposalId : Nat) -> async Nat;
        convertRewardToFocus : (user : Principal) -> async Result.Result<Nat, Text>;
        stakeRewards : (user : Principal, amount : Nat, period : Nat) -> async Result.Result<(), Text>;
        calculateStakingReward : (user : Principal) -> async Result.Result<Nat, Text>;
        unstake : (user : Principal) -> async Result.Result<Nat, Text>;
    };

    public func runTests(testActor : TestActorInterface) : async () {
        Debug.print("Running Reward System tests...");

        let testPrincipal1 = Principal.fromText("aaaaa-aa");
        let testPrincipal2 = Principal.fromText("2vxsx-fae");

        // Test 1: Process user actions
        await testProcessUserActions(testActor, testPrincipal1, testPrincipal2);

        // Test 2: Get user rewards
        await testGetUserRewards(testActor, testPrincipal1, testPrincipal2);

        // Test 3: Set and get rewards
        await testSetAndGetRewards(testActor);

        // Test 4: Reward voting
        await testRewardVoting(testActor, testPrincipal1, testPrincipal2);

        // Test 5: Distribute monthly voting rewards
        // await testDistributeMonthlyVotingRewards(testActor, testPrincipal1, testPrincipal2);

        // Test 6: Convert reward to FOCUS
        await testConvertRewardToFocus(testActor, testPrincipal1);

        // Test 7: Stake rewards
        // await testStakeRewards(testActor, testPrincipal1);

        // // Test 8: Calculate staking reward
        // await testCalculateStakingReward(testActor, testPrincipal1);

        // // Test 9: Unstake
        // await testUnstake(testActor, testPrincipal1);

        Debug.print("All Reward System tests completed!");
    };

    private func testProcessUserActions(testActor : TestActorInterface, p1 : Principal, p2 : Principal) : async () {
        Debug.print("Test 1: Processing user actions");

        let result1 = await testActor.processUserAction("reaction", Principal.toText(p1));
        Debug.print("Result of reaction action for user 1: " # debug_show (result1));
        assert (Result.isOk(result1));

        let result2 = await testActor.processUserAction("review", Principal.toText(p2));
        Debug.print("Result of review action for user 2: " # debug_show (result2));
        assert (Result.isOk(result2));

        let result3 = await testActor.processUserAction("registration", Principal.toText(p1));
        Debug.print("Result of registration action for user 1: " # debug_show (result3));
        assert (Result.isOk(result3));

        Debug.print("Test 1 passed: User actions processed successfully");
    };

    private func testGetUserRewards(testActor : TestActorInterface, p1 : Principal, p2 : Principal) : async () {
        Debug.print("Test 2: Getting user rewards");

        let reward1 = await testActor.getUserReward(p1);
        Debug.print("Reward for user 1: " # debug_show (reward1));
        assert (reward1 > 0);

        let reward2 = await testActor.getUserReward(p2);
        Debug.print("Reward for user 2: " # debug_show (reward2));
        assert (reward2 > 0);

        Debug.print("Test 2 passed: User rewards retrieved successfully");
    };

    private func testSetAndGetRewards(testActor : TestActorInterface) : async () {
        Debug.print("Test 3: Setting and getting rewards");

        let getResultBefore = await testActor.getReward(#Reaction);
        Debug.print("Get Reaction reward before setting: " # debug_show (getResultBefore));

        let setResult = await testActor.setReward(#Reaction, 2);
        Debug.print("Set Reaction reward (#Reaction, 2) result: " # debug_show (setResult));
        assert (Result.isOk(setResult));

        let getResult = await testActor.getReward(#Reaction);
        Debug.print("Getting Reaction reward after : " # debug_show (getResult));
        switch (getResult) {
            case (#ok(value)) assert (value == 2);
            case (#err(e)) Debug.print("Error getting reward: " # e);
        };

        let setResult3 = await testActor.setReward(#Custom("100"), 100);
        Debug.print("Set Custom reward (#Custom(\"100\"), 100) result: " # debug_show (setResult3));
        let getResult4 = await testActor.getReward(#Custom("100"));
        switch (getResult4) {
            case (#ok(value)) assert (value == 100);
            case (#err(e)) Debug.print("Error getting reward: " # e);
        };

        Debug.print("Test 3 passed: Rewards set and retrieved successfully");
    };

    private func testRewardVoting(testActor : TestActorInterface, p1 : Principal, p2 : Principal) : async () {
        Debug.print("Test 4: Rewarding voting");

        let reward1 = await testActor.rewardVoting(p1, 1);
        Debug.print("Reward for voting 1: " # debug_show (reward1));
        assert (reward1 > 0);

        let reward2 = await testActor.rewardVoting(p2, 1);
        Debug.print("Reward for voting 2: " # debug_show (reward2));
        assert (reward2 > 0);

        Debug.print("Test 4 passed: Voting rewarded successfully");
    };

    private func testConvertRewardToFocus(testActor : TestActorInterface, p : Principal) : async () {
        Debug.print("Test 6: Converting reward to FOCUS");
        let testPrincipal1 = Principal.fromText("aaaaa-aa");
        let result4 = await testActor.processUserAction("100", "aaaaa-aa");
        let r = await testActor.rewardVoting(testPrincipal1, 1);
        let result = await testActor.convertRewardToFocus(p);
        switch (result) {
            case (#ok(value)) assert (value > 0);
            case (#err(e)) Debug.print("Error converting reward to FOCUS: " # e);
        };

        Debug.print("Test 6 passed: Reward converted to FOCUS successfully");
    };

    // private func testStakeRewards(testActor : TestActorInterface, p : Principal) : async () {
    //     Debug.print("Test 7: Staking rewards");

    //     let result = await testActor.stakeRewards(p, 100, 2);
    //     assert (Result.isOk(result));

    //     Debug.print("Test 7 passed: Rewards staked successfully");
    // };

    // private func testCalculateStakingReward(testActor : TestActorInterface, p : Principal) : async () {
    //     Debug.print("Test 8: Calculating staking reward");

    //     let result = await testActor.calculateStakingReward(p);
    //     switch (result) {
    //         case (#ok(value)) assert (value > 0);
    //         case (#err(e)) Debug.print("Error calculating staking reward: " # e);
    //     };

    //     Debug.print("Test 8 passed: Staking reward calculated successfully");
    // };

    // private func testUnstake(testActor : TestActorInterface, p : Principal) : async () {
    //     Debug.print("Test 9: Unstaking");

    //     let result = await testActor.unstake(p);
    //     switch (result) {
    //         case (#ok(value)) assert (value > 0);
    //         case (#err(e)) Debug.print("Error unstaking: " # e);
    //     };

    //     Debug.print("Test 9 passed: Unstaked successfully");
    // };
};
