'use strict';

const { CycleService } = require('../services/cycle.service');

class CycleController {
  /**
   * POST /api/v1/financial-cycles
   */
  static async createCycle(req, res) {
    const userId         = req.user.id;
    const idempotencyKey = req.headers['idempotency-key'] || req.body?.idempotencyKey || null;

    const { cycle, replayed } = await CycleService.createCycle(userId, { idempotencyKey });

    res.status(replayed ? 200 : 201).json({
      success:  true,
      replayed: replayed || false,
      message:  replayed
        ? 'Financial cycle already exists (idempotent replay).'
        : 'Financial cycle created successfully.',
      data: cycle,
    });
  }

  /**
   * GET /api/v1/financial-cycles/current
   */
  static async getCurrentCycle(req, res) {
    const cycle = await CycleService.getCurrentCycle(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Current cycle retrieved successfully.',
      data:    cycle,
    });
  }

  /**
   * GET /api/v1/financial-cycles/:id
   */
  static async getCycleById(req, res) {
    const cycle = await CycleService.getCycleById(req.user.id, req.params.id);
    res.status(200).json({
      success: true,
      message: 'Cycle retrieved successfully.',
      data:    cycle,
    });
  }
}

module.exports = { CycleController };
