import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import ExperimentalInternetComputer "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";

actor {
    /**
  * Calls a canister function with raw parameters.
  * @param {Principal} canister - The principal of the canister.
  * @param {Text} functionName - The name of the function to call.
  * @param {Blob} argumentBinary - The binary representation of the argument.
  * @param {Nat} cycles - The amount of cycles to include in the call.
  * @param {Principal} caller - The caller's principal.
  * @returns {async} {Result.Result<Blob, Text>} - The result of the call.
  */
    let owner = Principal.fromText("2vxsx-fae");

    public shared ({ caller }) func call_raw(canister : Principal, functionName : Text, argumentBinary : Blob, cycles : Nat) : async Result.Result<Blob, Text> {
        Debug.print(debug_show (caller));
        assert (caller == owner);

        Debug.print("in call_raw");

        if (cycles > 0) {
            Debug.print("adding cycles");
            Cycles.add<system>(cycles);
        };

        try {
            Debug.print("trying call");
            #ok(await ExperimentalInternetComputer.call(canister, functionName, argumentBinary));
        } catch (e) {
            Debug.print("in error" # Error.message(e));
            #err(Error.message(e));
        };
    };

};
