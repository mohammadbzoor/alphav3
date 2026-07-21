const { Router } = require('express');
const { UserController } = require('../controllers/user.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { asyncHandler } = require('../utils/async-handler');

const router = Router();

// Get profile
router.get('/profile', authenticate, asyncHandler(UserController.getProfile));
router.get('/profile/summary', authenticate, asyncHandler(UserController.getProfileSummary));

// Update profile (covering different flutter endpoints)
router.patch('/profile', authenticate, asyncHandler(UserController.updateProfile));
router.patch('/demographics', authenticate, asyncHandler(UserController.updateProfile));
router.put('/profile/update', authenticate, asyncHandler(UserController.updateProfile));

module.exports = router;
