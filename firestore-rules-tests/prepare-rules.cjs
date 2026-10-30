const fs = require('node:fs');
const path = require('node:path');

const source = path.resolve(__dirname, '..', 'FIRESTORE_RULES_PROPOSED.txt');
const destination = path.join(__dirname, 'firestore.rules');
fs.copyFileSync(source, destination);
console.log(`Loaded proposed rules from ${source}`);
