const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/userModel');
const mongoose = require('mongoose');
const cloudinary = require('../utils/cloudinary');
const upload = require('../utils/multer');
const multer = require('multer');
const streamifier = require('streamifier');
const { OAuth2Client } = require('google-auth-library');
const { ImageAnnotatorClient } = require('@google-cloud/vision');
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const { isImageExplicit } = require('../utils/moderation');
const { sendVerificationEmail } = require('../utils/emailVerification');

const JWT_SECRET = process.env.JWT_SECRET || 'tu_jwt_secret_por_defecto';
const NodeGeocoder = require('node-geocoder');
const options = {
    provider: 'openstreetmap', // O Google si tienes key
};
const geocoder = NodeGeocoder(options);

const visionClient = new ImageAnnotatorClient({
    keyFilename: process.env.GOOGLE_APPLICATION_CREDENTIALS,
});

// Registro
exports.registerUser = async (req, res) => {
    console.log('BODY RECIBIDO EN /register:', req.body);
    try {
        const {
            email,
            password,
            username,
            firstName,
            lastName,
            gender,
            seeking,
            relationshipGoal,
            height,
            weight,
            age,
            goal,
            location
        } = req.body;

        if (!email || !password || !username || !gender || !relationshipGoal) {
            return res.status(400).json({ message: 'Faltan campos requeridos' });
        }

        // Buscar usuario existente
        const existingEmail = await User.findOne({ email });

        // Solo mostrar error si el usuario ya existe y NO es temporal
        if (existingEmail && !existingEmail.isTemporary) {
            return res.status(400).json({ message: 'El email ya está en uso' });
        }

        // Verificar si el username ya está en uso (por otro usuario)
        const existingUsername = await User.findOne({
            username,
            _id: { $ne: existingEmail ? existingEmail._id : null }
        });
        if (existingUsername) {
            return res.status(400).json({ message: 'El username ya está en uso' });
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Generar código de verificación (6 dígitos)
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();

        let newUser;

        if (existingEmail && existingEmail.isTemporary) {
            // Actualizar usuario temporal existente
            existingEmail.password = hashedPassword;
            existingEmail.username = username;
            existingEmail.firstName = firstName;
            existingEmail.lastName = lastName;
            existingEmail.gender = gender;
            existingEmail.seeking = seeking;
            existingEmail.relationshipGoal = relationshipGoal;
            existingEmail.height = height;
            existingEmail.weight = weight;
            existingEmail.age = age;
            existingEmail.goal = goal;
            existingEmail.usernameLastChangedAt = new Date();

            // Ya no es un usuario temporal
            existingEmail.isTemporary = false;
            existingEmail.registrationExpires = null;

            // Mantener el código de verificación si no está verificado
            if (!existingEmail.isVerified) {
                existingEmail.verificationCode = verificationCode;
            }

            newUser = existingEmail;
        } else {
            // Crear usuario nuevo
            newUser = new User({
                email,
                password: hashedPassword,
                username,
                firstName,
                lastName,
                gender,
                seeking,
                relationshipGoal,
                height,
                weight,
                age,
                goal,
                usernameLastChangedAt: new Date(),
                isVerified: false,
                verificationCode,
                isTemporary: false // Usuario completo, no temporal
            });
        }

        if (
            location &&
            location.type === 'Point' &&
            Array.isArray(location.coordinates) &&
            location.coordinates.length === 2
        ) {
            newUser.location = location;
            const [longitude, latitude] = location.coordinates;
            const resGeocode = await geocoder.reverse({ lat: latitude, lon: longitude });
            if (resGeocode && resGeocode.length > 0) {
                const bestMatch = resGeocode[0];
                newUser.city = bestMatch.city || bestMatch.administrativeLevels?.level2long || '';
                newUser.country = bestMatch.country || '';
            }
        }

        await newUser.save();

        // Enviar email de verificación si el usuario no está verificado
        if (!newUser.isVerified) {
            try {
                await sendVerificationEmail(email, verificationCode);
            } catch (emailError) {
                console.error("Error al enviar email:", emailError);
                // Opcional: podrías eliminar el usuario o marcarlo de alguna forma
            }
        }

        const token = jwt.sign({ userId: newUser._id }, JWT_SECRET, { expiresIn: '1d' });
        return res.status(201).json({
            message: 'Usuario registrado con éxito. Revisa tu correo para verificar tu cuenta.',
            token,
            user: {
                id: newUser._id,
                email: newUser.email,
                username: newUser.username,
                isPremium: newUser.isPremium
            }
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al registrar usuario' });
    }
};

exports.sendVerificationEmail = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) {
            return res.status(400).json({ message: 'El correo es obligatorio' });
        }

        const code = Math.floor(100000 + Math.random() * 900000).toString();

        let user = await User.findOne({ email: email.toLowerCase().trim() });
        if (!user) {
            // Crear usuario temporal
            user = new User({
                email: email.toLowerCase().trim(),
                isVerified: false,
                verificationCode: code,
                isTemporary: true, // Marcar como usuario temporal
                registrationExpires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 días para completar registro
            });
        } else {
            user.verificationCode = code;
            // Si el usuario ya existe pero no ha completado el registro
            if (user.isTemporary) {
                // Extender el tiempo de expiración
                user.registrationExpires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
            }
        }
        await user.save();

        const emailSent = await sendVerificationEmail(email, code);
        if (emailSent) {
            return res.status(200).json({ message: 'Código de verificación enviado' });
        } else {
            return res.status(500).json({ message: 'No se pudo enviar el correo de verificación' });
        }
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al enviar el correo de verificación', error: error.message });
    }
};

