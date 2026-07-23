const { FinanceService } = require('../services/finance.service');

class FinanceController {
  // ---------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------
  static async getExpenses(req, res) {
    const result = await FinanceService.getExpenses(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Expenses retrieved successfully',
      data: result.items,
      total: result.total,
      meta: null
    });
  }

  static async createExpense(req, res) {
    const result = await FinanceService.createExpense(req.user.id, req.body);
    res.status(201).json({
      success: true,
      message: 'Expense created successfully',
      data: result,
      meta: null
    });
  }

  static async deleteExpense(req, res) {
    await FinanceService.deleteExpense(req.user.id, req.params.id);
    res.status(200).json({
      success: true,
      message: 'Expense deleted successfully',
      data: null,
      meta: null
    });
  }

  static async getExpenseCategories(req, res) {
    const result = await FinanceService.getExpenseCategories();
    res.status(200).json({
      success: true,
      message: 'Expense categories retrieved',
      data: result.items,
      total: result.total,
      meta: null
    });
  }

  // ---------------------------------------------------------
  // INCOMES
  // ---------------------------------------------------------
  static async getIncomes(req, res) {
    const result = await FinanceService.getIncomes(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Incomes retrieved successfully',
      data: result.items,
      total: result.total,
      meta: null
    });
  }

  static async createIncome(req, res) {
    const result = await FinanceService.createIncome(req.user.id, req.body);
    res.status(201).json({
      success: true,
      message: 'Income created successfully',
      data: result,
      meta: null
    });
  }

  static async deleteIncome(req, res) {
    await FinanceService.deleteIncome(req.user.id, req.params.id);
    res.status(200).json({
      success: true,
      message: 'Income deleted successfully',
      data: null,
      meta: null
    });
  }

  // ---------------------------------------------------------
  // GOALS
  // ---------------------------------------------------------
  static async getGoals(req, res) {
    const result = await FinanceService.getGoals(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Goals retrieved successfully',
      data: result.items,
      total: result.total,
      meta: null
    });
  }

  static async createGoal(req, res) {
    const result = await FinanceService.createGoal(req.user.id, req.body);
    res.status(201).json(result);
  }

  static async updateGoal(req, res) {
    const { id } = req.params;
    const result = await FinanceService.updateGoal(req.user.id, id, req.body);
    res.json(result);
  }

  static async planningPreview(req, res) {
    const result = FinanceService.planningPreview(req.body);
    res.json(result);
  }

  static async savingsAllocationPreview(req, res) {
    const savingsAmount = parseFloat(req.body.savingsAmount || req.query.savingsAmount || 0);
    const emergencyFundRate = req.body.emergencyFundRate !== undefined
      ? parseFloat(req.body.emergencyFundRate)
      : (req.query.emergencyFundRate !== undefined ? parseFloat(req.query.emergencyFundRate) : 10.0);
    const goalAllocations = req.body.goalAllocations || [];
    const result = await FinanceService.savingsAllocationPreview(req.user.id, savingsAmount, emergencyFundRate, goalAllocations);
    res.json({ success: true, data: result });
  }

  static async getSavingsAllocation(req, res) {
    const result = await FinanceService.getSavingsAllocation(req.user.id);
    res.json({ success: true, data: result });
  }

  static async approveSavingsAllocation(req, res) {
    const result = await FinanceService.approveSavingsAllocation(req.user.id, req.body);
    res.json(result);
  }

  static async getReadyGoals(req, res) {
    const goals = await FinanceService.getReadyGoals(req.user.id);
    res.json({ success: true, data: goals });
  }

  static async getGoalTransactions(req, res) {
    const { id } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    const transactions = await FinanceService.getGoalTransactions(req.user.id, id, limit, offset);
    res.json({ success: true, data: transactions });
  }

  static async addGoalContribution(req, res) {
    const { id } = req.params;
    const idempotencyKey = req.headers['idempotency-key'] || req.body.idempotencyKey;

    const result = await FinanceService.addGoalContribution(req.user.id, id, {
      amount: req.body.amount,
      idempotencyKey,
      description: req.body.description
    });

    res.status(200).json(result);
  }

  static async pauseGoal(req, res) {
    const { id } = req.params;
    const result = await FinanceService.changeGoalStatus(req.user.id, id, 'paused');
    res.json(result);
  }

  static async resumeGoal(req, res) {
    const { id } = req.params;
    const result = await FinanceService.changeGoalStatus(req.user.id, id, 'active');
    res.json(result);
  }

  static async deleteGoal(req, res) {
    await FinanceService.deleteGoal(req.user.id, req.params.id);
    res.status(200).json({
      success: true,
      message: 'Goal deleted successfully',
      data: null,
      meta: null
    });
  }

  static async executeGoal(req, res) {
    const result = await FinanceService.executeGoal(req.user.id, req.params.id, req.body.idempotencyKey);
    res.status(200).json(result);
  }

  static async deferGoal(req, res) {
    const result = await FinanceService.deferGoal(req.user.id, req.params.id);
    res.status(200).json(result);
  }

  static async reallocateGoal(req, res) {
    const result = await FinanceService.reallocateGoal(
      req.user.id,
      req.params.id,
      req.body.destinationGoalId,
      req.body.amount,
      req.body.idempotencyKey
    );
    res.status(200).json(result);
  }

  // ---------------------------------------------------------
  // COMMITMENTS
  // ---------------------------------------------------------
  static async getCommitments(req, res) {
    const result = await FinanceService.getCommitments(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Commitments retrieved successfully',
      data: result.items,
      total: result.total,
      meta: null
    });
  }

  static async createCommitment(req, res) {
    const result = await FinanceService.createCommitment(req.user.id, req.body);
    res.status(201).json({
      success: true,
      message: 'Commitment created successfully',
      data: result,
      meta: null
    });
  }

  static async updateCommitment(req, res) {
    const result = await FinanceService.updateCommitment(req.user.id, req.params.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Commitment updated successfully',
      data: result,
      meta: null
    });
  }

  static async deleteCommitment(req, res) {
    await FinanceService.deleteCommitment(req.user.id, req.params.id);
    res.status(200).json({
      success: true,
      message: 'Commitment deleted successfully',
      data: null,
      meta: null
    });
  }

  static async getAllocation(req, res) {
    const result = await FinanceService.getAllocation(req.user.id);
    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'Allocation profile not found',
        data: null,
        meta: null
      });
    }

    res.status(200).json({
      success: true,
      message: 'Allocation retrieved successfully',
      data: result,
      meta: null
    });
  }

  static async getFinancialProfile(req, res) {
    const result = await FinanceService.getFinancialProfile(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Financial profile retrieved successfully',
      data: result,
      meta: null
    });
  }

  static async updateFinancialProfile(req, res) {
    const result = await FinanceService.updateFinancialProfile(req.user.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Financial profile updated successfully',
      data: result,
      meta: null
    });
  }

  static async financialProfileAllocationPreview(req, res) {
    const result = await FinanceService.financialProfileAllocationPreview(req.user.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Allocation preview generated successfully',
      data: result,
      meta: null
    });
  }

  static async approveFinancialProfileAllocation(req, res) {
    const result = await FinanceService.approveFinancialProfileAllocation(req.user.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Allocation approved successfully',
      data: result,
      meta: null
    });
  }
}

module.exports = { FinanceController };
