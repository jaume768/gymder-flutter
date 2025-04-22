const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const upload = require('../utils/multer');
const { loginLimiter } = require('../utils/rateLimiter');

// Rutas públicas
router.post('/register', userController.registerUser);
router.post('/send-verification-email', userController.sendVerificationEmail);
router.post('/verify-email', userController.verifyEmail);
router.post('/login', loginLimiter, userController.loginUser);
router.post('/auth/google', userController.googleLogin);
router.get('/check_email/:email', userController.checkEmail);
router.post('/validate/images', upload.array('photos', 5), userController.validateImages, userController.uploadErrorHandler);

// Rutas protegidas (requieren autenticación)
router.get('/profile', userController.authMiddleware, userController.getCurrentUser);
router.patch('/profile', userController.authMiddleware, userController.updateProfile);
router.patch('/username', userController.authMiddleware, userController.updateUsername);
router.get('/profile/:userId', userController.authMiddleware, userController.getUserProfile);
router.patch('/order/photos', userController.authMiddleware, userController.updatePhotoOrder);
router.patch('/change-password', userController.authMiddleware, userController.changePassword);

// Premium
router.post('/subscribe', userController.authMiddleware, userController.subscribePremium);
router.post('/cancel', userController.authMiddleware, userController.cancelPremium);

// Likes
router.post('/like/:likedUserId', userController.authMiddleware, userController.likeUser);
router.get('/likes', userController.authMiddleware, userController.getUserLikes);

// Obtener el perfil de otro usuario
router.get('/profile/:userId', userController.authMiddleware, userController.getUserProfile);

// Bloqueo
router.post('/block/:targetUserId', userController.authMiddleware, userController.blockUser);
router.post('/unblock/:targetUserId', userController.authMiddleware, userController.unblockUser);
router.get('/blocked', userController.authMiddleware, userController.getBlockedUsers);

router.get('/check_username/:username', userController.checkUsername);

// Fotos
// Subir foto de perfil
router.post('/upload/profile-picture', userController.authMiddleware, upload.single('profilePicture'), userController.uploadProfilePicture, userController.uploadErrorHandler);

// Subir fotos adicionales
router.post('/upload/photos', userController.authMiddleware, upload.array('photos', 5), userController.uploadPhotos, userController.uploadErrorHandler);

// Eliminar una foto
// Parámetros: photoId (ID de la foto en Mongoose), type ('profile' o 'photo')
router.delete('/delete/photo/:photoId/:type', userController.authMiddleware, userController.deletePhoto);

// Obtener todas las fotos del usuario
router.get('/photos', userController.authMiddleware, userController.getUserPhotos);

// Borrado lógico
router.delete('/deleteAccount', userController.authMiddleware, userController.deleteAccount);

// Rutas para gestión de límites de scroll
router.post('/scroll/update', userController.authMiddleware, userController.updateScrollCount);
router.get('/scroll/limit-status', userController.authMiddleware, userController.getScrollLimitStatus);

module.exports = router;