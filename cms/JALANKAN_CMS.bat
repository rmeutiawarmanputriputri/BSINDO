@echo off
REM Klik dua kali untuk menjalankan CMS BISINDO di http://localhost:8080
cd /d "%~dp0"
echo Membuka CMS di http://localhost:8080  (tutup jendela ini untuk berhenti)
start "" http://localhost:8080
where py >nul 2>nul && (py -m http.server 8080 & goto :eof)
where python >nul 2>nul && (python -m http.server 8080 & goto :eof)
where npx >nul 2>nul && (npx --yes serve -l 8080 . & goto :eof)
echo Python atau Node.js belum terpasang. Pasang Python dari https://www.python.org/downloads/ lalu ulangi.
pause
