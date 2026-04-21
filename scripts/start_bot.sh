#!/bin/bash
# Wrapper so PYTHONPATH is always set, regardless of service file environment.
# If the service file ever gets regenerated without Environment=PYTHONPATH,
# the bot still starts because PYTHONPATH is hardcoded here.
export PYTHONPATH=/root/MT5-PropFirm-Bot
cd /root/MT5-PropFirm-Bot
exec /usr/bin/python3 -m futures_bot.bot
