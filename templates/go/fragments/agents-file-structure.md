```
cmd/
  server/
    main.go                 # Application entry point

internal/                   # Private application code
  # Add your internal packages here

pkg/                        # Public library code (if any)
  # Add shared packages here

go.mod                      # Module definition
go.sum                      # Dependency checksums

docs/
  current-tasks.md          # Track progress (read first!)
  adr/                      # Architecture decisions
  stories/                  # User stories
  requirements/             # Requirements docs
```
