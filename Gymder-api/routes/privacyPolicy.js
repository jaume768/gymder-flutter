// routes/privacyPolicy.js
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Política de Privacidad - GYMswipe</title>
      <style>
        body {
          font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
          margin: 0;
          padding: 0;
          background: #f4f4f4;
          color: #333;
          line-height: 1.6;
        }
        .container {
          max-width: 900px;
          margin: 30px auto;
          background: #fff;
          padding: 20px 30px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        header, footer {
          text-align: center;
          padding: 10px 0;
        }
        header {
          border-bottom: 1px solid #ddd;
          margin-bottom: 20px;
        }
        footer {
          border-top: 1px solid #ddd;
          margin-top: 20px;
          font-size: 14px;
          color: #777;
        }
        h1 {
          color: #2c3e50;
          margin-bottom: 10px;
        }
        h2 {
          color: #34495e;
          margin-top: 20px;
          margin-bottom: 10px;
        }
        p {
          margin: 10px 0;
          text-align: justify;
        }
        ol {
          margin-left: 20px;
          margin-bottom: 20px;
        }
        li {
          margin-bottom: 10px;
          text-align: justify;
        }
        a {
          color: #2980b9;
          text-decoration: none;
        }
        a:hover {
          text-decoration: underline;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>Política de Privacidad de GYMswipe</h1>
        </header>
        <main>
          <h2>1. Introducción</h2>
          <p>
            Bienvenido a GYMswipe. La privacidad de nuestros usuarios es una prioridad. Esta Política de Privacidad explica cómo recopilamos, usamos, compartimos y protegemos tu información. Al utilizar nuestra aplicación, aceptas los términos de esta política.
          </p>
          <h2>2. Información que Recopilamos</h2>
          <p>Recopilamos la siguiente información:</p>
          <ol>
            <li><strong>Datos de Registro:</strong> Nombre, correo electrónico, fecha de nacimiento, género, ubicación aproximada.</li>
            <li><strong>Datos de Perfil:</strong> Fotos, descripción, preferencias, intereses.</li>
            <li><strong>Datos de Uso:</strong> Interacciones con otros usuarios, mensajes enviados y recibidos.</li>
            <li><strong>Datos del Dispositivo:</strong> Tipo de dispositivo, dirección IP, sistema operativo, identificadores únicos.</li>
            <li><strong>Ubicación:</strong> Podemos recopilar y procesar datos de ubicación si otorgas permiso.</li>
          </ol>
          <h2>3. Cómo Usamos Tu Información</h2>
          <p>Utilizamos tu información para:</p>
          <ol>
            <li>Crear y gestionar tu cuenta.</li>
            <li>Conectar usuarios compatibles según sus preferencias.</li>
            <li>Mejorar la seguridad de la aplicación y prevenir fraudes.</li>
            <li>Personalizar la experiencia del usuario.</li>
            <li>Enviar notificaciones sobre la aplicación.</li>
            <li>Cumplir con obligaciones legales.</li>
          </ol>
          <h2>4. Compartición de Información</h2>
          <p>Podemos compartir tu información con:</p>
          <ol>
            <li><strong>Otros Usuarios:</strong> Tu perfil y datos visibles en la aplicación.</li>
            <li><strong>Proveedores de Servicios:</strong> Empresas que nos ayudan a operar la aplicación (alojamiento, análisis de datos, pagos).</li>
            <li><strong>Autoridades Legales:</strong> Si es requerido por ley o para proteger derechos y seguridad.</li>
            <li><strong>Afiliados y Socios:</strong> Para mejorar nuestros servicios y ofrecer promociones relevantes.</li>
          </ol>
          <h2>5. Seguridad de la Información</h2>
          <p>
            Implementamos medidas de seguridad para proteger tu información. Sin embargo, no podemos garantizar una seguridad absoluta. Te recomendamos usar contraseñas seguras y estar atento a posibles fraudes.
          </p>
          <h2>6. Retención de Datos</h2>
          <p>
            Conservamos tu información mientras tu cuenta esté activa. Si eliminas tu cuenta, borraremos tu información, salvo cuando sea necesario conservarla por razones legales.
          </p>
          <h2>7. Tus Derechos</h2>
          <p>
            Dependiendo de tu ubicación, podrías tener los siguientes derechos:
          </p>
          <ol>
            <li>Acceder a tu información personal.</li>
            <li>Solicitar la corrección o eliminación de tus datos.</li>
            <li>Restringir el procesamiento de tu información.</li>
            <li>Oponerte al uso de tus datos para ciertos fines.</li>
            <li>Retirar el consentimiento para el procesamiento de datos.</li>
          </ol>
          <p>
            Para ejercer estos derechos, contáctanos en <a href="mailto:contact@gymswipe.app">contact@gymswipe.app</a>.
          </p>
          <h2>8. Cookies y Tecnologías Similares</h2>
          <p>
            Usamos cookies y tecnologías similares para mejorar la experiencia del usuario, analizar el uso de la aplicación y ofrecer publicidad personalizada.
          </p>
          <h2>9. Menores de Edad</h2>
          <p>
            GYMswipe está destinado a usuarios mayores de 18 años. No recopilamos intencionadamente datos de menores. Si detectamos una cuenta de un menor, la eliminaremos.
          </p>
          <h2>10. Cambios en la Política de Privacidad</h2>
          <p>
            Podemos actualizar esta Política de Privacidad. Notificaremos a los usuarios sobre cambios importantes. El uso continuo de la aplicación después de una actualización implica la aceptación de los nuevos términos.
          </p>
          <h2>11. Contacto</h2>
          <p>
            Si tienes preguntas sobre esta Política de Privacidad, contáctanos en <a href="mailto:contact@gymswipe.app">contact@gymswipe.app</a>.
          </p>
        </main>
        <footer>
          <p>&copy; ${new Date().getFullYear()} GYMswipe. Todos los derechos reservados.</p>
        </footer>
      </div>
    </body>
    </html>
  `);
});

module.exports = router;
