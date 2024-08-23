import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";

module {
    public type Role = {
        #Admin;
        #Member;
        #Guest;
    };

    public class AllowList() {
        private let users = HashMap.HashMap<Principal, Role>(10, Principal.equal, Principal.hash);

        public func setUserRole(user : Principal, role : Role) : async (){
            users.put(user, role);
        };

        public func removeUser(user : Principal) : async (){
            users.delete(user);
        };

        public func getRole(user : Principal) : async ?Role {
            users.get(user)
        };

        public func hasRole(user : Principal, role : Role) : async Bool {
            switch (users.get(user)) {
                case (?userRole) { userRole == role };
                case (null) { false };
            }
        };
    }
}
