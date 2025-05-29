import pandas as pd
from pymongo import MongoClient, errors
import json
import os

client = MongoClient(
    "mongodb://admin:heslo_123@127.0.0.1:27117,127.0.0.1:27118/?authMechanism=DEFAULT&directConnection=false"
)
db = client["medical_records"]

try:
    status = client.admin.command("connectionStatus")
    print("Connected as:", status["authInfo"]["authenticatedUsers"])
except Exception as e:
    print("Error during authentication:", e)
    exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", ".."))
CSV_PATH = os.path.join(PROJECT_ROOT, "data", "procedures.csv")
df = pd.read_csv(CSV_PATH)

print(db)
print(CSV_PATH)

print("Old data will be deleted")
db.procedures.delete_many({})
print("Old data was successfully deleted.")

batch_size = 10000
total = len(df)
print(f"Will be imported {len(df)} records")

docs = df.to_dict(orient="records")
errors_count = 0
error_log = []

try:
    db.procedures.insert_many(docs, ordered=False)
    print(f"Imported {len(docs)} records.")
except errors.BulkWriteError as bwe:
    write_errors = bwe.details.get("writeErrors", [])
    errors_count = len(write_errors)
    for err in write_errors:
        error_doc = err.get("op", {})
        error_log.append(error_doc)
    print(f"Some data cannot be added: {errors_count} error(s).")

# Write error log
if errors_count > 0:
    error_dir = os.path.join(SCRIPT_DIR, "import_errors")
    os.makedirs(error_dir, exist_ok=True)
    error_file = os.path.join(error_dir, "procedures_errors.json")
    with open(error_file, "w", encoding="utf-8") as f:
        json.dump(error_log, f, ensure_ascii=False, indent=2)
    print(f"Wrong data added to {error_file}")

# Summary
print(f"Import is completed with {db.procedures.count_documents({})} records in collection")