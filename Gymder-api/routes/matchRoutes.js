// routes/matchRoutes.js
const express = require('express');
const router = express.Router();
const matchController = require('../controllers/matchController');
const userController = require('../controllers/userController');

// Ruta protegida para obtener sugerencias de matches
router.get('/suggested', userController.authMiddleware, matchController.getSuggestedMatches);

// Ruta protegida para obtener matches actuales
router.get('/', userController.authMiddleware, matchController.getMatches);

router.post('/seen', userController.authMiddleware, matchController.updateSeenProfiles);

module.exports = router;
