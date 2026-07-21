import { describe, it, expect, vi } from 'vitest';
import { FinanceService } from '../services/finance.service';
import { FinanceRepository } from '../repositories/finance.repository';

// Mock DB tests if needed
describe('Financial Goals Phase 2A: Planning & Creation', () => {

  describe('Planning Preview', () => {
    it('calculates cycles correctly for contribution_based', () => {
      const result = FinanceService.planningPreview({
        targetAmount: 1000,
        planningMode: 'contribution_based',
        plannedContribution: 300,
      });
      expect(result.isEstimated).toBe(true);
      expect(result.remainingAmount).toBe(1000);
      expect(result.cyclesRequired).toBe(4); // ceil(1000/300) = 4
      expect(result.requiredContribution).toBeNull();
    });

    it('calculates required contribution for deadline_based', () => {
      const target = new Date();
      target.setFullYear(target.getFullYear() + 1); // 12 months from now

      const result = FinanceService.planningPreview({
        targetAmount: 1200,
        planningMode: 'deadline_based',
        targetDate: target.toISOString(),
      });
      expect(result.isEstimated).toBe(true);
      expect(result.remainingAmount).toBe(1200);
      expect(result.cyclesRequired).toBeNull();
      expect(result.requiredContribution).toBe(100); // 1200 / 12 = 100
    });
  });

  describe('Goal Validation Boundaries', () => {
    it('rejects target amount <= 0', () => {
      expect(() => FinanceService.validateGoalData({ targetAmount: 0 }))
        .toThrow('Target amount must be greater than zero');
    });

    it('rejects target amount < current balance', () => {
      expect(() => FinanceService.validateGoalData({ targetAmount: 50, goalType: 'laptop' }, 100))
        .toThrow('Target amount cannot be lower than current balance');
    });

    it('rejects unsupported goal types', () => {
      expect(() => FinanceService.validateGoalData({ targetAmount: 500, goalType: 'invalid_type' }))
        .toThrow('Unsupported goal type');
    });

    it('requires customName when goalType is custom', () => {
      expect(() => FinanceService.validateGoalData({ targetAmount: 500, goalType: 'custom' }))
        .toThrow('Custom name is required for custom goals');
    });

    it('rejects priority out of bounds', () => {
      expect(() => FinanceService.validateGoalData({ targetAmount: 500, goalType: 'laptop', priority: 11 }))
        .toThrow('Priority must be between 1 and 10');
    });

    it('rejects past target dates for deadline_based', () => {
      const past = new Date();
      past.setFullYear(past.getFullYear() - 1);
      expect(() => FinanceService.validateGoalData({
        targetAmount: 500, goalType: 'laptop', priority: 5,
        planningMode: 'deadline_based', targetDate: past.toISOString()
      })).toThrow('Target date cannot be in the past');
    });

    it('rejects target dates > 7 years for deadline_based', () => {
      const future = new Date();
      future.setFullYear(future.getFullYear() + 8);
      expect(() => FinanceService.validateGoalData({
        targetAmount: 500, goalType: 'laptop', priority: 5,
        planningMode: 'deadline_based', targetDate: future.toISOString()
      })).toThrow('Target date cannot be more than 7 years ahead');
    });

    it('validates a correct custom goal', () => {
      expect(() => FinanceService.validateGoalData({
        targetAmount: 500, goalType: 'custom', customName: 'My Goal', priority: 5,
        planningMode: 'contribution_based', plannedContribution: 100
      })).not.toThrow();
    });
  });
});
