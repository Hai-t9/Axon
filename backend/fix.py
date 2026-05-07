import sqlite3
c = sqlite3.connect('axon.db')
c.execute("UPDATE role SET role = 'host'")
c.commit()
print('Upgraded to host')
