chcp 65001

::powershell -ExecutionPolicy Bypass -File "D:\tmp\install-pandoc\pandoc\scripts\md2pdf.ps1" -InputPath "D:\tmp\install-pandoc\input\FaceAiKey流程圖-251124-v1.19.5.md" -Output "D:\tmp\install-pandoc\output\FaceAiKey流程圖-251124-v1.19.5-9.pdf"

SET INPUT_ROOT_PATH=%~dp0..\ai-assets\create-pdf\input
SET OUTPUT_ROOT_PATH=%~dp0..\ai-assets\create-pdf\output

SET SRC_FILE="%INPUT_ROOT_PATH%\FaceAiKey流程圖-251124-v1.20.9.md"
SET DST_FILE="%OUTPUT_ROOT_PATH%\FaceAiKey流程圖-251124-v1.20.9-md2pdf-html-test.pdf"

::原本的方案 但表格這邊畫線不好，寬度有問題
::powershell -ExecutionPolicy Bypass -File "D:\tmp\install-pandoc\pandoc\scripts\md2pdf.ps1" -InputPath %SRC_FILE% -Output %DST_FILE%

::  --theme [<anyAvailableTheme>] (recommended to use the default PDF theme)

::mmcli markdowntopdf  -i %SRC_FILE% -o %DST_FILE% -open --orientation Portrait --page-size A4 --show-print-headers false

SET BROWSER_PATH="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

powershell -ExecutionPolicy Bypass -File "..\pandoc\scripts\md2pdf-html.ps1" -InputPath %SRC_FILE% -Output %DST_FILE% -BrowserPath %BROWSER_PATH%

pause
