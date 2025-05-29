import subprocess
import sys
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

print("Import patients")
subprocess.run([sys.executable, os.path.join(SCRIPT_DIR, "patients-import.py")])

print("Import medications")
subprocess.run([sys.executable, os.path.join(SCRIPT_DIR, "medications-import.py")])

print("Import procedures")
subprocess.run([sys.executable, os.path.join(SCRIPT_DIR, "procedures-import.py")])


print("All data imported successfully.")