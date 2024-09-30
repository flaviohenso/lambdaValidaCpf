const { MongoClient } = require('mongodb');

let client;

const connectToDatabase = async () => {
    if (!client) {
        client = new MongoClient(process.env.DOCUMENTDB_URI, {
            useNewUrlParser: true,
            useUnifiedTopology: true,
            ssl: true,
            sslValidate: false,
        });
        await client.connect();
    }
    return client.db(process.env.DB_NAME);
};

exports.lambdaHandler = async (event) => {
    const cpf = event.cpf;

    if (!cpf) {
        return {
            statusCode: 400,
            body: JSON.stringify({ message: 'CPF não fornecido' }),
        };
    }

    try {
        const db = await connectToDatabase();
        const collection = db.collection('usuarios');

        const user = await collection.findOne({ cpf: cpf });

        if (user) {
            return {
                statusCode: 200,
                body: JSON.stringify({ message: 'CPF encontrado', data: user }),
            };
        } else {
            return {
                statusCode: 404,
                body: JSON.stringify({ message: 'CPF não encontrado' }),
            };
        }
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Erro ao conectar ao DocumentDB', error: error.message }),
        };
    }
};

// Exemplo de execução
(async () => {
    const event = { cpf: '12345678900' }; // Substitua pelo CPF que deseja testar
    const result = await exports.lambdaHandler(event);
    console.log(result);
})();