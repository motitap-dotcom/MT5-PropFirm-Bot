#!/bin/bash
# Start bot from venv with correct working directory
cd /root/MT5-PropFirm-Bot
exec venv/bin/python -m futures_bot.bot "$@"
