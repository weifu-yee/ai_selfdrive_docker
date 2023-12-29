#!/bin/bash

SESSION="ai-seldri"
tmux new-session -d -s $SESSION
tmux send-keys -t $SESSION:1 '. ~/sconsvenv/bin/activate && ./selfdrive/ui/ui' C-m
tmux split-window -v -p 80 -t $SESSION:1
tmux send-keys -t $SESSION:1 '. ~/sconsvenv/bin/activate && cd tools/replay && ./replayJLL  --demo' C-m
tmux attach-session -t $SESSION