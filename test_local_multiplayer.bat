@echo off
echo ========================================
echo    Godot Multiplayer Test Setup
echo ========================================
echo.
echo This will help you test your multiplayer game locally
echo.
echo 1. First, start the DEDICATED SERVER:
echo    - Open Godot
echo    - Load: coop/scenes/dedicated_server.tscn
echo    - Press F5 to run
echo    - Keep this window open
echo.
echo 2. Then, start CLIENTS:
echo    - Open Godot again (or use multiple instances)
echo    - Load: coop/scenes/client.tscn
echo    - Press F5 to run
echo    - Repeat for multiple clients
echo.
echo 3. Test the chat system:
echo    - Press Enter to open chat
echo    - Type messages and press Enter to send
echo    - Chat bubbles should appear above players
echo.
echo Press any key to continue...
pause > nul