exports.verifyEmail = async (req, res) => {
    try {
        const { email, code } = req.body;
        const user = await User.findOne({ email: email.toLowerCase().trim() });
        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }
        if (user.verificationCode === code) {
            user.isVerified = true;
            await user.save();
            return res.status(200).json({ message: 'Correo verificado exitosamente' });
        } else {
            return res.status(400).json({ message: 'Código incorrecto' });
        }
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al verificar el correo', error: error.message });
    }
};

exports.checkUsername = async (req, res) => {
    try {
        const username = req.params.username;
        if (!username) {
            return res.status(400).json({ available: false, message: 'Username no especificado' });
        }

        const existing = await User.findOne({ username });
        if (existing) {
            return res.status(200).json({ available: false, message: 'El username ya está en uso' });
        } else {
            return res.status(200).json({ available: true, message: 'Username disponible' });
        }
    } catch (error) {
        console.error(error);
        return res.status(500).json({ available: false, message: 'Error al comprobar disponibilidad del username' });
    }
};

// Login
exports.loginUser = async (req, res) => {
    try {
        const { email, password } = req.body;
        const identifier = email;

        // Buscar usuario por email o username
        const user = await User.findOne({
            $or: [
                { email: identifier },
                { username: identifier }
            ]
        });
        if (!user) {
            return res.status(400).json({ message: 'Credenciales inválidas' });
        }

        if (!user.password) {
            if (!user.googleId) {
                await User.findByIdAndDelete(user._id);
                return res.status(400).json({
                    message: 'Cuenta eliminada por error de registro. Por favor, regístrate de nuevo.'
                });
            } else {
                return res.status(400).json({
                    message: 'Este usuario se registró con Google, utiliza el inicio de sesión con Google'
                });
            }
        }


        // Verificar password
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Credenciales inválidas' });
        }

        // Verificar si la cuenta está marcada como borrada
        if (user.isDeleted) {
            return res.status(403).json({ message: 'Esta cuenta ha sido eliminada.' });
        }

        // Generar token JWT
        const token = jwt.sign({ userId: user._id }, JWT_SECRET, { expiresIn: '1d' });

        return res.json({
            message: 'Login exitoso',
            token,
            user: {
                id: user._id,
                email: user.email,
                username: user.username,
                isPremium: user.isPremium,
                goal: user.goal,
                profilePicture: user.profilePicture,
            }
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al iniciar sesión' });
    }
};

exports.checkEmail = async (req, res) => {
    try {
        const email = req.params.email;
        if (!email) {
            return res.status(400).json({ available: false, message: 'Email no especificado' });
        }

        const existing = await User.findOne({ email: email.toLowerCase().trim() });
        if (existing) {
            return res.status(200).json({ available: false, message: 'El email ya está en uso' });
        } else {
            return res.status(200).json({ available: true, message: 'Email disponible' });
        }
    } catch (error) {
        console.error(error);
        return res.status(500).json({ available: false, message: 'Error al comprobar disponibilidad del email' });
    }
};

exports.updatePhotoOrder = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { photoIds } = req.body;

        if (!photoIds || !Array.isArray(photoIds)) {
            return res.status(400).json({ success: false, message: 'photoIds debe ser un array' });
        }

        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ success: false, message: 'Usuario no encontrado o eliminado' });
        }

        const newPhotosOrder = [];
        for (const id of photoIds) {
            const photoDoc = user.photos.id(id);
            if (photoDoc) {
                newPhotosOrder.push(photoDoc);
            }
        }

        user.photos = newPhotosOrder;

        await user.save();

        return res.json({
            success: true,
            message: 'Orden de fotos actualizado',
            photos: user.photos,
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al actualizar el orden de fotos',
            error: error.message
        });
    }
};


