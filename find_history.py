import os
import glob

history_path = os.path.expandvars(r"%APPDATA%\Code\User\History")
found_login = []
found_admin = []

if os.path.exists(history_path):
    print("Scanning VS Code history...")
    for root, dirs, files in os.walk(history_path):
        for file in files:
            if file == "entries.json":
                continue
            
            file_path = os.path.join(root, file)
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    
                    if "_syncDeviceWithPin" in content and "BackendApiService.registerWorker" in content:
                        mtime = os.path.getmtime(file_path)
                        found_login.append((mtime, file_path, content))
                        
                    if "_DeviceSyncTab" in content and "generateSyncToken" in content:
                        mtime = os.path.getmtime(file_path)
                        found_admin.append((mtime, file_path, content))
            except Exception:
                pass

    if found_login:
        found_login.sort(key=lambda x: x[0], reverse=True)
        best = found_login[0]
        print("Found login_screen.dart match: " + best[1])
        with open(r"app\lib\presentation\screens\login_screen.dart", "w", encoding="utf-8") as f:
            f.write(best[2])
        print("Restored login_screen.dart")

    if found_admin:
        found_admin.sort(key=lambda x: x[0], reverse=True)
        best = found_admin[0]
        print("Found admin_dashboard.dart match: " + best[1])
        with open(r"app\lib\presentation\screens\admin_dashboard.dart", "w", encoding="utf-8") as f:
            f.write(best[2])
        print("Restored admin_dashboard.dart")
else:
    print("VS Code history path not found.")
