# Alpha V2 — Phase 2A Financial Goal Planning

## 1. Overview
Phase 2A extends the robust financial ledger established in Phase 1 by introducing advanced goal planning capabilities. This phase focuses on data modeling, validation, and real-time calculation previews for creating and updating goals, ensuring the backend remains the authoritative source for all financial rules. 

Goal execution, cycle allocations, and emergency-fund routing remain deferred to future phases.

## 2. Completed Features
- **Goal Library Integration:** Replaced open-ended goal types with a strict taxonomy of 13 predefined categories (e.g., `emergency_fund`, `laptop`, `travel`, `custom`).
- **Custom Goal Support:** Added dynamic custom naming exclusively when the `custom` category is selected.
- **Planning Modes:**
  - `contribution_based`: Users define how much they can contribute per cycle, and the system estimates the required number of cycles.
  - `deadline_based`: Users define a strict deadline, and the system estimates the required contribution per cycle.
- **Real-Time Planning Preview Endpoint:** Exposes a stateless API calculating expected outcomes instantly as users type in the Flutter application.
- **Migration Engine:** Non-destructively maps all legacy `goal_type` strings into the new standardized library, seamlessly migrating existing data.
- **Strict Boundary Validation:** Ensures dates aren't in the past (or > 7 years out), priorities remain between 1-10, and target amounts never fall below the current ledger balance.
- **Flutter Form Overhaul:** A complete structural rewrite of `AddGoalScreen` integrating dynamic toggles, interactive date pickers, input debouncing, and direct API state mapping.

## 3. Database Schema Changes (Migration 011)
The `goals` table was expanded safely via `011_phase2_goal_planning.js`:
- `custom_name` (VARCHAR 150, NULL): Stores explicit user-defined names when `goal_type` is `custom`.
- `planned_contribution` (BIGINT UNSIGNED, DEFAULT 0): Records the designated contribution target when operating in `contribution_based` mode.
- Existing records were explicitly updated to map unrecognized `goal_type` entries into `custom`, moving their old names into `custom_name`.

## 4. API Endpoints

### Get Planning Preview (Stateless)
- **Route**: `POST /api/v1/goals/planning-preview`
- **Authentication requirement**: Bearer JWT
- **Request format**: 
  ```json
  { 
    "targetAmount": 1000, 
    "planningMode": "contribution_based",
    "plannedContribution": 250
  }
  ```
- **Response format**: 
  ```json
  {
    "isEstimated": true,
    "remainingAmount": 1000,
    "cyclesRequired": 4,
    "requiredContribution": null
  }
  ```

### Update Goal
- **Route**: `PUT /api/v1/goals/:id`
- **Authentication requirement**: Bearer JWT
- **Validation**:
  - Rejects if `targetAmount` < `currentBalance`.
  - Rejects if the goal `status` is `executed`.
  - Implicitly ignores `userId`, `status`, and ledger metadata in the payload to prevent privilege escalation.

## 5. Security & Isolation
- **Backend Authority:** The Flutter application performs absolutely zero local math for financial cycles. All calculations are performed deterministically by the Node.js backend.
- **Debounced Network Calls:** The Flutter client waits 500ms after the last keystroke before querying the preview endpoint, preventing rate-limit blocks and backend exhaustion.
- **Ownership Verification:** `updateGoal` explicitly verifies the requested goal belongs strictly to the authenticated `user_id`.

## 6. Testing Strategy
- **Backend (`goals.test.js`)**: Focuses on calculation boundaries, ensuring `deadline_based` algorithms correctly resolve date differentials and `contribution_based` ceil math operates flawlessly.
- **Flutter (`add_goal_screen_test.dart`)**: Uses `testWidgets` to ensure dynamic form segments (like Custom Name inputs or Date Pickers) render predictably when Radio toggles are shifted.

## 7. Deferred Work
- Goal execution & capital expenses
- True financial cycle tracking (all planning is currently marked `isEstimated: true`)
- Emergency fund routing

## 8. Rollout Commands
1. **Apply Migrations**: `node run_all_migrations.js` (or manually run `011_phase2_goal_planning.js`).
2. **Execute Tests**: `npm run test`
3. **Flutter Analyze**: `flutter analyze`
4. **Flutter Tests**: `flutter test`
