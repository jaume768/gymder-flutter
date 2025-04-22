// routes/accountDeletion.js
const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Eliminación de Cuenta - GymSwipe</title>
      <style>
        body { 
          font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; 
          margin: 0; 
          padding: 0; 
          background: #f7f7f7; 
          color: #333; 
          line-height: 1.6;
        }
        .container { 
          max-width: 800px; 
          margin: 30px auto; 
          background: #fff; 
          padding: 20px; 
          box-shadow: 0 2px 8px rgba(0,0,0,0.1); 
        }
        header, footer { 
          text-align: center; 
          padding: 10px 0; 
        }
        header { 
          border-bottom: 1px solid #ddd; 
        }
        footer { 
          border-top: 1px solid #ddd; 
          margin-top: 20px; 
        }
        h1 { 
          margin-bottom: 10px; 
          font-size: 24px; 
          color: #2c3e50; 
        }
        h2 { 
          font-size: 20px; 
          color: #34495e; 
        }
        p { 
          margin: 15px 0; 
        }
        ol { 
          margin-left: 20px; 
        }
        li { 
          margin-bottom: 10px; 
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
          <h1>Eliminación de Cuenta</h1>
          <p>GymSwipe - Desarrollado por Jaume Fernández Suñer</p>
        </header>
        <main>
          <p>Para solicitar la eliminación de tu cuenta y de los datos asociados, tienes dos opciones:</p>
          <ol>
            <li>
              <strong>Desde la aplicación:</strong> 
              Accede a la sección de <em>Configuración</em> y selecciona <em>"Eliminar Cuenta"</em>. Sigue las instrucciones en pantalla para completar el proceso.
            </li>
            <li>
              <strong>Por correo electrónico:</strong> 
              Envía un correo a <a href="mailto:gymswipe.official@gmail.com">gymswipe.official@gmail.com</a> indicando que deseas eliminar tu cuenta. Asegúrate de incluir tu nombre de usuario y la dirección de correo electrónico registrada en la aplicación.
            </li>
          </ol>
          <h2>Datos eliminados y conservados</h2>
          <p>
            Se eliminarán los siguientes datos: información de perfil, datos de uso, historial de mensajes y otros datos asociados.
          </p>
          <p>
            Algunos datos podrán conservarse durante periodos adicionales para cumplir con obligaciones legales.
          </p>
        </main>
        <footer>
          <p>Para más información, contáctanos en <a href="mailto:gymswipe.official@gmail.com">gymswipe.official@gmail.com</a></p>
        </footer>
      </div>
    </body>
    </html>
  `);
});

module.exports = router;
