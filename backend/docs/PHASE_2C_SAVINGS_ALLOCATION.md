# Phase 2C: Savings Allocation

## Overview
Phase 2C introduces the ability to plan and preview savings allocations across active goals. This enables users to distribute their savings while enforcing an automatic 10% emergency fund reserve and ensuring allocations do not exceed the total available savings.

## Invariants Maintained
* **Core Formula**: `emergencyFundAmount + totalGoalAllocations + unallocatedSavings = savingsAmount`
* **Planning Only**: Allocations are strictly planning figures (`planned_contribution` in `goals` table). Goal balances (`current_balance`) are not updated.
* **No Side Effects**: No ledger entries (`goal_transactions`) or confirmed transactions are created.
* **Validation**: Allocations that exceed the available savings amount are rejected.

## Features Implemented
### Backend
- **Endpoint**: `GET /api/v1/goals/savings-allocation-preview?savingsAmount=`
  - Dynamically calculates the emergency fund (10% of `savingsAmount`).
  - Fetches all active goals and sums their `planned_contribution` as `totalGoalAllocations`.
  - Calculates `unallocatedSavings`.
- **Endpoint**: `POST /api/v1/goals/savings-allocation-approve`
  - Validates `emergencyFundAmount + sum(allocationAmount) + unallocated = savingsAmount`.
  - Rejects if `sum(allocationAmount) > savingsAmount - emergencyFundAmount`.
  - Updates `planned_contribution` for the specified goals.
- **Testing**: Added `savings_allocation.test.js` covering valid calculations, successful approvals, and over-allocation rejections.

### Flutter
- **Screen**: `SavingsAllocationScreen` (`lib/screens/goals/savings_allocation_screen.dart`)
  - Input for `Total Savings Amount` and "Preview" button.
  - Read-only display of the locked 10% Emergency Fund.
  - Dynamically generated list of TextFields to adjust each active goal's allocation.
  - Auto-summing `Unallocated Savings` gap indicator (turns red if negative).
  - "Approve Allocations" button (disabled if there is a gap/over-allocation).
- **Service**: Updated `FinanceService` (`lib/services/finance_service.dart`) with `savingsAllocationPreview` and `approveSavingsAllocation`.
- **Testing**: Added `savings_allocation_screen_test.dart` to verify the UI loads and renders correctly.

## Verification
- Backend tests passed: `npm test src/tests/savings_allocation.test.js` (3/3 passed).
- Flutter analyze passed.
- Flutter tests passed: `flutter test test/savings_allocation_screen_test.dart`.
- Alpha row counts and data integrity confirmed to be unchanged by tests (run exclusively on `alpha_test`).

## Migration
- No new migration needed. We reused the `planned_contribution` column introduced in Phase 2's migration (`011_phase2_goal_planning.js`).
