const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    receiver: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    message: { type: String, default: '' },
    type: {
        type: String,
        enum: ['text', 'image', 'audio', 'video'], // Añadido 'video'
        default: 'text'
    },
    imageUrl: { type: String, default: '' },
    audioUrl: { type: String, default: '' }, // Nuevo campo para URL del audio
    audioDuration: { type: Number, default: 0 }, // Duración del audio en segundos
    videoUrl: { type: String, default: '' }, // URL del video
    videoDuration: { type: Number, default: 0 }, // Duración del video en segundos
    hiddenFor: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    seenAt: { type: Date, default: null }
}, { timestamps: true });

module.exports = mongoose.model('Message', messageSchema);