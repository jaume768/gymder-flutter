const rateLimit = require('express-rate-limit');

// Limitador para las rutas de login
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 10, // Limitar a 10 solicitudes por IP
    message: 'Demasiados intentos de inicio de sesión desde esta IP, por favor intenta de nuevo después de 15 minutos'
});

// Puedes crear otros limitadores para diferentes rutas si es necesario

module.exports = { loginLimiter };