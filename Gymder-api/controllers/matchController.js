const mongoose = require('mongoose');
const User = require('../models/userModel');

// Obtener sugerencias de matches (aplica filtros, randomización y excluye perfiles ya vistos)
exports.getSuggestedMatches = async (req, res) => {
    try {
        const userId = req.user.userId;
        const user = await User.findById(userId);
        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        const {
            ageMin,
            ageMax,
            weightMin,
            weightMax,
            heightMin,
            heightMax,
            gymStage,
            relationshipGoal,
            distanceMin,
            distanceMax,
            useLocation,
        } = req.query;

        // Verificar si hay un límite de scroll activo
        let limitActive = false;
        let limitProfileId = null;

        if (user.scrollLimitReachedAt && !user.isPremium) {
            const LIMIT_DURATION_HOURS = 7;
            const limitExpiration = new Date(user.scrollLimitReachedAt);
            limitExpiration.setHours(limitExpiration.getHours() + LIMIT_DURATION_HOURS);

            // Si el límite sigue activo
            if (new Date() <= limitExpiration) {
                limitActive = true;
                limitProfileId = user.scrollLimitProfileId;
            } else {
                // Si ya expiró, limpiar los datos
                user.scrollCount = 0;
                user.scrollLimitReachedAt = null;
                user.scrollLimitProfileId = null;
                await user.save();
            }
        }

        // Construir consulta base: excluir al usuario actual y los ya vistos
        const seenProfiles = user.seenProfiles || [];
        const query = {
            isDeleted: false,
            _id: {
                $nin: [
                    new mongoose.Types.ObjectId(userId),
                    ...seenProfiles.map(id => new mongoose.Types.ObjectId(id))
                ]
            },
        };

        // Filtros adicionales
        if (ageMin || ageMax) {
            const ageFilter = {};
            if (ageMin) ageFilter.$gte = Number(ageMin);
            if (ageMax) ageFilter.$lte = Number(ageMax);
            query.age = ageFilter;
        }
        if (weightMin || weightMax) {
            const wFilter = {};
            if (weightMin) wFilter.$gte = Number(weightMin);
            if (weightMax) wFilter.$lte = Number(weightMax);
            query.weight = wFilter;
        }
        if (heightMin || heightMax) {
            const hFilter = {};
            if (heightMin) hFilter.$gte = Number(heightMin);
            if (heightMax) hFilter.$lte = Number(heightMax);
            query.height = hFilter;
        }
        if (gymStage && gymStage !== 'Todos') {
            query.goal = gymStage;
        }
        if (relationshipGoal && relationshipGoal !== 'Todos') {
            query.relationshipGoal = relationshipGoal;
        }
        if (user.seeking && user.seeking.length > 0) {
            query.gender = { $in: user.seeking };
        }

        const skip = req.query.skip ? parseInt(req.query.skip, 10) : 0;
        const limit = req.query.limit ? parseInt(req.query.limit, 10) : 20;

        // Si hay un perfil límite activo y es la primera página de resultados
        let results = [];
        let limitProfile = null;

        if (limitActive && limitProfileId && skip === 0) {
            try {
                // Intentar obtener el perfil límite
                limitProfile = await User.findById(limitProfileId);

                // Si encontramos el perfil límite, lo reservamos para añadirlo al principio
                if (limitProfile) {
                    console.log(`Encontrado perfil límite: ${limitProfile.username}`);
                }
            } catch (err) {
                console.error('Error al obtener perfil límite:', err);
            }
        }

        // Si no se aplica filtro por ubicación, usamos una pipeline simple para randomizar
        if (
            !user.location ||
            !Array.isArray(user.location.coordinates) ||
            user.location.coordinates.length !== 2 ||
            (user.location.coordinates[0] === 0 && user.location.coordinates[1] === 0) ||
            useLocation !== 'true'
        ) {
            const pipeline = [
                { $match: query },
                { $addFields: { random: { $rand: {} } } },
                { $sort: { random: 1 } },
                { $skip: skip },
                { $limit: limit },
                { $project: { random: 0 } }
            ];
            results = await User.aggregate(pipeline);
        } else {
            // Filtrado por ubicación usando $geoNear
            const minDistMeters = distanceMin ? parseInt(distanceMin, 10) * 1000 : 0;
            const maxDistMeters = distanceMax ? parseInt(distanceMax, 10) * 1000 : 50000;
            const [userLon, userLat] = user.location.coordinates;

            const pipeline = [
                {
                    $geoNear: {
                        near: { type: 'Point', coordinates: [userLon, userLat] },
                        distanceField: 'dist.calculated',
                        minDistance: minDistMeters,
                        maxDistance: maxDistMeters,
                        query: query,
                        spherical: true
                    }
                },
                { $skip: skip },
                { $limit: limit }
            ];
            results = await User.aggregate(pipeline);
        }

        // Si tenemos un perfil límite y estamos en la primera página, insertarlo al principio
        if (limitProfile && skip === 0) {
            // Convertimos el documento Mongoose a objeto plano para evitar problemas
            const limitProfileObj = limitProfile.toObject();

            // Filtrar el perfil límite si ya está en los resultados para evitar duplicados
            const existingIndex = results.findIndex(r => r._id.toString() === limitProfileId.toString());
            if (existingIndex >= 0) {
                results.splice(existingIndex, 1);
            }

            // Insertar el perfil límite al principio
            results.unshift(limitProfileObj);
        }

        return res.json({ success: true, matches: results });

    } catch (error) {
        console.error('Error al obtener matches sugeridos:', error);
        return res.status(500).json({ message: 'Error del servidor' });
    }
};

// Endpoint para actualizar los perfiles vistos
exports.updateSeenProfiles = async (req, res) => {
    try {
        const userId = req.user.userId;
        const { seen } = req.body; // Se espera un arreglo de IDs (por ejemplo: ["id1", "id2", ...])
        if (!seen || !Array.isArray(seen)) {
            return res.status(400).json({ success: false, message: 'No se proporcionaron perfiles vistos' });
        }
        await User.findByIdAndUpdate(userId, {
            $addToSet: { seenProfiles: { $each: seen.map(id => new mongoose.Types.ObjectId(id)) } }
        });
        return res.json({ success: true, message: 'Perfiles vistos actualizados' });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al actualizar perfiles vistos',
            error: error.message,
        });
    }
};

// Obtener matches actuales
exports.getMatches = async (req, res) => {
    try {
        const userId = req.user.userId;

        const user = await User.findById(userId).populate('matches', '-password -isDeleted -premiumExpiration -__v');

        if (!user || user.isDeleted) {
            return res.status(404).json({ message: 'Usuario no encontrado o eliminado' });
        }

        return res.json({ matches: user.matches });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ message: 'Error al obtener los matches' });
    }
};
