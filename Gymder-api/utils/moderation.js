const AWS = require('aws-sdk');

AWS.config.update({ region: process.env.AWS_REGION || 'us-east-1' });

const rekognition = new AWS.Rekognition();

async function isImageExplicit(imageBuffer) {
    const params = {
        Image: {
            Bytes: imageBuffer
        },
        MinConfidence: 80
    };

    try {
        const data = await rekognition.detectModerationLabels(params).promise();
        const explicitLabels = ['Explicit Nudity', 'Violence', 'Graphic Male Nudity', 'Graphic Female Nudity'];
        const labelsFound = data.ModerationLabels || [];
        return labelsFound.some(label => explicitLabels.includes(label.Name));
    } catch (error) {
        console.error('Error en detectModerationLabels:', error);
        return false;
    }
}

module.exports = {
    isImageExplicit,
};