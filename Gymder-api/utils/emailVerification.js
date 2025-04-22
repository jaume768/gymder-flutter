const axios = require('axios');

async function sendVerificationEmail(email, code) {
    const BREVO_API_KEY = process.env.BREVO_API_KEY;
    const url = 'https://api.brevo.com/v3/smtp/email';

    const data = {
        sender: { email: 'gymswipe.official@gmail.com' },
        to: [{ email }],
        subject: 'Verifica tu correo en Gymder',
        htmlContent: `<p>Tu código de verificación es: <strong>${code}</strong></p>`
    };

    try {
        const response = await axios.post(url, data, {
            headers: {
                'api-key': BREVO_API_KEY,
                'Content-Type': 'application/json'
            }
        });
        return response.data;
    } catch (error) {
        console.error('Error al enviar email de verificación:', error.response?.data || error.message);
        throw error;
    }
}

module.exports = {
    sendVerificationEmail
};