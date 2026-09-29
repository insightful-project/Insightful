# Operations Standards

Production readiness checklist for every deployable service.
A service cannot merge to `live` without passing every check in this document.

## Checklist

Every service must pass all checks before merging to `live`.

### Healthchecks

- [ ] Service exposes `GET /health` returning `{ "status": "ok" }`
- [ ] Healthcheck is used in Docker Compose `healthcheck:` block
- [ ] Healthcheck confirms the service can serve requests (not just "process is running")
- [ ] Downstream dependencies are checked if they're critical (e.g., DB connection)

Implementation:

```typescript
// NestJS — HealthController
@Controller()
export class HealthController {
    @Get('health')
    async check() {
        // Optionally check DB connection
        // await this.db.$queryRaw`SELECT 1`;
        return { status: 'ok', timestamp: new Date().toISOString() };
    }
}
```

```java
// Java — HealthController
@RestController
public class HealthController {
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> check() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "timestamp", Instant.now().toString()
        ));
    }
}
```

### Graceful Shutdown

- [ ] Service handles SIGTERM and SIGINT
- [ ] Drains active connections before exiting
- [ ] Stop grace period >= 30 seconds
- [ ] Logs a clear message at shutdown start and completion

```typescript
// NestJS — automatic with enableShutdownHooks
async function bootstrap() {
    const app = await NestFactory.create(AppModule);
    app.enableShutdownHooks();
    await app.listen(4001);
}
```

```java
// Java — Spring Boot automatic
// Just ensure spring.lifecycle.timeout-per-shutdown-phase=30s
```

### Structured Logging

- [ ] All logs are JSON format (not plain text)
- [ ] Every log entry includes: level, message, service name, timestamp
- [ ] Every request has a `correlationId` forwarded through all services
- [ ] Errors include stack trace and correlationId
- [ ] No sensitive data (passwords, tokens, PII) in logs

```typescript
// NestJS — Pino logger
import { LoggerModule } from 'nestjs-pino';

LoggerModule.forRoot({
    pinoHttp: {
        transport: process.env.NODE_ENV !== 'production'
            ? { target: 'pino-pretty' }
            : undefined,
        customProps: (req) => ({
            correlationId: req.headers['x-correlation-id'],
        }),
    },
});
```

```json
// Log format example
{
    "level": "error",
    "message": "Failed to process transaction",
    "service": "FinanceService",
    "correlationId": "abc-123-def-456",
    "operation": "createTransaction",
    "stack": "ValidationException: ...",
    "timestamp": "2026-06-25T12:00:00.000Z"
}
```

### Docker Best Practices

- [ ] Multi-stage build (build stage + runtime stage)
- [ ] Slim base image (`-slim` or `-alpine`)
- [ ] No root user in container (use `USER` directive)
- [ ] `.dockerignore` excludes `node_modules`, `.env`, `dist/`, `.git/`
- [ ] Image is scanned for vulnerabilities before deploy

```dockerfile
# NestJS — multi-stage example
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./
USER node
EXPOSE 4001
CMD ["node", "dist/main"]
```

```dockerfile
# Java (Maven) — multi-stage example
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY pom.xml ./
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests -B

FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
USER 1000:1000
EXPOSE 7500
CMD ["java", "-jar", "app.jar"]
```

### Docker Compose Best Practices

- [ ] Healthcheck on every service
- [ ] `restart: unless-stopped` on every service
- [ ] Bind to `127.0.0.1` (loopback) unless intentionally public
- [ ] Resource limits set (CPU + memory)
- [ ] Secrets via env_file or Docker secrets, not hardcoded
- [ ] Logging driver configured (json-file or loki)

```yaml
# docker-compose.yml — production pattern
version: '3.8'

services:
  api:
    build: .
    ports:
      - "127.0.0.1:4001:4001"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:4001/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    stop_grace_period: 30s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    env_file:
      - .env.production
```

### Rate Limiting

- [ ] Rate limiting on auth endpoints (/login, /register, /refresh)
- [ ] General rate limiting on all API endpoints
- [ ] Different limits for authenticated vs unauthenticated users