exports.googleLogin = async (req, res) => {
    const { token } = req.body;

    try {
        // Verificar el token de ID con Google
        const ticket = await client.verifyIdToken({
            idToken: token,
            audience: process.env.GOOGLE_CLIENT_ID
        });

        const payload = ticket.getPayload();
        const { sub, email, name, given_name, family_name, picture } = payload;

        let isNewAccount = false;
        // Buscar si el usuario ya existe
        let user = await User.findOne({ $or: [{ googleId: sub }, { email }] });

        if (user) {
            // Si ya existe, sólo actualiza googleId o la foto
            if (!user.googleId) {
                user.googleId = sub;
                if (!user.profilePicture || !user.profilePicture.url) {
                    user.profilePicture = {
                        url: picture || '',
                        public_id: '' // no subimos a Cloudinary
                    };
                }
                await user.save();
            }
        } else {
            isNewAccount = true;
            user = new User({
                email,
                firstName: given_name || '',
                lastName: family_name || '',
                username: `${given_name || 'user'}${family_name || 'anon'}${Math.floor(Math.random() * 1000)}`,
                googleId: sub,
                gender: 'Pendiente',
                relationshipGoal: 'Pendiente',
                profilePicture: picture
                    ? { url: picture, public_id: '' }
                    : { url: '', public_id: '' },
            });
            await user.save();
        }

        const jwtToken = jwt.sign({ userId: user._id }, JWT_SECRET, { expiresIn: '1d' });

        return res.json({
            message: 'Login con Google exitoso',
            token: jwtToken,
            user: {
                id: user._id,
                email: user.email,
                username: user.username,
                isPremium: user.isPremium,
                gender: user.gender,
                relationshipGoal: user.relationshipGoal
            },
            newAccount: isNewAccount
        });

    } catch (error) {
        console.error(error);
        return res.status(401).json({ message: 'Token de Google inválido' });
    }
};

exports.getCurrentUser = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId).select('-password -isDeleted -premiumExpiration -__v');
        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }
        return res.json({
            user: {
                id: user._id,
                email: user.email,
                username: user.username,
                isPremium: user.isPremium,
                goal: user.goal,
                profilePicture: user.profilePicture,
                firstName: user.firstName,
                lastName: user.lastName,
                gender: user.gender,
                age: user.age,
                height: user.height,
                weight: user.weight,
                seeking: user.seeking,
                biography: user.biography,
                relationshipGoal: user.relationshipGoal,
                photos: user.photos,
                location: user.location,
                city: user.city,
                country: user.country,
            }
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al obtener los datos del usuario' });
    }
};

exports.uploadProfilePicture = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        if (!req.file) {
            return res.status(400).json({ message: 'No se ha proporcionado ninguna imagen' });
        }

        const explicit = await isImageExplicit(req.file.buffer);
        if (explicit) {
            return res.status(400).json({ message: 'La imagen contiene contenido explícito o inapropiado' });
        }

        const cloudinaryResult = await new Promise((resolve, reject) => {
            const stream = cloudinary.uploader.upload_stream(
                {
                    folder: 'gymder/profile_pictures',
                    width: 1000,
                    height: 1000,
                    crop: 'limit',
                    quality: 'auto:best'
                },
                (error, result) => {
                    if (result) {
                        resolve(result);
                    } else {
                        reject(error);
                    }
                }
            );
            streamifier.createReadStream(req.file.buffer).pipe(stream);
        });

        if (user.profilePicture && user.profilePicture.public_id) {
            await cloudinary.uploader.destroy(user.profilePicture.public_id);
        }

        user.profilePicture = {
            url: cloudinaryResult.secure_url,
            public_id: cloudinaryResult.public_id
        };

        await user.save();

        return res.json({ message: 'Foto de perfil actualizada exitosamente', profilePicture: user.profilePicture });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al subir la foto de perfil', error: error.message });
    }
};

