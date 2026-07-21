const { UserService } = require('../services/user.service');

class UserController {
  static async getProfile(req, res) {
    const result = await UserService.getProfile(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Profile retrieved successfully',
      data: result,
      meta: null
    });
  }

  static async getProfileSummary(req, res) {
    const result = await UserService.getProfileSummary(req.user.id);
    res.status(200).json({
      success: true,
      message: 'Profile summary retrieved successfully',
      data: result,
      meta: null
    });
  }

  static async updateProfile(req, res) {
    // Flutter might send this to multiple endpoints: /users/profile, /users/demographics, /users/profile/update
    // We handle all updates dynamically based on the body.
    const result = await UserService.updateProfile(req.user.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: result,
      meta: null
    });
  }
}

module.exports = { UserController };
