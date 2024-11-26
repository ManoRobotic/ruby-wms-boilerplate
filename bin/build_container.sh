#!/bin/bash

npx @devcontainers/cli build --workspace-folder .
npx @devcontainers/cli up --workspace-folder .
bin/bundle i 
bin/rails db:create db:migrate db:seed