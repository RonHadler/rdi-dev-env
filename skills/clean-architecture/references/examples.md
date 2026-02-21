# Clean Architecture Code Examples

## Good: Complete Feature (TypeScript)

### 1. Domain: Entity + Interface

```typescript
// src/domain/entities/Report.ts
export interface Report {
  id: string;
  title: string;
  clientId: string;
  content: string;
  createdAt: Date;
}
```

```typescript
// src/domain/interfaces/IReportRepository.ts
export interface IReportRepository {
  findById(id: string): Promise<Report | null>;
  findByClient(clientId: string): Promise<Report[]>;
  save(report: Report): Promise<void>;
  delete(id: string): Promise<void>;
}
```

### 2. Application: Use Case + DTO

```typescript
// src/application/dto/CreateReportDTO.ts
export interface CreateReportDTO {
  title: string;
  clientId: string;
  content: string;
}

export interface CreateReportResultDTO {
  id: string;
  createdAt: Date;
}
```

```typescript
// src/application/use-cases/CreateReportUseCase.ts
import { injectable, inject } from 'tsyringe';
import { IReportRepository } from '@/domain/interfaces/IReportRepository';
import { CreateReportDTO, CreateReportResultDTO } from '../dto/CreateReportDTO';

@injectable()
export class CreateReportUseCase {
  constructor(
    @inject('IReportRepository') private reportRepo: IReportRepository
  ) {}

  async execute(dto: CreateReportDTO): Promise<CreateReportResultDTO> {
    const report = {
      id: crypto.randomUUID(),
      title: dto.title,
      clientId: dto.clientId,
      content: dto.content,
      createdAt: new Date(),
    };

    await this.reportRepo.save(report);

    return { id: report.id, createdAt: report.createdAt };
  }
}
```

### 3. Infrastructure: Repository Implementation

```typescript
// src/infrastructure/repositories/FirestoreReportRepository.ts
import { injectable } from 'tsyringe';
import { getFirestore } from 'firebase-admin/firestore';
import { IReportRepository } from '@/domain/interfaces/IReportRepository';
import { Report } from '@/domain/entities/Report';

@injectable()
export class FirestoreReportRepository implements IReportRepository {
  private collection = getFirestore().collection('reports');

  async findById(id: string): Promise<Report | null> {
    const doc = await this.collection.doc(id).get();
    return doc.exists ? (doc.data() as Report) : null;
  }

  async findByClient(clientId: string): Promise<Report[]> {
    const snapshot = await this.collection
      .where('clientId', '==', clientId)
      .get();
    return snapshot.docs.map(doc => doc.data() as Report);
  }

  async save(report: Report): Promise<void> {
    await this.collection.doc(report.id).set(report);
  }

  async delete(id: string): Promise<void> {
    await this.collection.doc(id).delete();
  }
}
```

### 4. Presentation: API Route (Thin Wrapper)

```typescript
// app/api/reports/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { container } from '@/container';
import { CreateReportUseCase } from '@/application/use-cases/CreateReportUseCase';
import { verifyAuth, isSysadmin } from '../_lib/auth';

export async function POST(request: NextRequest) {
  const user = await verifyAuth(request);
  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await request.json();
  const useCase = container.resolve(CreateReportUseCase);
  const result = await useCase.execute({
    title: body.title,
    clientId: user.clientId,
    content: body.content,
  });

  return NextResponse.json(result, { status: 201 });
}
```

---

## Bad: Common Anti-Patterns

### Domain Importing npm Package
```typescript
// src/domain/entities/Analysis.ts
import { Timestamp } from 'firebase-admin/firestore'; // VIOLATION
```

**Fix:** Use plain `Date` in domain, convert in infrastructure.

### Business Logic in API Route
```typescript
// app/api/analyze/route.ts
export async function POST(request: NextRequest) {
  // 200+ lines of business logic...
  const client = new Anthropic({ apiKey: process.env.CLAUDE_API_KEY });
  const data = await fetchFromMCP(query);
  const analysis = await client.messages.create({...});
  // ... more logic ...
}
```

**Fix:** Extract to a use case, inject dependencies.

### Hard-coded Dependency
```typescript
// src/application/use-cases/ProcessQuery.ts
import { ClaudeProvider } from '@/infrastructure/ai/ClaudeProvider'; // VIOLATION

export class ProcessQuery {
  private provider = new ClaudeProvider(); // Can't test, can't swap
}
```

**Fix:** Define `IAIProvider` interface in domain, inject it.

## Good: Python Example

```python
# domain/interfaces/report_repository.py
from abc import ABC, abstractmethod
from domain.entities.report import Report

class IReportRepository(ABC):
    @abstractmethod
    async def find_by_id(self, id: str) -> Report | None: ...

    @abstractmethod
    async def save(self, report: Report) -> None: ...
```

```python
# application/use_cases/create_report.py
from domain.interfaces.report_repository import IReportRepository

class CreateReportUseCase:
    def __init__(self, repo: IReportRepository):
        self._repo = repo

    async def execute(self, title: str, content: str) -> Report:
        report = Report(title=title, content=content)
        await self._repo.save(report)
        return report
```
