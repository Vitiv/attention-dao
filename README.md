# `Attention DAO Alfa version`

**Version for community testing and dicussion.**

# Attention DAO

Attention DAO is a Decentralized Autonomous Organization built on the Internet Computer blockchain. It manages and develops the Event Hub Broadcaster, a decentralized infrastructure for sending event-driven messages and receiving reactions to them.

## Table of Contents

- [`Attention DAO Alfa version`](#attention-dao-alfa-version)
- [Attention DAO](#attention-dao)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Local Testing](#local-testing)
  - [Deployment](#deployment)
  - [Usage](#usage)
    - [Interacting with the DAO](#interacting-with-the-dao)
    - [Key Features](#key-features)
    - [Example: Creating a Proposal](#example-creating-a-proposal)
    - [Example: Voting on a Proposal](#example-voting-on-a-proposal)
  - [DAO Module](#dao-module)
    - [Creating a DAO Instance](#creating-a-dao-instance)
    - [Key DAO Operations](#key-dao-operations)
  - [Contributing](#contributing)
  - [License](#license)

## Prerequisites

Before you begin, ensure you have the following installed:

- [DFINITY Canister SDK](https://sdk.dfinity.org/docs/quickstart/local-quickstart.html)
- [mops](https://mops.one)

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/your-username/attention-dao.git
   cd attention-dao
   ```

2. Install the project dependencies:
   ```
   mops install
   ```
   
## Local Testing

To test the project deployment locally, use the 

```
sh ./setup_and_tests.sh
```
   

## Deployment

1. Start the local Internet Computer replica:
   ```
   dfx start --background
   ```

2. Deploy the canisters:
   ```
   dfx deploy
   ```

3. Once deployed, the CLI will display the canister IDs and web interfaces for your project.


## Usage

### Interacting with the DAO

1. Access the DAO frontend by opening the URL provided after deployment.

2. Connect your Internet Identity to authenticate.

3. Once authenticated, you can:
   - Create proposals
   - Vote on existing proposals
   - Publish events
   - Subscribe to events
   - React to notifications

### Key Features

- **Proposal Creation and Voting**: Members can create proposals and vote on them to influence the DAO's decisions.
- **Event Publishing**: Users can publish events through the Event Hub Broadcaster.
- **Event Subscription**: Users can subscribe to events based on their interests.
- **Reward System**: Users are rewarded with $FOCUS tokens for various activities within the ecosystem.
- **Tokenomics**: The $FOCUS token is at the heart of the Attention DAO economy, incentivizing participation and governance.

### Example: Creating a Proposal

```javascript
import { dao_backend } from './<your_dao_handler>.js';

async function createProposal(description, action) {
  const daoActor = await dao_backend();
  const proposalContent = {
    other: { description, action }
  };
  const result = await daoActor.createProposal(proposalContent);
  console.log("Proposal creation result:", result);
}

createProposal("Implement new feature", "Add user profiles to the platform");
```

### Example: Voting on a Proposal

```javascript
import { dao_backend } from './<your_dao_handler>.js';

async function voteOnProposal(proposalId, vote) {
  const daoActor = await dao_backend();
  const result = await daoActor.vote(proposalId, vote);
  console.log("Voting result:", result);
}

voteOnProposal(1, true); // Vote 'yes' on proposal with ID 1

## Deployment

1. Start the local Internet Computer replica:
   ```
   dfx start --background
   ```

2. Deploy the canisters:
   ```
   dfx deploy
   ```

3. Once deployed, the CLI will display the canister IDs and web interfaces for your project.

## Usage

### Interacting with the DAO

1. Access the DAO frontend by opening the URL provided after deployment.

2. Connect your Internet Identity to authenticate.

3. Once authenticated, you can:
   - Create proposals
   - Vote on existing proposals
   - Publish events
   - Subscribe to events
   - React to notifications

### Key Features

- **Proposal Creation and Voting**: Members can create proposals and vote on them to influence the DAO's decisions.
- **Event Publishing**: Users can publish events through the Event Hub Broadcaster.
- **Event Subscription**: Users can subscribe to events based on their interests.
- **Reward System**: Users are rewarded with $FOCUS tokens for various activities within the ecosystem.
- **Tokenomics**: The $FOCUS token is at the heart of the Attention DAO economy, incentivizing participation and governance.

### Example: Creating a Proposal

```javascript
import { dao_backend } from './<your_dao_handler>.js';

async function createProposal(description, action) {
  const daoActor = await dao_backend();
  const proposalContent = {
    other: { description, action }
  };
  const result = await daoActor.createProposal(proposalContent);
  console.log("Proposal creation result:", result);
}

createProposal("Implement new feature", "Add user profiles to the platform");
```

### Example: Voting on a Proposal

```javascript
import { dao_backend } from './<your_dao_handler>.js';

async function voteOnProposal(proposalId, vote) {
  const daoActor = await dao_backend();
  const result = await daoActor.vote(proposalId, vote);
  console.log("Voting result:", result);
}

voteOnProposal(1, true); // Vote 'yes' on proposal with ID 1
```

## DAO Module

__DAO module based on Ethan Celletti's code https://github.com/edjCase/daoball/blob/main/src/backend/Dao.mo__

The central component of Attention DAO is the DAO module, implemented in the `Dao.mo` file. This module provides core functionality for managing proposals, voting, and executing DAO decisions.

### Creating a DAO Instance

To create a DAO instance, the `Dao` class is used. Here's what its constructor looks like:

```motoko
public class Dao<system, TProposalContent>(
    data : StableData<TProposalContent>,
    onProposalExecute : Proposal<TProposalContent> -> async* Result.Result<(), Text>,
    onProposalReject : Proposal<TProposalContent> -> async* CommonTypes.CommonResult,
    onProposalValidate : TProposalContent -> async* Result.Result<(), [Text]>,
    getVotingPower : Principal -> async* Nat,
)
```

Constructor parameters:
- `data`: Initial DAO data, including existing proposals, voting duration, and voting thresholds.
- `onProposalExecute`: Function for executing accepted proposals.
- `onProposalReject`: Function called when a proposal is rejected.
- `onProposalValidate`: Function for validating new proposals.
- `getVotingPower`: Function for getting a member's voting power.

Example of creating a DAO instance:

```motoko
import DAO "Dao";
import Types "types";
import Result "mo:base/Result";
import CommonTypes "CommonTypes";

actor Main {
    let dao = DAO.Dao<system, Types.ProposalContent>(
        // Initial DAO data
        {
            proposals = [];
            proposalDuration = #days(7);
            votingThreshold = #percent({ percent = 51; quorum = ?25 });
        },
        // Proposal execution function
        func (proposal : DAO.Proposal<Types.ProposalContent>) : async* Result.Result<(), Text> {
            // Implementation of proposal execution
        },
        // Proposal rejection function
        func (proposal : DAO.Proposal<Types.ProposalContent>) : async* CommonTypes.CommonResult {
            // Implementation of proposal rejection
        },
        // Proposal validation function
        func (content : Types.ProposalContent) : async* Result.Result<(), [Text]> {
            // Implementation of proposal validation
        },
        // Voting power retrieval function
        func (principal : Principal) : async* Nat {
            // Implementation of getting voting power
        }
    );

    // Use the dao instance to interact with the DAO
}
```

This example shows how to create a DAO instance with the necessary parameters and callback functions. You can customize these functions according to your specific DAO requirements.

### Key DAO Operations

Once you have created a DAO instance, you can use it to perform various operations:

1. Create a proposal:
   ```motoko
   public func createProposal(content : Types.ProposalContent) : async Result.Result<Nat, DAO.CreateProposalError> {
       await* dao.createProposal(caller, content, currentMembers);
   }
   ```

2. Vote on a proposal:
   ```motoko
   public func vote(proposalId : Nat, voter : Principal, vote : Bool) : async Result.Result<(), DAO.VoteError> {
       await* dao.vote(proposalId, voter, vote);
   }
   ```

3. Get proposal details:
   ```motoko
   public query func getProposal(id : Nat) : async ?DAO.Proposal<Types.ProposalContent> {
       dao.getProposal(id);
   }
   ```

4. List proposals:
   ```motoko
   public query func getProposals(count : Nat, offset : Nat) : async CommonTypes.PagedResult<DAO.Proposal<Types.ProposalContent>> {
       dao.getProposals(count, offset);
   }
   ```

These operations form the core functionality of the DAO, allowing members to create and vote on proposals, as well as retrieve information about existing proposals.

Remember to implement proper access control and validation in your actual DAO canister to ensure that only authorized members can perform these actions.

## Contributing

We welcome contributions to the Attention DAO project! Please follow these steps to contribute:

1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Make your changes and commit them with a clear commit message
4. Push your changes to your fork
5. Create a pull request to the main repository

Please ensure your code adheres to the project's coding standards and include tests for new features.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
