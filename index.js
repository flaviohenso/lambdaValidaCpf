const MongoClient = require('mongodb').MongoClient;

const uri = process.env.DOCUMENTDB_URI;

let cachedDb = null;

const connectToDatabase = async () => {
    if (cachedDb) {
        console.log("Usando conexão existente.");
        return cachedDb;
    }

    console.log("Criando nova conexão.");
    const client = await MongoClient.connect(uri, {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        tlsAllowInvalidCertificates: true // Amazon DocumentDB requer essa opção.
    });

    const db = client.db('fiap');
    cachedDb = db;
    return db;
};

exports.handler = async (event) => {
    try {
        let cpf;

        try {
            const body = JSON.parse(event.body);
            cpf = body.cpf;
            console.log("CPF recebido:", cpf);
        } catch (error) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'Corpo da requisição inválido' }),
            };
        }

        if (!cpf) {
            return {
                statusCode: 400,
                body: JSON.stringify({ message: 'CPF não fornecido' }),
            };
        }

        const db = await connectToDatabase();
        const collection = db.collection('clientes');

        console.log('Buscando CPF');
        const user = await collection.findOne({ cpf: cpf });

        if (user) {
            console.log("CPF encontrado:", user);
            return {
                statusCode: 200,
                body: JSON.stringify({ message: 'CPF encontrado', data: user }),
            };
        } else {
            console.log("CPF não encontrado");
            return {
                statusCode: 404,
                body: JSON.stringify({ message: 'CPF não encontrado' }),
            };
        }
    } catch (error) {
        console.error("Erro ao conectar ao DocumentDB:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: "Erro ao conectar ao DocumentDB",
                error: error.message,
            }),
        };
    }
};