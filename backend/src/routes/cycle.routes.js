'use strict';

const { Router }          = require('express');
const { CycleController } = require('../controllers/cycle.controller');
const { CyclePlanningController } = require('../controllers/cycle-planning.controller');
const { SettlementController } = require('../controllers/settlement.controller');
const { authenticate }    = require('../middleware/auth.middleware');
const { asyncHandler }    = require('../utils/async-handler');

const router = Router();

// POST /api/v1/financial-cycles
router.post(
  '/',
  authenticate,
  asyncHandler(CycleController.createCycle)
);

// GET /api/v1/financial-cycles/current
// Must be declared BEFORE /:id so Express does not treat "current" as an id.
router.get(
  '/current',
  authenticate,
  asyncHandler(CycleController.getCurrentCycle)
);

// GET /api/v1/financial-cycles/:id
router.get(
  '/:id',
  authenticate,
  asyncHandler(CycleController.getCycleById)
);

// ───────────────────────────────────────────────────────────────────── //
// CYCLE PLANNING (Phase 3A.3)
// ───────────────────────────────────────────────────────────────────── //
router.post(
  '/:cycleId/goal-allocations',
  authenticate,
  asyncHandler(CyclePlanningController.planGoalAllocations)
);

router.post(
  '/:cycleId/savings-allocation',
  authenticate,
  asyncHandler(CyclePlanningController.linkSavingsAllocation)
);

router.get(
  '/:cycleId/planning-summary',
  authenticate,
  asyncHandler(CyclePlanningController.getCyclePlanningSummary)
);

// ───────────────────────────────────────────────────────────────────── //
// SETTLEMENT (Phase 3B)
// ───────────────────────────────────────────────────────────────────── //
// POST /api/v1/financial-cycles/current/settlement-preview
router.post(
  '/current/settlement-preview',
  authenticate,
  asyncHandler(SettlementController.previewSettlement)
);

// POST /api/v1/financial-cycles/current/settlement
router.post(
  '/current/settlement',
  authenticate,
  asyncHandler(SettlementController.beginSettlement)
);

// POST /api/v1/financial-cycles/current/close
router.post(
  '/current/close',
  authenticate,
  asyncHandler(SettlementController.closeCycle)
);

module.exports = router;
