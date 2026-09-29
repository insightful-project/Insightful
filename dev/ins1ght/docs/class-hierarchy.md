# Class Hierarchy — Superclass Contracts

> **2026-07-15 architecture update**: NestJS stubs no longer extend `Foundation<T>`. All 10 life-os-v2 stubs are now plain `@Injectable()` classes using direct Drizzle ORM. `Foundation<T>` remains the pattern for Java codeSpace entities and for any new entity that uses the JSONB DomainEntity table structure. See `ai-framework/ai-memory/codespace-architecture.md` for the canonical entity contract format.

Defines the base classes and naming conventions for Insightful services.
`@insightful/base` (CommonJS) provides Facelet, AppException, DomainEntity, and Foundation (for Java codeSpace).

## Full Stack Overview

```
@insightful/codeSpace/models/     ← Entity contracts (self-describing, field codes, Zod schema)
  └── ActionHistory.ts            ← Example: FIELD codes, ACTION constants, generateToken(), toJSON()

@insightful/codeSpace/contracts/  ← Service interfaces (optional — most stubs use inline typing)
  └── IActionHistoryService.ts    ← Typed method signatures

@insightful/base/                 ← Superclasses (CommonJS)
  ├── Foundation<T>               ← Generic CRUD base for Java codeSpace JSONB tables
  ├── Facelet                     ← Response envelope
  ├── AppException                ← Error hierarchy
  └── DomainEntity                ← Entity shape (id, userId, hash, data, timestamps)

Naming convention:
  ├── XxxStub                     ← Plain @Injectable() with direct Drizzle ORM (e.g. FitnessStub, AuthStub)
  ├── XxxFacelet                  ← Per-domain Facelet for the module
  └── XxxProcess                  ← NestJS Module tying stub + facelet together

Optional pattern:
  └── XxxService                  ← Facade composing multiple stubs (e.g. AuditService)
```

### Base Classes

```
Foundation<T extends DomainEntity>     ← Generic CRUD base for Java codeSpace JSONB tables
  ├── add(data, userId) → T
  ├── update(id, userId, data) → T | null
  ├── upsert(id, data, userId) → T
  ├── remove(id, userId) → void
  ├── list(userId, filters?, page?, limit?) → { data, total }
  ├── getById(id, userId) → T | null
  ├── link(parentId, childId, type?) → void
  ├── unlink(parentId, childId) → void
  └── transaction(callback) → TResult

XxxStub (naming convention)            ← Plain @Injectable() with direct Drizzle ORM
  ├── Plain @Injectable() class — does NOT extend Foundation
  ├── Direct Drizzle ORM queries against flat-column tables
  ├── All methods async, throw AppException subclasses on errors
  └── Registered in Process module providers

XxxFacelet                             ← Response envelope for every controller
  ├── ok(data) → ApiResponse
  ├── created(data) → ApiResponse
  ├── paginated(data, page, limit, total) → PaginatedResponse
  ├── error(code, message) → ErrorResponse
  ├── badRequest(message) → ErrorResponse
  ├── unauthorized(message) → ErrorResponse
  ├── forbidden(message) → ErrorResponse
  ├── notFound(message) → ErrorResponse
  └── conflict(message) → ErrorResponse

AppException                           ← Base error class (abstract)
  ├── ValidationException     → 400
  ├── AuthException           → 401
  ├── ForbiddenException      → 403
  ├── NotFoundException       → 404
  ├── ConflictException       → 409
  ├── RateLimitException      → 429
  ├── InternalException       → 500
  └── ServiceUnavailableException → 503

DomainEntity                           ← Shape of every persisted entity
  ├── id: string
  ├── userId: string
  ├── hash: string
  ├── data: Record<string, unknown>
  ├── createdAt: number
  └── updatedAt: number
```

## Foundation (Java codeSpace only)

