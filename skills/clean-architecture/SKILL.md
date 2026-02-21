---
name: clean-architecture
description: >
  Use when creating new files, classes, or modules. Triggered by
  "new use case", "new entity", "new repository", "architecture",
  "layer", "dependency injection", "interface", "where should I put".
---

# Clean Architecture

All RDI projects with business logic follow Clean Architecture with four layers.

## Layer Diagram

```
+-----------------------------------------------------------+
|                    Presentation Layer                       |
|           (API routes, UI components, CLI)                  |
+-----------------------------------------------------------+
|                    Application Layer                        |
|              (Use cases, DTOs, orchestration)               |
+-----------------------------------------------------------+
|                   Infrastructure Layer                      |
|         (AI SDKs, databases, HTTP clients, MCP)             |
+-----------------------------------------------------------+
|                      Domain Layer                           |
|            (Entities, interfaces, value objects)             |
|              *** ZERO external dependencies ***             |
+-----------------------------------------------------------+
```

## Layer Rules

| Layer | Can Import From | Cannot Import From |
|-------|-----------------|-------------------|
| **Domain** | Nothing (pure language types only) | Any packages, any other layer |
| **Application** | Domain | Infrastructure, Presentation |
| **Infrastructure** | Domain, Application | Presentation |
| **Presentation** | All layers via DI container | Direct instantiation of infra |

## File Placement Guide

### Where does my new file go?

| Creating... | Layer | Path Example |
|-------------|-------|-------------|
| Entity / Value Object | Domain | `src/domain/entities/MyEntity.ts` |
| Interface / Contract | Domain | `src/domain/interfaces/IMyService.ts` |
| Type / Enum | Domain | `src/domain/types/MyType.ts` |
| Use Case | Application | `src/application/use-cases/MyUseCase.ts` |
| DTO | Application | `src/application/dto/MyDTO.ts` |
| Context Provider | Application | `src/application/context/MyContext.tsx` |
| Repository Impl | Infrastructure | `src/infrastructure/repositories/MyRepo.ts` |
| External Service | Infrastructure | `src/infrastructure/services/MyService.ts` |
| AI Provider | Infrastructure | `src/infrastructure/ai/MyProvider.ts` |
| API Route | Presentation | `app/api/my-route/route.ts` |
| React Component | Presentation | `app/components/MyComponent.tsx` |
| React Hook | Presentation | `app/hooks/useMyHook.ts` |

## Key Patterns

### Dependency Injection
- Define interfaces in the **Domain** layer
- Implement in the **Infrastructure** layer
- Register in the DI container (composition root)
- Inject via constructor in **Application** layer

### Use Cases
- One class per business operation
- Accept DTOs as input, return DTOs as output
- Orchestrate domain logic — never contain framework code
- Keep them small and focused (single responsibility)

### API Routes (Thin Wrappers)
- 50-70 lines maximum
- Resolve use case from DI container
- Handle only HTTP concerns: parse request, call use case, format response
- No business logic

### Composition Roots
- **Only place** where infrastructure implementations are imported
- Server-side: `src/container.ts`
- Client-side: `app/providers/ClientProviders.tsx` (or equivalent)

For detailed layer rules and code examples, see [references/layer-rules.md](references/layer-rules.md) and [references/examples.md](references/examples.md).
