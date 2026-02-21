# Common Test Patterns

## Jest (TypeScript / Node.js)

### Basic Test Structure
```typescript
describe('MyUseCase', () => {
  let useCase: MyUseCase;
  let mockRepo: jest.Mocked<IMyRepository>;

  beforeEach(() => {
    mockRepo = {
      findById: jest.fn(),
      save: jest.fn(),
    } as jest.Mocked<IMyRepository>;
    useCase = new MyUseCase(mockRepo);
  });

  it('should return entity when found', async () => {
    mockRepo.findById.mockResolvedValue({ id: '1', name: 'Test' });

    const result = await useCase.execute('1');

    expect(result).toEqual({ id: '1', name: 'Test' });
    expect(mockRepo.findById).toHaveBeenCalledWith('1');
  });

  it('should throw when entity not found', async () => {
    mockRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('999')).rejects.toThrow('Not found');
  });
});
```

### Mocking Patterns

```typescript
// Mock an interface
const mockService: jest.Mocked<IMyService> = {
  doSomething: jest.fn(),
};

// Mock a module
jest.mock('../../infrastructure/SomeModule', () => ({
  SomeClass: jest.fn().mockImplementation(() => ({
    method: jest.fn().mockResolvedValue('result'),
  })),
}));

// Spy on an existing method
const spy = jest.spyOn(myObject, 'method').mockReturnValue('mocked');
```

### Async Testing
```typescript
// Resolved value
mockFn.mockResolvedValue(value);
mockFn.mockResolvedValueOnce(firstCallValue);

// Rejected value
mockFn.mockRejectedValue(new Error('fail'));

// Assert async errors
await expect(asyncFn()).rejects.toThrow('message');
```

## Pytest (Python)

### Basic Test Structure
```python
import pytest
from unittest.mock import AsyncMock, MagicMock

class TestMyService:
    def setup_method(self):
        self.mock_repo = MagicMock()
        self.service = MyService(repo=self.mock_repo)

    def test_returns_entity_when_found(self):
        self.mock_repo.find_by_id.return_value = {"id": "1", "name": "Test"}

        result = self.service.get("1")

        assert result == {"id": "1", "name": "Test"}
        self.mock_repo.find_by_id.assert_called_once_with("1")

    def test_raises_when_not_found(self):
        self.mock_repo.find_by_id.return_value = None

        with pytest.raises(ValueError, match="Not found"):
            self.service.get("999")
```

### Async Testing (Python)
```python
@pytest.mark.asyncio
async def test_async_operation():
    mock_client = AsyncMock()
    mock_client.fetch.return_value = {"data": "value"}

    result = await my_async_function(mock_client)

    assert result == {"data": "value"}
```

### Fixtures
```python
@pytest.fixture
def mock_repo():
    repo = MagicMock()
    repo.find_all.return_value = [{"id": "1"}, {"id": "2"}]
    return repo

def test_list_all(mock_repo):
    service = MyService(repo=mock_repo)
    result = service.list_all()
    assert len(result) == 2
```

## Go Testing

### Table-Driven Tests
```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            if result != tt.expected {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, result, tt.expected)
            }
        })
    }
}
```

### Mocking with Interfaces
```go
type MockRepo struct {
    FindByIDFunc func(id string) (*Entity, error)
}

func (m *MockRepo) FindByID(id string) (*Entity, error) {
    return m.FindByIDFunc(id)
}

func TestService(t *testing.T) {
    repo := &MockRepo{
        FindByIDFunc: func(id string) (*Entity, error) {
            return &Entity{ID: id, Name: "Test"}, nil
        },
    }
    svc := NewService(repo)
    // ...
}
```
