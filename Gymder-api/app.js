// app.js
const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const http = require('http'); // Necesario para Socket.io
const socketIo = require('socket.io'); // Socket.io
const userRoutes = require('./routes/userRoutes');
const messageRoutes = require('./routes/messageRoutes');
const matchRoutes = require('./routes/matchRoutes');
const accountDeletionRoutes = require('./routes/accountDeletion');
const privacyPolicyRoutes = require('./routes/privacyPolicy');
const securityStandardsRoutes = require('./routes/securityStandards');
const Message = require('./models/messageModel');

dotenv.config();

const app = express();

// Middleware para parsear JSON
app.use(express.json());

// Conectar a MongoDB
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('Conectado a MongoDB'))
  .catch(err => console.error('Error al conectar a MongoDB:', err));

// Rutas
app.use('/api/users', userRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/matches', matchRoutes);

app.use('/delete-account', accountDeletionRoutes);
app.use('/privacy-policy', privacyPolicyRoutes);
app.use('/security-standards', securityStandardsRoutes);

// Crear el servidor HTTP a partir de Express
const server = http.createServer(app);

// Configurar Socket.io con CORS
const io = socketIo(server, {
  cors: {
    origin: "*", // Cambia esto a tu dominio/puerto en producción
    methods: ["GET", "POST"]
  }
});

// Manejar conexiones de Socket.io
io.on('connection', (socket) => {
  console.log('Nuevo cliente conectado:', socket.id);

  // Unirse a una sala específica
  socket.on('joinRoom', ({ userId, matchedUserId }) => {
    const room = [userId, matchedUserId].sort().join('_');
    socket.userId = userId;
    socket.matchedUserId = matchedUserId;
    socket.join(room);
    console.log(`Usuario ${userId} se unió a la sala ${room}`);
    io.to(room).emit('userOnline', { userId });
  });

  socket.on('sendMessage', async (data) => {
    const { senderId, receiverId, message, type, imageUrl, audioUrl, audioDuration, videoUrl, videoDuration } = data;
    const room = [senderId, receiverId].sort().join('_');
    try {
      const newMessage = new Message({
        sender: senderId,
        receiver: receiverId,
        type: type || 'text',
        message: message || '',
        imageUrl: imageUrl || '',
        audioUrl: audioUrl || '',
        audioDuration: audioDuration || 0,
        videoUrl: videoUrl || '',
        videoDuration: videoDuration || 0
      });
      await newMessage.save();

      io.to(room).emit('receiveMessage', {
        senderId,
        type: newMessage.type,
        message: newMessage.message,
        imageUrl: newMessage.imageUrl,
        audioUrl: newMessage.audioUrl,
        audioDuration: newMessage.audioDuration,
        videoUrl: newMessage.videoUrl,
        videoDuration: newMessage.videoDuration,
        timestamp: newMessage.createdAt
      });
    } catch (error) {
      console.error('Error al enviar el mensaje:', error);
      socket.emit('errorMessage', { message: 'No se pudo enviar el mensaje.' });
    }
  });

  // Modificación: Emitir a toda la sala al marcar como leído
  socket.on('markAsRead', async (data) => {
    const { userId, matchedUserId } = data;
    try {
      await Message.updateMany(
        { sender: matchedUserId, receiver: userId, seenAt: null },
        { $set: { seenAt: new Date() } }
      );
      const room = [userId, matchedUserId].sort().join('_');
      io.to(room).emit('messagesMarkedAsRead', { matchedUserId, userId });
    } catch (error) {
      console.error("Error al marcar mensajes como leídos:", error);
    }
  });

  // Desconexión
  socket.on('disconnect', () => {
    console.log('Cliente desconectado:', socket.id);
    if (socket.userId && socket.matchedUserId) {
      const room = [socket.userId, socket.matchedUserId].sort().join('_');
      io.to(room).emit('userOffline', { userId: socket.userId });
    }
  });
});

// Manejo de errores globales
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Algo salió mal!', error: err.message });
});

// Iniciar el servidor
const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Servidor corriendo en el puerto ${PORT}`);
});
