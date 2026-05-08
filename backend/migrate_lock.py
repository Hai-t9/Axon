import sqlite3
conn = sqlite3.connect("axon.db")
try:
    conn.execute("ALTER TABLE phase_log ADD COLUMN dataset_locked BOOLEAN DEFAULT 0")
    conn.commit()
    print("Migration successful")
except Exception as e:
    print("Error:", e)
conn.close()
