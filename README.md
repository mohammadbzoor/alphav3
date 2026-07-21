# alphav2

## Financial Goals — Phase 1
Phase 1 establishes the traceable and concurrency-safe foundation for financial goals, including a permanent ledger and strict row-level locking.

- **Documentation**: [docs/PHASE_1_FINANCIAL_GOALS.md](backend/docs/PHASE_1_FINANCIAL_GOALS.md)
- **Run Migrations**: `node src/database/migrations/run_009.js` (and 010)
- **Run Tests**: `npm run test` (backend)

> **WARNING**: Integration tests require an isolated database (`alpha_test`). Do not run integration tests against the main `alpha` database.

**Status**: 
- Phase 1 (Ledger, Atomic Contributions, Lifecycle Controls): **Complete**
- Phase 2A (Goal Library, Planning Modes, Live Preview API): **Complete**
- Phase 2B (Execution, Capital Expenses, Reallocation, Financial Cycles): **Deferred**

- **Documentation**: [docs/PHASE_2A_GOAL_PLANNING.md](backend/docs/PHASE_2A_GOAL_PLANNING.md)
