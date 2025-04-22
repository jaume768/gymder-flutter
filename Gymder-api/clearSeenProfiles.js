const { MongoClient } = require('mongodb');

const url = "mongodb://mongo:EsfhhFWMieJnTmWJNJGtfCqxuDgXAicL@autorack.proxy.rlwy.net:48480";

const dbName = "test";

async function clearSeenProfiles() {
    const client = new MongoClient(url, { useNewUrlParser: true, useUnifiedTopology: true });

    try {
        await client.connect();
        console.log("Conectado a la base de datos");

        const db = client.db(dbName);
        // Se asume que la colección se llama "users"
        const usersCollection = db.collection("users");

        // Actualiza todos los documentos para vaciar el campo seenProfiles
        const result = await usersCollection.updateMany({}, { $set: { seenProfiles: [] } });

        console.log(`Se han limpiado los seenProfiles de ${result.modifiedCount} usuarios.`);
    } catch (error) {
        console.error("Error al limpiar seenProfiles:", error);
    } finally {
        await client.close();
        console.log("Conexión cerrada");
    }
}

clearSeenProfiles();
