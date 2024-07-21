#!/bin/bash

# Остановка dfx, если она запущена
echo "Stopping DFX..."
dfx stop

# # Очистка кэша и состояния
# echo "Cleaning up..."
# rm -rf .dfx

# Запуск dfx в фоновом режиме
echo "Starting DFX in background..."
dfx start --clean --background

# Деплой канистеров
echo "Deploying canisters..."
dfx deploy

# Запуск тестов
echo "Running tests..."
dfx canister call dao-small-backend runTests

echo "Test script completed."

# Остановка dfx
dfx  stop
