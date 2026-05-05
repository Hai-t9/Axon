import glob

for f in glob.glob('C:/Users/MICROSOFT/PycharmProjects/Axon/backend/app/**/*.py', recursive=True):
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    if 'backend.app.' in content:
        content = content.replace('backend.app.', 'app.')
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"Fixed {f}")

