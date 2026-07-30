#!/usr/bin/env bash

BOT_TOKEN="ISI_DENGAN_BOT_TOKEN_KAMU"
CHAT_ID="ISI_DENGAN_CHAT_ID_KAMU"

MSG="$1"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="🚨 [Pi Node Alert]\n${MSG}" \
  -d parse_mode="HTML"
