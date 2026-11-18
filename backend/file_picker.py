#!/usr/bin/python3
"""Keep toolkit file dialogs outside the desktop shell process."""
import json
import sys
from PySide6.QtWidgets import QApplication, QFileDialog
from PySide6.QtGui import QPalette, QColor

app = QApplication(sys.argv[:1])
app.setApplicationName('Tor file picker')
app.setDesktopFileName('org.omarchy.tor-file-picker')
app.setStyle('Fusion')
palette = QPalette()
for role, color in ((QPalette.Window,'#171c1b'),(QPalette.WindowText,'#e0e8e4'),
                    (QPalette.Base,'#101513'),(QPalette.AlternateBase,'#202925'),
                    (QPalette.Text,'#e0e8e4'),(QPalette.Button,'#27332e'),
                    (QPalette.ButtonText,'#e0e8e4'),(QPalette.Highlight,'#427e66'),
                    (QPalette.HighlightedText,'#ffffff')):
    palette.setColor(role,QColor(color))
app.setPalette(palette)
if '--folder' in sys.argv:
    folder = QFileDialog.getExistingDirectory(None, 'Choose a website folder containing index.html',
        options=QFileDialog.DontUseNativeDialog)
    print(json.dumps({'folder': folder}))
else:
    files, _ = QFileDialog.getOpenFileNames(None,'Select files to start sharing through Tor',
        options=QFileDialog.DontUseNativeDialog)
    print(json.dumps({'files':files}))
