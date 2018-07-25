require('dotenv').config();
const express = require('express');
const bodyParser = require('body-parser');
const TrueVaultClient = require('truevault');
const app = express();
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('chats.sqlite3');

if (!process.env.TWILIO_ACCOUNT_SID || !process.env.TWILIO_KEY_SID || !process.env.TWILIO_KEY_SECRET || !process.env.TWILIO_FROM_NUMBER) {
    console.error('Configure Twilio parameters as described in README');
    process.exit(-1);
}

// Create DB schema if needed
db.serialize(function () {
    db.run('SELECT * FROM messages', function (error) {
        if (error) {
            db.run('CREATE TABLE messages(createdAt TEXT, fromUserId TEXT, toUserId TEXT, truevaultVaultId TEXT, truevaultDocId TEXT)');
        }
    });
});


app.use(bodyParser.json());

// Install an authentication middleware that validates the TV access token supplied via the Authorization: header
app.use(function (req, res, next) {
    const httpBasic = req.headers.authorization.split(' ')[1];
    const trueVaultClient = new TrueVaultClient({httpBasic});
    trueVaultClient.readCurrentUser().then(function (user) {
        req.user = user;
        req.trueVaultClient = trueVaultClient;
        next();
    }).catch(function (e) {
        console.error(e);
        res.sendStatus(401);
        next();
    });
});

app.get('/chat/:userId/messages', function (req, res) {
    console.log(`Getting messages between ${req.params.userId} and ${req.user.id}`);
    db.all('SELECT createdAt, fromUserId, toUserId, truevaultVaultId, truevaultDocId FROM messages WHERE (fromUserId=$currentUserId AND toUserid=$otherUserId) OR (fromUserId=$otherUserId AND toUserId=$currentUserId) ORDER BY createdAt ASC', {
        $currentUserId: req.user.id,
        $otherUserId: req.params.userId
    }, function (error, rows) {
        if (error) {
            console.error(error);
            res.sendStatus(500);
        } else {
            res.status(200).send({messages: rows});
        }
    });
});

app.post('/chat/:userId/messages', function (req, res) {
    const toUserId = req.params.userId;
    console.log(`Sending message ${req.user.id} -> ${toUserId}`);

    // When storing pointers to TV data, always keep the vault and doc ID. Do this even if you only use a single vault,
    // to avoid a painful migration if you ever need to use multiple vaults.
    db.run('INSERT INTO messages(createdAt, fromUserId, toUserId, truevaultVaultId, truevaultDocId) VALUES($createdAt, $fromUserId, $toUserId, $truevaultVaultId, $truevaultDocId)', {
        $createdAt: new Date().toISOString(),
        $fromUserId: req.user.id,
        $toUserId: toUserId,
        $truevaultVaultId: req.body.truevaultVaultId,
        $truevaultDocId: req.body.truevaultDocId
    }, async function (error) {
        if (error) {
            console.error(error);
            res.sendStatus(500);
        } else {
            try {
                // In a real chat application, the link would go to your server, which would redirect to an iOS
                // deep link.
                const messageBody = `You have a new message: http://example.com/conversation/${toUserId}`;

                await req.trueVaultClient.sendSMSTwilio(
                    process.env.TWILIO_ACCOUNT_SID,
                    process.env.TWILIO_KEY_SID,
                    process.env.TWILIO_KEY_SECRET,
                    toUserId,
                    {literal_value: process.env.TWILIO_FROM_NUMBER},
                    {user_attribute: 'phoneNumber'},
                    messageBody);

                res.sendStatus(201);
            } catch (e) {
                console.error(e);
                res.sendStatus(500);
            }


        }
    });
});


app.listen(process.env.port || 3000, function () {
    console.log('Example app listening on port 3000!')
});
