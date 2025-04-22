// routes/securityStandards.js
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Estándares de Seguridad Infantil - GYMswipe</title>
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
          max-width: 800px;
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
          margin: 15px 0;
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
          <h1>Estándares de Seguridad Infantil</h1>
          <p>GYMswipe - Comprometidos con la protección infantil</p>
        </header>
        <main>
          <p>
            Todas las aplicaciones de las categorías Social o Citas deben proporcionar estándares de seguridad publicados e información de contacto para cumplir con nuestra política de estándares de seguridad infantil.
          </p>
          <p>
            En GYMswipe, hemos adoptado los siguientes estándares genéricos para prevenir la explotación y el abuso sexual infantil (EASI):
          </p>
          <h2>Estándares de Seguridad Infantil (EASI)</h2>
          <ol>
            <li>
              <strong>Protección de la Privacidad Infantil:</strong> Se implementan medidas robustas para proteger la privacidad de los usuarios menores, garantizando el cifrado de la información personal y un estricto control de acceso.
            </li>
            <li>
              <strong>Verificación de Edad:</strong> Se requiere una verificación de edad precisa para prevenir el acceso de menores no autorizados a contenidos y funcionalidades inapropiadas.
            </li>
            <li>
              <strong>Sistema de Reporte y Respuesta Inmediata:</strong> Disponemos de mecanismos para reportar y actuar de forma inmediata ante cualquier situación de riesgo, abuso o explotación infantil.
            </li>
            <li>
              <strong>Capacitación y Concienciación:</strong> Nuestro personal recibe formación continua en medidas de protección infantil y en la detección temprana de señales de abuso o riesgo.
            </li>
          </ol>
          <p>
            Si necesitas información adicional o deseas reportar alguna situación, por favor contáctanos a través de <a href="mailto:contact@gymswipe.app">contact@gymswipe.app</a>.
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
