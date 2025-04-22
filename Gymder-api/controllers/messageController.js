const Message = require('../models/messageModel');
const cloudinary = require('../utils/cloudinary');
const streamifier = require('streamifier');
const mongoose = require('mongoose');
const User = require('../models/userModel');

exports.getConversation = async (req, res) => {
    try {
        const { user1, user2, limit = 30, skip = 0 } = req.query;
        const currentUserId = req.user.userId;

        const pageLimit = parseInt(limit);
        const pageSkip = parseInt(skip);

        const messages = await Message.find({
            $or: [
                { sender: user1, receiver: user2 },
                { sender: user2, receiver: user1 }
            ],
            hiddenFor: { $ne: currentUserId }
        })
            .sort({ createdAt: -1 })
            .skip(pageSkip)
            .limit(pageLimit);

        return res.json({
            success: true,
            messages
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al obtener la conversación'
        });
    }
};

exports.getLastMessagesForUser = async (req, res) => {
    try {
        const currentUserId = new mongoose.Types.ObjectId(req.user.userId);
        // Buscamos al usuario para obtener sus matches
        const user = await User.findById(currentUserId).populate('matches');
        if (!user) {
            return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
        }

        const matchIds = user.matches.map(m => m._id);

        const pipeline = [
            {
                $match: {
                    $or: [
                        { sender: currentUserId, receiver: { $in: matchIds } },
                        { receiver: currentUserId, sender: { $in: matchIds } }
                    ],
                    hiddenFor: { $ne: currentUserId }
                }
            },
            // Ordenar de más reciente a más antiguo
            { $sort: { createdAt: -1 } },
            {
                $group: {
                    // Agrupamos por "el otro usuario"
                    _id: {
                        $cond: [
                            { $eq: ["$sender", currentUserId] },
                            "$receiver",
                            "$sender"
                        ]
                    },
                    // "lastMsg" será el mensaje más reciente ($first) tras ordenar descendente
                    lastMsg: { $first: "$$ROOT" }
                }
            }
        ];

        const lastMessages = await Message.aggregate(pipeline);

        return res.json({
            success: true,
            lastMessages
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al obtener últimos mensajes'
        });
    }
};

exports.uploadChatImage = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, message: 'No se ha proporcionado ninguna imagen' });
        }

        const cloudinaryResult = await new Promise((resolve, reject) => {
            const stream = cloudinary.uploader.upload_stream(
                {
                    folder: 'gymder/chat_photos',
                    width: 2000,
                    height: 2000,
                    crop: 'limit',
                    quality: 'auto:best'
                },
                (error, result) => {
                    if (error) reject(error);
                    else resolve(result);
                }
            );
            streamifier.createReadStream(req.file.buffer).pipe(stream);
        });

        return res.json({
            success: true,
            url: cloudinaryResult.secure_url,
            public_id: cloudinaryResult.public_id
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al subir la imagen de chat',
            error: error.message
        });
    }
};

exports.hideMessage = async (req, res) => {
    try {
        const userId = req.user.userId; // autenticado
        const { messageId } = req.params;

        // Verificar que sea un ID de MongoDB válido
        if (!mongoose.Types.ObjectId.isValid(messageId)) {
            return res.status(400).json({ success: false, message: 'ID de mensaje inválido' });
        }

        // Buscar el mensaje
        const message = await Message.findById(messageId);
        if (!message) {
            return res.status(404).json({ success: false, message: 'Mensaje no encontrado' });
        }

        // Agregar el userId a hiddenFor si no existe ya
        if (!message.hiddenFor.includes(userId)) {
            message.hiddenFor.push(userId);
            await message.save();
        }

        return res.json({ success: true, message: 'Mensaje ocultado para el usuario' });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al ocultar el mensaje'
        });
    }
};

exports.uploadChatAudio = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'No se ha proporcionado ningún archivo de audio'
            });
        }

        const cloudinaryResult = await new Promise((resolve, reject) => {
            const stream = cloudinary.uploader.upload_stream(
                {
                    resource_type: 'auto',
                    folder: 'gymder/chat/audios',
                },
                (error, result) => {
                    if (error) reject(error);
                    else resolve(result);
                }
            );
            streamifier.createReadStream(req.file.buffer).pipe(stream);
        });

        return res.json({
            success: true,
            url: cloudinaryResult.secure_url,
            duration: req.body.duration || 0
        });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al subir el archivo de audio'
        });
    }
};

exports.uploadChatVideo = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, message: 'No se ha proporcionado ningún video' });
        }
        const duration = parseFloat(req.body.duration) || 0;
        if (duration > 120) {
            return res.status(400).json({ success: false, message: 'Video demasiado largo (máx. 2 minutos)' });
        }
        const cloudinaryResult = await new Promise((resolve, reject) => {
            const stream = cloudinary.uploader.upload_stream(
                { resource_type: 'video', folder: 'gymder/chat/videos' },
                (error, result) => { if (error) reject(error); else resolve(result); }
            );
            streamifier.createReadStream(req.file.buffer).pipe(stream);
        });
        return res.json({ success: true, url: cloudinaryResult.secure_url, duration });
    } catch (error) {
        console.error(error);
        return res.status(500).json({ success: false, message: 'Error al subir el video de chat', error: error.message });
    }
};

exports.hideConversation = async (req, res) => {
    try {
        const { otherUserId } = req.body; // con quién "borra"
        const currentUserId = req.user.userId;

        // set userId en hiddenFor de todos los mensajes 
        await Message.updateMany(
            {
                $or: [
                    { sender: currentUserId, receiver: otherUserId },
                    { sender: otherUserId, receiver: currentUserId }
                ],
                hiddenFor: { $ne: currentUserId }
            },
            { $push: { hiddenFor: currentUserId } }
        );

        return res.json({ success: true, message: 'Conversación ocultada' });
    } catch (error) {
        console.error(error);
        return res.status(500).json({
            success: false,
            message: 'Error al ocultar la conversación'
        });
    }
};