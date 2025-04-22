const express = require('express');
const router = express.Router();
const messageController = require('../controllers/messageController');
const userController = require('../controllers/userController');
const upload = require('../utils/multer');

router.get('/conversation', userController.authMiddleware, messageController.getConversation);

router.post(
    '/upload',
    userController.authMiddleware,
    upload.single('chatImage'),
    messageController.uploadChatImage
);

router.delete(
    '/:messageId/hide',
    userController.authMiddleware,
    messageController.hideMessage
);

router.get(
    '/lastConversations',
    userController.authMiddleware,
    messageController.getLastMessagesForUser
);

router.post(
    '/upload-audio',
    userController.authMiddleware,
    upload.single('chatAudio'),
    messageController.uploadChatAudio
);

router.post(
    '/conversation/hide',
    userController.authMiddleware,
    messageController.hideConversation
);

router.post(
    '/upload-video',
    userController.authMiddleware,
    upload.single('chatVideo'),
    messageController.uploadChatVideo
);

module.exports = router;