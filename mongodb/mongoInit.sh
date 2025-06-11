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


# Wait for MongoDB to be ready on router container
wait_for_mongo() {
  local container=$1
  echo "Waiting for MongoDB on $container to be ready..."
  until docker-compose exec -T "$container" mongosh --quiet --eval "db.adminCommand('ping')" &>/dev/null; do
    echo "MongoDB not ready yet, retrying in 3 seconds..."
    sleep 3
  done
  echo "MongoDB on $container is ready!"
}

echo "Starting MongoDB cluster with Docker Compose..."
docker-compose up -d
echo "Waiting for MongoDB containers to start..."
sleep 20

# wait_for_mongo router01

echo "Initializing config servers and shards..."
# run_script configsvr01 /scripts/init-configserver.js
docker compose exec configsvr01 bash  /scripts/init-configserver.js

docker compose exec shard01-a bash /scripts/init-shard01.js
docker compose exec shard02-a bash /scripts/init-shard02.js
docker compose exec shard03-a bash /scripts/init-shard03.js

# run_script shard01-a /scripts/init-shard01.js
# run_script shard02-a /scripts/init-shard02.js
# run_script shard03-a /scripts/init-shard03.js

echo "Waiting for shards to settle..."
sleep 3
wait_for_mongo router01

echo "Initializing router..."
# docker-compose exec -T router01 sh -c mongosh < /scripts/init-router.js
docker-compose exec router01 sh -c "mongosh < /scripts/init-router.js"

sleep 3
echo "Waiting for router to settle..."

echo "Setting up authentication on all nodes..."
# run_script configsvr01 /scripts/auth.js
# run_script shard01-a /scripts/auth.js
# run_script shard02-a /scripts/auth.js
# run_script shard03-a /scripts/auth.js

docker compose exec configsvr01 bash "/scripts/auth.js"
docker compose exec shard01-a bash "/scripts/auth.js"
docker compose exec shard02-a bash "/scripts/auth.js"
docker compose exec shard03-a bash "/scripts/auth.js"


echo "Waiting for authentication to settle..."
sleep 5

docker-compose exec -T router01 mongosh -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin <<EOF
const dbName = "$DB_NAME";
const shardKey = { PATIENT_ID: "hashed" };
const collections = ["$COLLECTION_1", "$COLLECTION_2", "$COLLECTION_3"];

sh.enableSharding(dbName);

db = db.getSiblingDB(dbName);

db = db.getSiblingDB(dbName);
db.createCollection("patients",{
 validator: {
    \$jsonSchema: {
      bsonType: "object",
      required: ["FIRST", "LAST", "BIRTHDATE"],
      properties: {
        PATIENT_ID:{ bsonType:"string"}
        FIRST: { bsonType: "string" },
        LAST: { bsonType: "string" }, 
        BIRTHDATE: {  bsonType: "string" }
      }
    }
  }
})
db.createCollection("medications",{
 validator: {
    \$jsonSchema: {
      bsonType: "object",
      required: ["MEDICATION_START", "MEDICATION_STOP", "PATIENT_ID", "MEDICATION_CODE"],
      properties: {
        MEDICATION_START: { bsonType: "string" },
        MEDICATION_STOP: { bsonType: "string" },
        PATIENT_ID: { bsonType: "string" },
        MEDICATION_CODE: { bsonType: "int" }
      }
    }
  }
})
db.createCollection("procedures",{
 validator: {
    \$jsonSchema: {
      bsonType: "object",
      required: ["DATE", "PATIENT_ID", "PROCEDURE_ID", "CODE", "BASE_COST"],
      properties: {
         DATE: { bsonType: "string" },
        PATIENT_ID: { bsonType: "string" },
        PROCEDURE_ID: { bsonType: "string" },
        CODE: { bsonType: "int" },
        BASE_COST: { bsonType: ["int", "double"] }
      }
    }
  }
})


collections.forEach(col => {
  db.getCollection(col).createIndex({ PATIENT_ID: 1 });
  sh.shardCollection(\`\${dbName}.\${col}\`, shardKey);
});

EOF

python3 "$(dirname "$0")/scripts/data-import/import-all.py"
echo "MongoDB has data and is ready to use!"