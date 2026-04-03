#!/bin/bash
cd /root/MT5-PropFirm-Bot
exec venv/bin/python -m futures_bot.bot "$@"
