#!/bin/bash

# Stop dfx, if it's running
dfx stop

# Clean and start the replica
dfx start --clean --background

# Build the project
dfx deploy

# Call the initLedger function
dfx canister call dao-small-backend initLedger

echo "Setup completed"

dfx canister call dao-small-backend runTests

echo "Tests completed"

dfx stop