exports.uploadPhotos = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ message: 'No se han proporcionado fotos' });
        }

        if (user.photos.length + req.files.length > 6) {
            return res.status(400).json({ message: 'Puedes subir un máximo de 6 fotos adicionales' });
        }

        for (const file of req.files) {
            const explicit = await isImageExplicit(file.buffer);
            if (explicit) {
                return res.status(400).json({ message: 'Una o más imágenes contienen contenido explícito o inapropiado' });
            }
        }

        const uploadedPhotos = [];
        for (const file of req.files) {
            const cloudinaryResult = await new Promise((resolve, reject) => {
                const stream = cloudinary.uploader.upload_stream(
                    {
                        folder: 'gymder/profile_photos',
                        width: 1000,
                        height: 1000,
                        crop: 'limit',
                        quality: 'auto:best'
                    },
                    (error, result) => {
                        if (result) {
                            resolve(result);
                        } else {
                            reject(error);
                        }
                    }
                );
                streamifier.createReadStream(file.buffer).pipe(stream);
            });

            uploadedPhotos.push({
                url: cloudinaryResult.secure_url,
                public_id: cloudinaryResult.public_id
            });
        }

        user.photos.push(...uploadedPhotos);
        await user.save();

        return res.json({ message: 'Fotos subidas exitosamente', photos: user.photos });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al subir fotos adicionales', error: error.message });
    }
};

exports.deletePhoto = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { photoId, type } = req.params; // type: 'profile' o 'photo'

        if (!mongoose.Types.ObjectId.isValid(photoId)) {
            return res.status(400).json({ message: 'ID de foto inválido' });
        }

        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        if (type === 'profile') {
            if (!user.profilePicture || !user.profilePicture.public_id) {
                return res.status(400).json({ message: 'No tienes una foto de perfil para eliminar' });
            }

            // Eliminar la foto de perfil de Cloudinary
            await cloudinary.uploader.destroy(user.profilePicture.public_id);

            // Eliminar la foto de perfil del usuario
            user.profilePicture = undefined;

            await user.save();

            return res.json({ message: 'Foto de perfil eliminada exitosamente' });
        } else if (type === 'photo') {
            const photo = user.photos.find(p => p._id.equals(photoId));
            if (!photo) {
                return res.status(404).json({ message: 'Foto no encontrada' });
            }

            // 2. Eliminar la foto de Cloudinary
            await cloudinary.uploader.destroy(photo.public_id);

            // 3. Quitar la foto del array
            user.photos.pull(photo._id);  // <--- Esto elimina el subdocumento
            await user.save();

            return res.json({ message: 'Foto eliminada exitosamente', photos: user.photos });
        } else {
            return res.status(400).json({ message: 'Tipo de foto inválido' });
        }
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al eliminar la foto', error: error.message });
    }
};

exports.getUserPhotos = async (req, res) => {
    try {
        const userId = req.user.userId;

        const user = await User.findById(userId).select('profilePicture photos');

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        return res.json({
            message: 'Fotos obtenidas exitosamente',
            profilePicture: user.profilePicture,
            photos: user.photos
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al obtener las fotos', error: error.message });
    }
};

exports.uploadErrorHandler = (err, req, res, next) => {
    if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({ message: 'El archivo es demasiado grande. Tamaño máximo: 5MB' });
        }
        return res.status(400).json({ message: err.message });
    } else if (err) {
        // Otros errores
        return res.status(400).json({ message: err.message });
    }
    next();
};

