#!/bin/bash

# Остановка dfx, если она запущена
dfx stop

# Очистка и запуск dfx
dfx start --clean --background

# Сборка проекта
dfx build

# Создание canister с циклами
dfx canister create dao-small-backend --with-cycles 10000000000

# Установка canister
dfx canister install dao-small-backend

# Вызов функции setup
dfx canister call dao-small-backend setup

echo "Setup complete"
