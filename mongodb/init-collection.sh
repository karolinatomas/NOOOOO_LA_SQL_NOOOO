#!/bin/bash
set -euo pipefail

MONGO_USER="admin"
MONGO_PASS="heslo_123"
DB_NAME="medical_records"
COLLECTION_1="patients"
COLLECTION_2="medications"
COLLECTION_3="procedures"

# Shard key as a JS object string (note double quotes inside single quotes)
SHARD_KEY='{ PATIENT_ID: "hashed" }'

echo "Už to snad nebude tak zkurvený..."

echo "Enabling sharding and creating sharded collections..."

docker-compose exec -T router01 mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin <<EOF
const dbName = "$DB_NAME";
const shardKey = { PATIENT_ID: "hashed" };
const collections = ["$COLLECTION_1", "$COLLECTION_2", "$COLLECTION_3"];

sh.enableSharding(dbName);

db = db.getSiblingDB(dbName);

collections.forEach(col => {
  db.createCollection(col);
  db.getCollection(col).createIndex({ PATIENT_ID: 1 });
  sh.shardCollection(\`\${dbName}.\${col}\`, shardKey);
});
EOF

echo "MongoDB cluster is fully initialized and sharded. Ready to use!"