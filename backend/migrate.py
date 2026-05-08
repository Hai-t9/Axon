import sqlite3
import os

db_path = r'C:\Users\MICROSOFT\PycharmProjects\Axon\backend\axon.db'
if not os.path.exists(db_path):
    print('DB not found')
    exit(1)

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Check if model_id is unique
cur.execute('PRAGMA foreign_keys=off;')

cur.execute('''
CREATE TABLE IF NOT EXISTS evaluation_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_id INTEGER NOT NULL,
    score FLOAT,
    metrics_json VARCHAR,
    status VARCHAR NOT NULL DEFAULT 'pending',
    evaluated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(model_id) REFERENCES model(id)
)
''')

# Copy data
cur.execute('''
INSERT INTO evaluation_new (id, model_id, score, metrics_json, status, evaluated_at)
SELECT id, model_id, score, metrics_json, status, evaluated_at FROM evaluation
''')

cur.execute('DROP TABLE evaluation')
cur.execute('ALTER TABLE evaluation_new RENAME TO evaluation')

conn.commit()
conn.close()
print('Migration complete')
