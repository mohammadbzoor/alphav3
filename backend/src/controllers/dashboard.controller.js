const { DashboardQueryService } = require('../services/dashboard.query.service');

class DashboardController {
  static async getSummary(req, res) {
    try {
      const result = await DashboardQueryService.getSummary(req.user.id);
      res.status(200).json({
        success: true,
        message: 'Dashboard data retrieved successfully',
        data: result,
        meta: null
      });
    } catch (error) {
      console.error('Error fetching dashboard summary:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error while fetching dashboard summary',
        data: null
      });
    }
  }
}

module.exports = { DashboardController };
