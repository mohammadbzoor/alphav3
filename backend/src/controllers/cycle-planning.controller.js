const { CyclePlanningService } = require('../services/cycle-planning.service');

class CyclePlanningController {
  static async planGoalAllocations(req, res) {
    const { cycleId } = req.params;
    const { goalAllocations } = req.body;
    const result = await CyclePlanningService.planGoalAllocations(req.user.id, cycleId, goalAllocations);
    res.status(201).json({
      success: true,
      message: 'Goal allocations planned successfully',
      data: result,
      meta: null
    });
  }

  static async linkSavingsAllocation(req, res) {
    const { cycleId } = req.params;
    const result = await CyclePlanningService.linkSavingsAllocation(req.user.id, cycleId, req.body);
    res.status(201).json({
      success: true,
      message: 'Savings allocation linked successfully',
      data: result,
      meta: null
    });
  }

  static async getCyclePlanningSummary(req, res) {
    const { cycleId } = req.params;
    const result = await CyclePlanningService.getCyclePlanningSummary(req.user.id, cycleId);
    res.status(200).json({
      success: true,
      message: 'Cycle planning summary retrieved',
      data: result,
      meta: null
    });
  }
}

module.exports = { CyclePlanningController };
