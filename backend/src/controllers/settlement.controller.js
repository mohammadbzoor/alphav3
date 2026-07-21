/**
 * SettlementController – Phase 3B – Financial Cycle Settlement and Closure
 *
 * Handles HTTP requests for:
 *   - POST /api/v1/financial-cycles/current/settlement-preview
 *   - POST /api/v1/financial-cycles/current/settlement
 *   - POST /api/v1/financial-cycles/current/close
 */

'use strict';

const { SettlementService } = require('../services/settlement.service');

class SettlementController {
  /**
   * POST /api/v1/financial-cycles/current/settlement-preview
   */
  static async previewSettlement(req, res) {
    const userId = req.user.id;

    const preview = await SettlementService.previewSettlement(userId);

    res.status(200).json({
      success: true,
      data: preview
    });
  }

  /**
   * POST /api/v1/financial-cycles/current/settlement
   */
  static async beginSettlement(req, res) {
    const userId = req.user.id;
    const { idempotencyKey } = req.body || {};

    const result = await SettlementService.beginSettlement(userId, { idempotencyKey });

    res.status(result.replayed ? 200 : 201).json({
      success: true,
      replayed: result.replayed || false,
      message: result.replayed
        ? 'Settlement already exists (idempotent replay).'
        : 'Settlement begun successfully.',
      data: result
    });
  }

  /**
   * POST /api/v1/financial-cycles/current/close
   */
  static async closeCycle(req, res) {
    const userId = req.user.id;
    const { actions, idempotencyKey } = req.body || {};

    const result = await SettlementService.closeCycle(userId, { actions, idempotencyKey });

    res.status(200).json({
      success: true,
      message: 'Cycle closed successfully.',
      data: result
    });
  }
}

module.exports = { SettlementController };
