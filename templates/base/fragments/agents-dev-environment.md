### Layout

The recommended development setup uses tmux with 3 panes:

```
+------------------------------+----------------------+
|                              |                      |
|   Pane 1: Claude Code        |  Pane 2: Quality     |
|   (main development)         |  Gate (watch)        |
|                              |                      |
|                              +----------------------+
|                              |                      |
|                              |  Pane 3: Dev Server  |
|                              |  (or test watcher)   |
+------------------------------+----------------------+
```

### Starting the Environment

```bash
# One-command launch (from rdi-dev-env):
bash /path/to/rdi-dev-env/tmux/tmux-dev.sh /path/to/project session-name
```
