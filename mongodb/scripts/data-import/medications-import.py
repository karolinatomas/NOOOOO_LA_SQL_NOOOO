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
    print("Připojeno jako:", status["authInfo"]["authenticatedUsers"])
except Exception as e:
    print("Chyba při ověřování připojení:", e)
    exit(1)


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", ".."))
CSV_PATH = os.path.join(PROJECT_ROOT, "data", "medications.csv")
df = pd.read_csv(CSV_PATH)
print(db)
print(CSV_PATH)

print("stará data budou smazány")
db.medications.delete_many({})
print("Stará data odstraněna.")

batch_size = 10000
total = len(df)
print(f"Importuji {len(df)} ")

docs = df.to_dict(orient="records")
errors_count = 0
error_log = []

try:
    db.medications.insert_many(docs, ordered=False)
    print(f"Vloženo {len(docs)} záznamů.")
except errors.BulkWriteError as bwe:
    write_errors = bwe.details.get("writeErrors", [])
    errors_count = len(write_errors)
    for err in write_errors:
        error_doc = err.get("op", {})
        error_log.append((error_doc))
    print(f"Některé záznamy se nepodařilo vložit: {errors_count} chyb.")

# Zápis chyb
if errors_count > 0:
    error_dir = os.path.join(SCRIPT_DIR, "import_errors")
    os.makedirs(error_dir, exist_ok=True)
    error_file = os.path.join(error_dir, "medications_errors.json")
    with open(error_file, "w", encoding="utf-8") as f:
        json.dump(error_log, f, ensure_ascii=False, indent=2)
    print(f"Chybové záznamy uloženy do {error_file}")

# Shrnutí
print(f"Import hotov: {db.medications.count_documents({})} záznamů v kolekci.")