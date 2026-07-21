const { Router } = require('express');
const { FinanceController } = require('../controllers/finance.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../utils/async-handler');

const router = Router();

// ---------------------------------------------------------
// EXPENSES
// ---------------------------------------------------------
router.get('/expenses', authenticate, asyncHandler(FinanceController.getExpenses));
router.post('/expenses', authenticate, asyncHandler(FinanceController.createExpense));
router.delete('/expenses/:id', authenticate, asyncHandler(FinanceController.deleteExpense));
router.get('/expenses/categories', authenticate, asyncHandler(FinanceController.getExpenseCategories));

// ---------------------------------------------------------
// INCOMES
// ---------------------------------------------------------
router.get('/incomes', authenticate, asyncHandler(FinanceController.getIncomes));
router.post('/incomes', authenticate, asyncHandler(FinanceController.createIncome));
router.delete('/incomes/:id', authenticate, asyncHandler(FinanceController.deleteIncome));

// ---------------------------------------------------------
// GOALS
// ---------------------------------------------------------
router.get('/goals', authenticate, asyncHandler(FinanceController.getGoals));
router.get('/goals/ready', authenticate, asyncHandler(FinanceController.getReadyGoals));
router.post('/goals/:id/execute', authenticate, asyncHandler(FinanceController.executeGoal));
router.post('/goals/:id/defer', authenticate, asyncHandler(FinanceController.deferGoal));
router.post('/goals/:id/reallocate', authenticate, asyncHandler(FinanceController.reallocateGoal));
router.get('/goals/savings-allocation-preview', authenticate, asyncHandler(FinanceController.savingsAllocationPreview));
router.post('/goals/savings-allocation-approve', authenticate, asyncHandler(FinanceController.approveSavingsAllocation));

// Canonical Phase 2C savings allocation routes
router.post('/savings/allocation-preview', authenticate, asyncHandler(FinanceController.savingsAllocationPreview));
router.get('/savings/allocation', authenticate, asyncHandler(FinanceController.getSavingsAllocation));
router.put('/savings/allocation', authenticate, asyncHandler(FinanceController.approveSavingsAllocation));

router.post('/goals/planning-preview', authenticate, asyncHandler(FinanceController.planningPreview));
router.get('/goals/:id/transactions', authenticate, asyncHandler(FinanceController.getGoalTransactions));
router.post('/goals', authenticate, asyncHandler(FinanceController.createGoal));
router.put('/goals/:id', authenticate, asyncHandler(FinanceController.updateGoal));
router.post('/goals/:id/contributions', authenticate, asyncHandler(FinanceController.addGoalContribution));
router.post('/goals/:id/pause', authenticate, asyncHandler(FinanceController.pauseGoal));
router.post('/goals/:id/resume', authenticate, asyncHandler(FinanceController.resumeGoal));
router.delete('/goals/:id', authenticate, asyncHandler(FinanceController.deleteGoal));

// ---------------------------------------------------------
// COMMITMENTS
// ---------------------------------------------------------
router.get('/commitments', authenticate, asyncHandler(FinanceController.getCommitments));
router.post('/commitments', authenticate, asyncHandler(FinanceController.createCommitment));
router.patch('/commitments/:id', authenticate, asyncHandler(FinanceController.updateCommitment));
router.delete('/commitments/:id', authenticate, asyncHandler(FinanceController.deleteCommitment));

// ---------------------------------------------------------
// FINANCIAL PROFILE
// ---------------------------------------------------------
router.get('/financial-profile/allocation', authenticate, asyncHandler(FinanceController.getAllocation));
router.patch('/financial-profile', authenticate, asyncHandler(FinanceController.updateFinancialProfile));
router.post('/financial-profile/allocation-preview', authenticate, asyncHandler(FinanceController.financialProfileAllocationPreview));
router.put('/financial-profile/allocation', authenticate, asyncHandler(FinanceController.approveFinancialProfileAllocation));

module.exports = router;