```typescript
// NestJS — throttler
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

@Module({
    imports: [
        ThrottlerModule.forRoot([
            { name: 'short', ttl: 1000, limit: 10 },   // 10 req/s
            { name: 'medium', ttl: 60000, limit: 100 }, // 100 req/min
        ]),
    ],
    providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
```

```java
// Java — Spring Boot + bucket4j
// Add spring-boot-starter-web + bucket4j dependency
// Configure rate limit filter
```

### CORS

- [ ] CORS restricted to known origins (not `*` or `true` in production)
- [ ] Dev mode can be permissive, but production mode is locked

```typescript
// NestJS
app.enableCors({
    origin: process.env.NODE_ENV === 'production'
        ? ['http://app.insightful.local']
        : ['http://localhost:3000', 'http://localhost:5173'],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    credentials: true,
});
```

### Input Validation

- [x] Every endpoint validates its inputs (Zod via ZodValidationPipe)
- [x] Validation errors return consistent error format
- [x] No raw `req.body` without schema validation

```typescript
// NestJS — Zod DTO validation (active in codebase)
import { z } from 'zod';

export const CreateTransactionSchema = z.object({
    name: z.string().min(1, 'Name required'),
    amount: z.number(),
    notes: z.string().optional(),
});

export type CreateTransactionInput = z.infer<typeof CreateTransactionSchema>;
```

### Monitoring & Observability

- [x] Correlation ID middleware — every request gets UUID, injected into Pino context + response header
- [x] Log aggregation — Pino → pino-loki → Loki (optional via `LOKI_URL`)
- [x] Error tracking — Sentry (optional via `SENTRY_DSN`)
- [x] Structured JSON logging — Pino with redacted sensitive fields
- [ ] Metrics endpoint (`/metrics` in Prometheus format)
- [ ] Request duration histogram
- [ ] Error rate by endpoint
- [ ] Healthcheck dependency status

## Environment-Specific Config

| Config | dev | test | live |
|--------|-----|------|------|
| .env file | `compose/.env` | `.env.test` | `.env.production` |
| DB host | localhost | test-postgres | prod-postgres |
| CORS origins | localhost:3000, :5173 | test.insightful.local | app.insightful.local |
| Log level | debug | info | warn |
| Rate limit | relaxed | moderate | strict |

## Agent Instruction

When deploying a service to live:
1. Walk through every checkbox in this document
2. Verify healthcheck endpoint exists and returns 200
3. Verify Dockerfile has multi-stage build + slim base
4. Verify compose file has healthcheck + restart + resource limits
5. Verify structured logging is JSON with correlation IDs
6. Verify rate limiting is in place
7. Verify CORS is locked down
8. If any check fails, fix it before the deploy PR merges

## Next Steps

- [x] Add healthcheck endpoint to every service (2026-07-13: all 11 compose files / 17 services hardened)
- [x] Graceful shutdown — NestJS `enableShutdownHooks()` active in main.ts
- [x] Configure structured JSON logging (Pino for NestJS) (done)
- [x] Add correlation ID middleware to all services (CorrelationIdMiddleware — active)
- [x] Sentry error tracking (optional via SENTRY_DSN — initialized in main.ts)
- [x] Loki log aggregation (optional via LOKI_URL — pino-loki transport in app.module.ts)
- [x] Redis cache + rate limit store (compose/redis.yml, RedisThrottlerStorage)
- [x] Bull async job queue (queues/ — ntfy push + n8n webhook dispatch)
- [x] Row-Level Security (RlsInterceptor — Drizzle tx + SET LOCAL on all user-owned tables)
- [x] Audit all Dockerfiles for multi-stage + slim base + USER directive (2026-07-13: NestJS ✅ USER node, codeSpace ✅ USER appuser, nginx ✅ master-root-native-drop)
- [x] Audit all docker-compose files for healthchecks + restart + resource limits (2026-07-13: all 11 compose files verified/hardened)
- [x] Add rate limiting to all API services (done — @nestjs/throttler)
- [x] Audit CORS configuration across all services (2026-07-13: codeSpace WebConfig.java fixed from wildcard to env-var driven, NestJS locked to dev origins)
- [x] Add input validation DTOs to every endpoint (done — ZodValidationPipe)
- [ ] Create `.env.production.example` for every project
