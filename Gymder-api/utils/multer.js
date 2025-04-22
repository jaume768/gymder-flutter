const multer = require('multer');

const storage = multer.memoryStorage();

const upload = multer({
    storage,
    limits: { fileSize: 1000 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        if (file.fieldname === 'chatAudio') {
            const allowedAudioTypes = /aac|mpeg|wav|ogg/;
            const fileAudioType = file.mimetype.split('/')[1];
            if (allowedAudioTypes.test(fileAudioType)) {
                return cb(null, true);
            }
            return cb(new Error(`Tipo de archivo no permitido: ${file.mimetype}`));
        }

        if (file.fieldname === 'chatVideo') {
            const allowedVideoTypes = /mp4|mov|mpeg|avi|mkv/;
            const fileVideoType = file.mimetype.split('/')[1];
            if (allowedVideoTypes.test(fileVideoType)) {
                return cb(null, true);
            }
            return cb(new Error(`Tipo de archivo de video no permitido: ${file.mimetype}`));
        }

        const allowedImageTypes = /jpeg|jpg|png/;
        const mimeTypeValid = allowedImageTypes.test(file.mimetype);
        const extNameValid = allowedImageTypes.test(file.originalname.toLowerCase());

        if (mimeTypeValid && extNameValid) {
            return cb(null, true);
        }

        if (!mimeTypeValid) {
            return cb(new Error(`Tipo de archivo no permitido: ${file.mimetype}`));
        }

        if (!extNameValid) {
            return cb(new Error(`Extensión de archivo no permitida: ${file.originalname}`));
        }

        cb(new Error('Solo se permiten archivos JPEG, JPG y PNG'));
    }
});

module.exports = upload;