`Foundation<T>` is a generic CRUD base for **JSONB DomainEntity tables** (`{ id, userId, hash, data, createdAt, updatedAt }`).
Used by the **Java codeSpace** Spring Boot layer (`EntityService.java`, `EntityController.java`).
Foundation writes to the `data` JSONB column — incompatible with life-os-v2 flat-column tables.

> **NestJS stubs no longer extend Foundation.** Life OS v2 stubs are plain `@Injectable()` classes with direct Drizzle ORM. See [Stub Format](#stub-format-nestjs-flat-tables) below.

### Foundation CRUD Methods (Java codeSpace)

| Method | Description |
|--------|-------------|
| `add(data, userId)` | Creates entity with UUID, hash, timestamps |
| `update(id, userId, data)` | Scoped to user, updates hash on change |
| `upsert(id, data, userId)` | Update-or-insert by id |
| `remove(id, userId)` | User-scoped delete |
| `list(userId, filters?, page?, limit?)` | Paginated list with optional filters |
| `getById(id, userId)` | Single entity lookup |
| `link(parentId, childId, type?)` | Creates entity_links record with hash snapshots |
| `unlink(parentId, childId)` | Removes link |
| `transaction(callback)` | Wraps in Drizzle transaction |

All write operations are user-scoped (`userId` filter on WHERE clauses).
List supports arbitrary key-value filters plus pagination (default limit: 40).

## Entity Contracts (codeSpace)

Every domain entity follows the **self-describing entity** pattern. The entity class IS the contract:
field codes, token generation, serialization, and validation are co-located.

```typescript
// @insightful/codeSpace/models/ActionHistory.ts
//
// Pattern: entity class with self-describing fields, action constants,
// token generation (hash@type@shard@timestamp), optional null-safe fields,
// and co-located Zod schema.

import { z } from 'zod';

export class ActionHistory
{
    static readonly TYPE = 'action_history';

    // Field codes (sequential, never reused)
    static readonly FIELD = {
        TOKEN:            { code: 1, name: 'token',          type: 'string' },
        EXECUTOR_TOKEN:   { code: 2, name: 'executorToken',  type: 'string' },
        TARGET_TOKEN:     { code: 3, name: 'targetToken',    type: 'string' },
        ACTION:           { code: 4, name: 'action',          type: 'string' },
        TIMESTAMP:        { code: 5, name: 'timestamp',       type: 'number' },
        MESSAGE:          { code: 6, name: 'message',         type: 'string' },
        REASON:           { code: 7, name: 'reason',          type: 'string' },
        IP:               { code: 8, name: 'ip',              type: 'string' },
        EXTRA:            { code: 9, name: 'extra',           type: 'string' },
    } as const;

    // Action constants
    static readonly ACTION = {
        ADD:             'add',
        EDIT:            'edit',
        DELETE:          'delete',
        PASSWORD_RESET:  'password_reset',
        LOGIN:           'login',
        LOGOUT:          'logout',
        API_CALL:        'api_call',
        SYNC:            'sync',
    } as const;

    // All fields optional — null values skip serialization
    token?: string;
    executorToken?: string;
    targetToken?: string;
    action?: string;
    timestamp?: number;
    message?: string;
    reason?: string;
    ip?: string;
    extra?: string;

    constructor(init?: Partial<ActionHistory>)
    {
        Object.assign(this, init);
    }

    // Token: hash@type@shard@timestamp
    generateToken(shard: string = '1'): string
    {
        const h = this.token || 'default';
        return `${h}@${ActionHistory.TYPE}@${shard}@${Date.now()}`;
    }

    // Validation schema co-located with entity
    static zodSchema = z.object({
        token: z.string().optional(),
        executorToken: z.string().optional(),
        targetToken: z.string().optional(),
        action: z.string().optional(),
        timestamp: z.number().optional(),
        message: z.string().optional(),
        reason: z.string().optional(),
        ip: z.string().optional(),
        extra: z.string().optional(),
    });
}
```

Service contracts are defined as TypeScript interfaces and live in `contracts/`:

```typescript
// @insightful/codeSpace/contracts/IActionHistoryService.ts
import type { ActionHistory } from '../models';

export interface IActionHistoryService
{
    log(entry: ActionHistory): Promise<ActionHistory>;
    list(filters?: Partial<ActionHistory>): Promise<ActionHistory[]>;
    getByToken(token: string): Promise<ActionHistory | null>;
}
```

Full reference: `dev/insightful-hub/ai-framework/ai-memory/codespace-architecture.md`

## Facelet

Every NestJS controller extends Facelet for standardized response formatting.

```typescript
import { Facelet } from '@insightful/base';

@Controller('fitness')
export class FitnessFacelet extends Facelet
{
    @Get()
    async list(@CurrentUser() user: User, @Query() query: PaginationDto)
    {
        const result = await this.service.list(user.id, query.filters, query.page, query.limit);
        return this.paginated(result.data, query.page, query.limit, result.total);
    }
}
```

### Response Envelope

Success:
```json
{
    "status": "ok",
    "data": { ... },
    "meta": {
        "correlationId": "uuid",
        "timestamp": "2026-07-09T..."
    }
}
```

Paginated:
```json
{
    "status": "ok",
    "data": [ ... ],
    "meta": {
        "page": 1,
        "limit": 40,
        "total": 156,
        "totalPages": 4,
        "correlationId": "uuid",
        "timestamp": "2026-07-09T..."
    }
}
```

Error:
```json
{
    "status": "error",
    "error": {
        "code": "NOT_FOUND",
        "message": "Resource not found"
    },
    "meta": {
        "correlationId": "uuid",
        "timestamp": "2026-07-09T..."
    }
}
```

## AppException Hierarchy

Every service throws typed exceptions. A NestJS exception filter (`AppExceptionFilter`)
catches them and formats the error envelope automatically.

| Exception | HTTP Status | Code |
|-----------|-------------|------|
| `ValidationException` | 400 | VALIDATION_ERROR |
| `AuthException` | 401 | AUTH_ERROR |
| `ForbiddenException` | 403 | FORBIDDEN |
| `NotFoundException` | 404 | NOT_FOUND |
| `ConflictException` | 409 | CONFLICT |
| `RateLimitException` | 429 | RATE_LIMITED |
| `InternalException` | 500 | INTERNAL_ERROR |
| `ServiceUnavailableException` | 503 | SERVICE_UNAVAILABLE |

```typescript
import { NotFoundException } from '@insightful/base';

if (!entity) throw new NotFoundException(`Fitness item ${id} not found`);
```

## Service Architecture Pattern

The full stack for a domain entity follows this pattern:

```
codeSpace (contract layer)    ← Entity class + optional service interface in @insightful/codeSpace
  │
  ├── Stub (per-domain)       ← Plain @Injectable(), direct Drizzle ORM, flat-column tables
  │
  ├── Facade (optional)       ← Convenience layer composing stubs (replaces static utility classes)
  │
  └── Facelet (controller)    ← Extends Facelet, handles HTTP mapping
        └── Process (module)  ← NestJS Module, wires everything together
```

- **codeSpace** — `@insightful/codeSpace/models/` defines self-describing entity classes with field codes, token generation, Zod schema. These are the canonical entity contracts shared across all services. See `codespace-architecture.md`.
- **Stub** — plain `@Injectable()` class with direct Drizzle ORM queries against flat-column tables. Does NOT extend Foundation. Each stub covers one domain (FitnessStub, NutritionStub, ScheduleStub, etc.). All methods throw AppException subclasses on errors.
- **Foundation** — (Java codeSpace only) generic CRUD base for JSONB DomainEntity tables. Not used by NestJS stubs.
- **Facade** — optional injectible service that composes one or more stubs into business operations. Replaces the legacy static-facade pattern (e.g., `LogInterface.logCustom()`) with testable, scoped services.
- **Facelet** — controller. Extends Facelet base, defines routes, calls Stub or Facade methods, returns formatted responses.
- **Process** — NestJS `@Module` that registers the Stub, Facade (if any), Facelet, and any DTOs/guards.


