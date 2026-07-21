# Alpha V2 — Phase 1 Financial Goals Architecture

## 1. Overview
Phase 1 establishes the traceable and concurrency-safe foundation for financial goals. It introduces a permanent financial ledger for tracking goal contributions and implements row-level locking to prevent concurrency exploits during balance mutations.

Phase 1 intentionally defers goal execution (transferring funds), reallocation of completed goals, emergency-fund allocation, and financial-cycle integrations to Phase 2.

## 2. Completed Features
- **Goal transaction ledger**: A robust, immutable ledger recording all financial movements.
- **Traceable contributions**: All API contributions strictly log ledger rows containing user boundaries and timestamp audits.
- **Opening-balance adjustments**: Deterministic migration rules ensuring all legacy balances are mathematically correct and reconciled.
- **Atomic contribution workflow**: Ledger inserts and balance aggregations mutate inside one monolithic transaction.
- **Row-level locking**: Leverages InnoDB `SELECT ... FOR UPDATE` ensuring serialized writes during concurrent requests.
- **Idempotency**: Implements user-scoped unique requests safeguarding duplicate networking.
- **Request-hash conflict detection**: Verifies duplicate idempotency keys to distinguish legitimate replays from malicious concurrent payloads.
- **Over-contribution rejection**: Real-time evaluation preventing a target from exceeding 100% capacity.
- **Goal lifecycle controls**: Enforces strict transitions (e.g., active goals cannot receive contributions if paused or draft).
- **Automatic ready transition**: Reaching 100% implicitly triggers the `ready` status.
- **Pause and resume behavior**: Explicit lifecycle manipulation.
- **Ready-goals query**: Specialized extraction of completely funded goals awaiting execution.
- **Paginated ledger history**: Read-only extraction of the transaction stream.
- **Ownership authorization**: Complete 404/403 cryptographic boundary across all endpoints.
- **Goal deletion protection**: Rejects hard deletion of goals with existing financial histories.
- **Balance reconciliation**: Internal service capable of reconstructing balances directly from transaction records.
- **Foreign-key enforcement**: Restrictive `ON DELETE RESTRICT` schemas blocking implicit ledger erasure.
- **Migration safety**: Safe, rerunnable introspection parsing `information_schema`.
- **Automated testing**: Broad vitest suite running directly on real MySQL servers.

## 3. Goal Lifecycle
The supported state model implements strict deterministic paths:
- `draft` -> `active`
- `active` -> `paused`
- `paused` -> `active`
- `active` -> `ready`

The following statuses exist but their execution behavior is deferred to Phase 2:
- `executed`
- `cancelled`

**Important**: Reaching `ready` does **not** execute the goal automatically. It simply indicates that the funding target has been achieved.

## 4. Ledger Model
The `goal_transactions` table enforces an immutable accounting model.
- Each contribution creates a precise ledger entry.
- `current_balance` on the `goals` table remains as a highly efficient cached aggregate.
- Ledger entries and the cached balance are always updated atomically together.
- Opening balances use deterministic `adjustment` entries to reconcile legacy structures.
- Financial ledger history must not be cascade-deleted. Hard deletions are forbidden.

**Transaction Types**:
- `contribution` (Exposed via public API)
- `adjustment` (Internal/Migration only)
- `reallocation_in` (Deferred to Phase 2)
- `reallocation_out` (Deferred to Phase 2)
- `execution` (Deferred to Phase 2)
- `reversal` (Deferred to Phase 2)

## 5. Atomic Contribution Workflow
The actual underlying execution sequence operates exactly as follows:
```
BEGIN
-> idempotency lookup (read phase)
-> SELECT goal FOR UPDATE
-> ownership verification
-> lifecycle validation
-> remaining-amount calculation
-> over-contribution validation
-> ledger insertion
-> balance update
-> optional ready transition
-> COMMIT
```
Any failure during these steps (or network disconnect) causes a complete `ROLLBACK`, guaranteeing zero side effects.

## 6. Idempotency
- **Idempotency-Key usage**: Clients must supply a unique string for mutative endpoints.
- **User-scoped uniqueness**: The primary guard is a database composite constraint `(user_id, idempotency_key)`.
- **Deterministic request hash**: We compute a server-side hash of the operation, user, goal, amount, and description.
- **Identical replay behavior**: Bypasses `REPEATABLE READ` illusions via `FOR SHARE` lookups on `ER_DUP_ENTRY` errors, ensuring clients can safely recover timeouts.
- **Conflicting replay behavior**: A different hash with a reused key instantly throws a `409` conflict.
- **Concurrent duplicate-request behavior**: Automatically detected and gracefully rejected by MySQL's native unique index block.

## 7. API Endpoints

### Add Contribution
- **Route**: `POST /api/v1/goals/:id/contributions`
- **Authentication requirement**: Bearer JWT
- **Headers**:
  - `Idempotency-Key`: Required string
- **Request format**: 
  ```json
  { "amount": 100.50, "description": "Weekly save" }
  ```
- **Response format**: Goal entity reflecting the newly aggregated `current_balance`.
- **Possible error codes**: `GOAL_NOT_FOUND`, `GOAL_NOT_ACTIVE`, `GOAL_CONTRIBUTION_EXCEEDS_REMAINING`, `IDEMPOTENCY_KEY_REUSED`
- **Ownership behavior**: Returns `404` if the goal does not belong to the user.

### Get Ready Goals
- **Route**: `GET /api/v1/goals/ready`
- **Authentication requirement**: Bearer JWT
- **Response format**: Array of fully funded goals.