// Middleware para verificar el token JWT
exports.authMiddleware = (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
        return res.status(401).json({ message: 'No hay token, autorización denegada' });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
        return res.status(401).json({ message: 'Formato de token inválido' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded; // userId está en decoded.userId
        next();
    } catch (error) {
        return res.status(401).json({ message: 'Token inválido' });
    }
};

// Actualizar perfil (nombre, apellido, descripción de perfil, etc.)
exports.updateProfile = async (req, res) => {
    try {
        const userId = req.user.userId;
        const {
            firstName,
            lastName,
            height,
            weight,
            squatWeight,
            deadliftWeight,
            benchPressWeight,
            gymTime,
            gymName,
            goal,
            gender,
            age,
            seeking,
            relationshipGoal,
            location,
            biography
        } = req.body;

        const user = await User.findById(userId);

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        // Actualizar campos
        if (firstName !== undefined) user.firstName = firstName;
        if (lastName !== undefined) user.lastName = lastName;
        if (height !== undefined) user.height = height;
        if (weight !== undefined) user.weight = weight;
        if (squatWeight !== undefined) user.squatWeight = squatWeight;
        if (deadliftWeight !== undefined) user.deadliftWeight = deadliftWeight;
        if (benchPressWeight !== undefined) user.benchPressWeight = benchPressWeight;
        if (gymTime !== undefined) user.gymTime = gymTime;
        if (gymName !== undefined) user.gymName = gymName;
        if (age !== undefined) user.age = age;
        if (goal !== undefined) user.goal = goal;
        if (
            location &&
            location.type === 'Point' &&
            Array.isArray(location.coordinates) &&
            location.coordinates.length === 2
        ) {
            user.location = location;

            const [longitude, latitude] = location.coordinates;

            const resGeocode = await geocoder.reverse({ lat: latitude, lon: longitude });

            if (resGeocode && resGeocode.length > 0) {
                const bestMatch = resGeocode[0];
                user.city = bestMatch.city || bestMatch.administrativeLevels?.level2long || '';
                user.country = bestMatch.country || '';
            }
        }

        if (biography !== undefined) {
            user.biography = biography;
        }

        // Actualizar nuevos campos
        if (gender !== undefined) user.gender = gender;
        if (seeking !== undefined) user.seeking = seeking;
        if (relationshipGoal !== undefined) user.relationshipGoal = relationshipGoal;

        await user.save();

        return res.json({ message: 'Perfil actualizado correctamente', user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al actualizar el perfil' });
    }
};

// Actualizar username (solo cada 10 días)
exports.updateUsername = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { newUsername } = req.body;

        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        // Verificar si ya existe ese username
        const existingUsername = await User.findOne({ username: newUsername });
        if (existingUsername) {
            return res.status(400).json({ message: 'El username ya está en uso' });
        }

        // Revisar la fecha de último cambio
        const now = new Date();
        if (user.usernameLastChangedAt) {
            const diff = now - user.usernameLastChangedAt; // Diferencia en ms
            const days = diff / (1000 * 60 * 60 * 24);

            if (days < 14) {
                return res.status(400).json({
                    message: `No puedes cambiar tu username hasta dentro de ${Math.ceil(14 - days)} días`
                });
            }
        }

        // Actualizar username
        user.username = newUsername;
        user.usernameLastChangedAt = now;
        await user.save();

        return res.json({ message: 'Username actualizado correctamente', user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al actualizar el username' });
    }
};

// Suscribirse a Premium (ej. suscripción mensual)
exports.subscribePremium = async (req, res) => {
    try {
        const userId = req.user.userId;
        // Podrías agregar lógica de pago real aquí...
        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        // Activar premium por 1 mes
        user.isPremium = true;
        const now = new Date();
        const oneMonthAfter = new Date(now.setMonth(now.getMonth() + 1));
        user.premiumExpiration = oneMonthAfter;

        await user.save();
        return res.json({ message: 'Suscripción a Premium activa', user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al suscribirse a Premium' });
    }
};

exports.changePassword = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { currentPassword, newPassword } = req.body;

        if (!currentPassword || !newPassword) {
            return res.status(400).json({ message: 'Faltan campos requeridos' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        // Verificar que la contraseña actual sea correcta
        const isMatch = await bcrypt.compare(currentPassword, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Contraseña actual incorrecta' });
        }

        // Hashear la nueva contraseña
        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);

        await user.save();

        return res.json({ message: 'Contraseña actualizada exitosamente' });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al cambiar la contraseña' });
    }
};

// Cancelar suscripción Premium
exports.cancelPremium = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        user.isPremium = false;
        user.premiumExpiration = null;

        await user.save();
        return res.json({ message: 'Suscripción a Premium cancelada', user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al cancelar Premium' });
    }
};

// Dar like a otro usuario
exports.likeUser = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { likedUserId } = req.params;

        if (!mongoose.Types.ObjectId.isValid(likedUserId)) {
            return res.status(400).json({ message: 'ID de usuario inválido' });
        }

        if (userId === likedUserId) {
            return res.status(400).json({ message: 'No puedes darte like a ti mismo' });
        }

        const user = await User.findById(userId);
        const likedUser = await User.findById(likedUserId);

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Tu cuenta no existe o está eliminada' });
        }
        if (!likedUser || likedUser.isDeleted) {
            return res.status(404).json({ message: 'El usuario al que intentas dar like no existe o está eliminado' });
        }

        // Verificar si el usuario ha bloqueado al likedUser o viceversa
        if (user.blockedUsers.includes(likedUserId) || likedUser.blockedUsers.includes(userId)) {
            return res.status(403).json({ message: 'No puedes dar like a este usuario debido a que está bloqueado.' });
        }

        // Verificar si ya le diste like
        if (user.likes.includes(likedUserId)) {
            return res.status(400).json({ message: 'Ya le diste like a este usuario' });
        }

        // Agregar el like
        user.likes.push(likedUserId);
        await user.save();

        // Verificar si el "likedUser" también te dio like (match)
        if (likedUser.likes.includes(userId)) {
            // Si ambos se han dado like -> MATCH
            // Agregamos en matches de ambos
            if (!user.matches.includes(likedUserId)) {
                user.matches.push(likedUserId);
            }
            if (!likedUser.matches.includes(userId)) {
                likedUser.matches.push(userId);
            }
            await user.save();
            await likedUser.save();

            // Opcional: Notificar a ambos usuarios sobre el match

            return res.json({ message: '¡Es un match!', user, matchedUser: likedUser });
        }

        return res.json({ message: 'Like enviado', user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al dar like' });
    }
};

// Eliminar la cuenta (borrado lógico)
exports.deleteAccount = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        // Marcamos la cuenta como "borrada"
        user.isDeleted = true;
        await user.save();

        return res.json({ message: 'Cuenta eliminada lógicamente', user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al eliminar la cuenta' });
    }
};

// Obtener usuarios que han dado like al usuario actual
exports.getUserLikes = async (req, res) => {
    try {
        const userId = req.user.userId;

        // Validar que el ID del usuario es válido
        if (!mongoose.Types.ObjectId.isValid(userId)) {
            return res.status(400).json({ message: 'ID de usuario inválido' });
        }

        // Obtener el usuario actual para acceder a su lista de matches
        const currentUser = await User.findById(userId);
        if (!currentUser) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        // Buscar todos los usuarios que han dado like al usuario actual, excluyendo aquellos ya en matches
        const usersWhoLiked = await User.find({
            likes: userId,
            isDeleted: false,
            _id: { $nin: currentUser.matches }  // Excluir usuarios con quienes ya se ha hecho match
        }).select('-password -blockedUsers');

        return res.json({
            message: 'Lista de usuarios que te han dado like',
            usersWhoLiked
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al obtener la lista de likes' });
    }
};


exports.getUserProfile = async (req, res) => {
    try {
        const { userId } = req.params;

        if (!mongoose.Types.ObjectId.isValid(userId)) {
            return res.status(400).json({ message: 'ID de usuario inválido' });
        }

        const requestingUserId = req.user.userId;
        const user = await User.findOne({ _id: userId, isDeleted: false }).select('-password -isDeleted -premiumExpiration -__v');

        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        const requestingUser = await User.findById(requestingUserId);
        if (requestingUser.blockedUsers.includes(userId) || user.blockedUsers.includes(requestingUserId)) {
            return res.status(403).json({ message: 'No tienes permiso para ver el perfil de este usuario.' });
        }

        return res.json({
            message: 'Perfil de usuario obtenido exitosamente',
            user: {
                id: user._id,
                email: user.email,
                username: user.username,
                isPremium: user.isPremium,
                goal: user.goal,
                profilePicture: user.profilePicture,
                firstName: user.firstName,
                lastName: user.lastName,
                age: user.age,
                height: user.height,
                weight: user.weight,
                gender: user.gender,
                biography: user.biography,
                seeking: user.seeking,
                relationshipGoal: user.relationshipGoal,
                photos: user.photos,
            }
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al obtener el perfil del usuario' });
    }
};

// Bloquear a otro usuario
exports.blockUser = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { targetUserId } = req.params;

        // Validar que el ID proporcionado es válido
        if (!mongoose.Types.ObjectId.isValid(targetUserId)) {
            return res.status(400).json({ message: 'ID de usuario inválido' });
        }

        if (userId === targetUserId) {
            return res.status(400).json({ message: 'No puedes bloquearte a ti mismo' });
        }

        const user = await User.findById(userId);
        const targetUser = await User.findById(targetUserId);

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Tu cuenta no existe o está eliminada' });
        }
        if (!targetUser || targetUser.isDeleted) {
            return res.status(404).json({ message: 'El usuario que intentas bloquear no existe o está eliminado' });
        }

        // Verificar si ya está bloqueado
        if (user.blockedUsers.includes(targetUserId)) {
            return res.status(400).json({ message: 'Ya has bloqueado a este usuario' });
        }

        // Bloquear al usuario
        user.blockedUsers.push(targetUserId);

        user.likes = user.likes.filter(id => id.toString() !== targetUserId);
        user.matches = user.matches.filter(id => id.toString() !== targetUserId);
        targetUser.likes = targetUser.likes.filter(id => id.toString() !== userId);
        targetUser.matches = targetUser.matches.filter(id => id.toString() !== userId);

        await user.save();
        await targetUser.save();

        return res.json({ message: `Has bloqueado a ${targetUser.username}`, user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al bloquear al usuario' });
    }
};

// Desbloquear a un usuario
exports.unblockUser = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { targetUserId } = req.params;

        // Validar que el ID proporcionado es válido
        if (!mongoose.Types.ObjectId.isValid(targetUserId)) {
            return res.status(400).json({ message: 'ID de usuario inválido' });
        }

        if (userId === targetUserId) {
            return res.status(400).json({ message: 'No puedes desbloquearte a ti mismo' });
        }

        const user = await User.findById(userId);
        const targetUser = await User.findById(targetUserId);

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Tu cuenta no existe o está eliminada' });
        }
        if (!targetUser || targetUser.isDeleted) {
            return res.status(404).json({ message: 'El usuario que intentas desbloquear no existe o está eliminado' });
        }

        // Verificar si está bloqueado
        if (!user.blockedUsers.includes(targetUserId)) {
            return res.status(400).json({ message: 'Este usuario no está bloqueado' });
        }

        // Desbloquear al usuario
        user.blockedUsers = user.blockedUsers.filter(id => id.toString() !== targetUserId);

        await user.save();

        return res.json({ message: `Has desbloqueado a ${targetUser.username}`, user });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al desbloquear al usuario' });
    }
};

// Obtener lista de usuarios bloqueados
exports.getBlockedUsers = async (req, res) => {
    try {
        const userId = req.user.userId;

        // Buscar el usuario y poblar los usuarios bloqueados
        const user = await User.findById(userId).populate('blockedUsers', '-password -isDeleted -premiumExpiration -__v');

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        return res.json({
            message: 'Lista de usuarios bloqueados',
            blockedUsers: user.blockedUsers
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al obtener la lista de usuarios bloqueados' });
    }
};

// Validar imágenes sin subirlas (solo verificación de contenido explícito)
exports.validateImages = async (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ message: 'No se han proporcionado imágenes' });
        }

        // Verificar cada imagen por contenido explícito
        const explicitResults = [];
        for (const file of req.files) {
            const explicit = await isImageExplicit(file.buffer);
            if (explicit) {
                explicitResults.push({
                    filename: file.originalname,
                    isExplicit: true
                });
            }
        }

        if (explicitResults.length > 0) {
            return res.status(400).json({
                success: false,
                message: 'Una o más imágenes contienen contenido explícito o inapropiado',
                explicitImages: explicitResults
            });
        }

        return res.status(200).json({
            success: true,
            message: 'Todas las imágenes son apropiadas'
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al validar las imágenes',
            error: error.message
        });
    }
};

// Actualizar contador de scroll y gestionar límites
exports.updateScrollCount = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { scrollLimitProfileId } = req.body;

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        // Incrementar el contador de scroll
        user.scrollCount = (user.scrollCount || 0) + 1;

        // Establecer límite según género (hombre: 20, mujer: 45)
        const SCROLL_LIMIT = user.gender === 'Masculino' ? 20 : 45;
        const LIMIT_DURATION_HOURS = 7; // duración del límite en horas

        // Si hay un límite vigente, verificar si ya expiró
        if (user.scrollLimitReachedAt) {
            const limitExpiration = new Date(user.scrollLimitReachedAt);
            limitExpiration.setHours(limitExpiration.getHours() + LIMIT_DURATION_HOURS);

            // Si ya expiró el límite, reiniciar contador y limpiar datos
            if (new Date() > limitExpiration) {
                user.scrollCount = 1; // Reiniciar con 1 (el scroll actual)
                user.scrollLimitReachedAt = null;
                user.scrollLimitProfileId = null;
            }
        }

        // Verificar si se alcanza el límite con este scroll
        let limitReached = false;
        if (user.scrollCount >= SCROLL_LIMIT && !user.isPremium) {
            // Marcar que se ha alcanzado el límite
            limitReached = true;

            // Guardar la hora actual como momento en que se alcanzó el límite
            if (!user.scrollLimitReachedAt) {
                user.scrollLimitReachedAt = new Date();
            }

            // Guardar el ID del perfil donde se alcanzó el límite si no hay uno guardado
            if (scrollLimitProfileId && !user.scrollLimitProfileId) {
                user.scrollLimitProfileId = scrollLimitProfileId;
            }
        }

        await user.save();

        // Responder con el estado actualizado
        const response = {
            success: true,
            scrollCount: user.scrollCount,
            limitReached,
        };

        // Si se alcanzó el límite, incluir información adicional
        if (limitReached) {
            const limitExpiration = new Date(user.scrollLimitReachedAt);
            limitExpiration.setHours(limitExpiration.getHours() + LIMIT_DURATION_HOURS);

            response.limitInfo = {
                limitReachedAt: user.scrollLimitReachedAt,
                limitExpiration,
                limitProfileId: user.scrollLimitProfileId,
                remainingHours: Math.max(0, Math.ceil((limitExpiration - new Date()) / (1000 * 60 * 60))),
            };
        }

        return res.json(response);
    } catch (error) {
        console.error('Error al actualizar contador de scroll:', error);
        return res.status(500).json({ message: 'Error del servidor' });
    }
};

