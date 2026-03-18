function dev_start
    # Create a new detached session named 'flutter-dev'
    tmux new-session -d -s flutter-dev

    # Pane 1 (Bottom): Start Server
    # Use 'send-keys' to feed commands to specific panes
    tmux send-keys -t flutter-dev "cd ~/path/to/server; npm start" C-m

    # Pane 2 (Top-Right): Launch Emulator
    tmux split-window -h -t flutter-dev
    tmux send-keys -t flutter-dev "flutter emulators --launch <your_emulator_id>" C-m

    # Pane 3 (Top-Left): Run Flutter App
    tmux split-window -v -t flutter-dev
    tmux send-keys -t flutter-dev "cd ~/path/to/flutter_app; flutter run" C-m

    # Attach to the session
    tmux attach-session -t flutter-dev
end