### Get Goal Ledger History
- **Route**: `GET /api/v1/goals/:id/transactions`
- **Authentication requirement**: Bearer JWT
- **Response format**: Paginated array of transactions (supports `?limit=` & `?offset=`).

### Pause Goal
- **Route**: `POST /api/v1/goals/:id/pause`
- **Authentication requirement**: Bearer JWT
- **Response format**: Updated Goal entity (`status: "paused"`).
- **Validation**: Fails if goal is not `active`.

### Resume Goal
- **Route**: `POST /api/v1/goals/:id/resume`
- **Authentication requirement**: Bearer JWT
- **Response format**: Updated Goal entity (`status: "active"`).
- **Validation**: Fails if goal is not `paused`.

## 8. Error Codes
- `GOAL_NOT_FOUND`: Target entity does not exist or violates ownership.
- `GOAL_NOT_ACTIVE`: Cannot manipulate lifecycle (requires active status).
- `GOAL_CONTRIBUTION_EXCEEDS_REMAINING`: Prevent exceeding the 100% funding target.
- `IDEMPOTENCY_KEY_REUSED`: Hash collision with a differing payload.
- `GOAL_HAS_LEDGER_HISTORY`: Prevents deleting historical audits.
- `INVALID_GOAL_STATE`: Illegal lifecycle transition (e.g. paused to paused).

## 9. Database Integrity
The structural baseline mandates InnoDB engines exclusively.
- **Foreign keys**: Formalize relationship mapping between `users`, `goals`, and `goal_transactions`.
- **ON DELETE RESTRICT**: Cascade deletion on financial history is explicitly prohibited at the schema level.
- **Safe migration reruns**: All migrations parse `information_schema` directly to prevent duplicate executions.
- **Required REFERENCES privilege**: The deployment architecture strictly mandates the execution of `GRANT REFERENCES ON alpha.* TO '<application-user>'@'<application-host>';` (Identify via `SELECT CURRENT_USER(), USER();`).

## 10. Test Isolation
Integration tests are highly volatile and mutate massive amounts of ledger data. 
- **`alpha_test` requirement**: An isolated DB specifically designated for automated tests.
- **Database safety guard**: Internal connection startup hard-aborts if `NODE_ENV=test` and `DB_NAME` fails to match an explicitly permitted `*_test` suffix.
- **Warning**: Never run the integration test suite against the alpha development or production database.
- See `.env.test.example` for secure scaffolding configurations.

## 11. Testing
The Vitest integration suite explicitly validates the following conditions against the live testing cluster:
- Contribution success & Ledger insertion
- Atomic balance update & Transaction rollback
- Ready transition
- Idempotent replay & Idempotency conflict
- Over-contribution rejection
- Ownership isolation & Lifecycle rejection
- Concurrent contributions (Lock & Key verification)
- Opening-adjustment migration & Migration rerun
- Ready-route ordering & Reconciliations

**Results**: 
- `12` Goals tests successfully executed.
- `4` Migration tests successfully executed.
- Overall code-coverage successfully established (e.g., 100% across critical integration test vectors).

## 12. Deferred Phase 2 Work
- Goal library UI
- Custom-goal field
- Goal planning by contribution
- Goal planning by deadline
- Goal execution
- Capital-expense creation
- Execution deferral
- Goal reallocation
- Emergency fund
- Savings allocation
- Financial cycles
- Dashboard
- Notifications

## 13. Operational Notes
**Required Migrations**:
`009_phase1_goal_ledger.js`
`010_post_deployment_goal_ledger_fks.js`

**Required Test Database**: `alpha_test`

**Commands**:
- Run migrations: `node run_migrations.js` (pseudo-command wrapper)
- Run tests: `npm run test`
- Run coverage: `npm run test -- --coverage`
- Start application: `npm run dev`

## 14. Phase 1 Status
- Goal Ledger: **Complete**
- Atomic Contributions: **Complete**
- Row-Level Locking: **Complete**
- Idempotency: **Complete**
- Lifecycle Controls: **Complete**
- Ownership Authorization: **Complete**
- Opening Adjustments: **Complete**
- Database Foreign Keys: **Complete**
- Migration Safety: **Complete**
- Test Isolation: **Complete**
- Automated Tests: **Complete**

---

# API Examples (Phase 1)

### 1. Add Contribution
```bash
curl -X POST <BASE_URL>/api/v1/goals/<GOAL_ID>/contributions \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Idempotency-Key: <UNIQUE_IDEMPOTENCY_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50, "description": "Weekly transfer"}'
```

### 2. Replay Identical Idempotent Request
```bash
# Repeat the exact same curl above. 
# Response returns success with the previously committed ledger entry (no duplication).
```

### 3. Conflicting Reuse of Idempotency Key
```bash
curl -X POST <BASE_URL>/api/v1/goals/<GOAL_ID>/contributions \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Idempotency-Key: <UNIQUE_IDEMPOTENCY_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "description": "Different payload"}'
# Returns 409 Conflict: IDEMPOTENCY_KEY_REUSED
```

### 4. Get Ready Goals
```bash
curl -X GET <BASE_URL>/api/v1/goals/ready \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 5. Get Goal Ledger History
```bash
curl -X GET "<BASE_URL>/api/v1/goals/<GOAL_ID>/transactions?limit=10&offset=0" \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 6. Pause Goal
```bash
curl -X POST <BASE_URL>/api/v1/goals/<GOAL_ID>/pause \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 7. Resume Goal
```bash
curl -X POST <BASE_URL>/api/v1/goals/<GOAL_ID>/resume \
  -H "Authorization: Bearer <JWT_TOKEN>"
```