// Obtener el estado actual del límite de scroll
exports.getScrollLimitStatus = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);

        if (!user) {
            return res.status(404).json({ message: 'Usuario no encontrado' });
        }

        // Verificar si hay un límite activo
        let limitActive = false;
        let limitInfo = null;

        if (user.scrollLimitReachedAt) {
            const LIMIT_DURATION_HOURS = 7;
            const limitExpiration = new Date(user.scrollLimitReachedAt);
            limitExpiration.setHours(limitExpiration.getHours() + LIMIT_DURATION_HOURS);

            // Verificar si el límite sigue activo
            if (new Date() <= limitExpiration && !user.isPremium) {
                limitActive = true;

                limitInfo = {
                    limitReachedAt: user.scrollLimitReachedAt,
                    limitExpiration,
                    limitProfileId: user.scrollLimitProfileId,
                    remainingHours: Math.max(0, Math.ceil((limitExpiration - new Date()) / (1000 * 60 * 60))),
                };
            } else {
                // Si el límite ha expirado, actualizamos el usuario
                user.scrollCount = 0;
                user.scrollLimitReachedAt = null;
                user.scrollLimitProfileId = null;
                await user.save();
            }
        }

        return res.json({
            success: true,
            scrollCount: user.scrollCount || 0,
            limitActive,
            limitInfo
        });
    } catch (error) {
        console.error('Error al obtener estado de límite de scroll:', error);
        return res.status(500).json({ message: 'Error del servidor' });
    }
};
