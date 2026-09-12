# Prüfbericht – LAS Customer 0.3.0

Dokumentiert am 12. September 2026. Backend-Tests: 10. September; ergänzte Dart-Tests: 12. September.

## Bestanden

- iOS-/Android-Projektdateien mit Flutter 3.47.2 erzeugt; Abhängigkeiten in pubspec.lock festgehalten.
- Dart-Codeanalyse nach der Erweiterung: No issues found.
- 19 direkte Dart-Navigationsprüfungen bestanden, einschließlich Signaturlinks. Die vier ursprünglichen Flutter-Testgruppen bestanden unter 0.1.0; eine ergänzte fünfte Gruppe liegt im Quellcode. Deren neue Fälle wurden direkt mit Dart geprüft.
- 17 zusätzliche direkte Dart-Prüfungen für die Backend-Rückmeldung bestanden: bestätigter Erfolg, fehlender Login, Serverfehler, fremde/manipulierte Antworten, Zeitüberschreitungen, parallele Anfragen, Seitenwechsel und Freigabe belegter Ressourcen. Die Prüfungen sind auch als weitere Flutter-Testgruppe eingebunden.
- Erfolg bei der Aktivierung setzt eine Backend-Antwort mit Status 204 voraus. Die Deaktivierung meldet nur Erfolg, wenn die Token-Löschung beim Firebase-SDK erfolgreich zurückkehrt. Diese SDK-Operation ist noch nicht auf einem echten Gerät getestet.
- Zwölf Backend-Integrationstests gegen eine separate lokale PostgreSQL-18-Testdatenbank und FastAPI bestanden. Die gepatchten Original-Kundenrouten wurden ausgeführt; Mitarbeiter-Testberechtigung und Firebase-Versand waren ersetzt.
- Fotozugriff nach Kunde/Auftrag/Veröffentlichung, Pfadgrenzen, Dateitypen, Freigabeberechtigung, Escaping und unveränderte Rechnungsanzeige geprüft.
- Push nach Inaktivitätsablauf, Widerruf bei Logout/Passwortänderung/Deaktivierung/Ablauf, Kontowechsel und verspätete Anmeldung nach Logout geprüft.
- Geänderte Backend-Python-Dateien syntaktisch geprüft. Ausgangsdateien durch SHA-256 im Integrationspaket dokumentiert.

## Noch nicht geprüft

Zusätzlich vorbereitet: manueller Cloud-Mac-Workflow. Seine YAML-Datei wurde gelesen und zwölf Konfigurationsprüfungen bestanden. Der Ablauf selbst und das macOS-Skript wurden mangels Mac-/GitHub-Zugang noch nicht ausgeführt.

Die neue schreibgeschützte Integrationsprüfung besteht sieben Tests. Beim vorhandenen lokalen DMS-Quellstand stimmen alle fünf Ausgangsdateien überein; die zwei neuen Module fehlen dort erwartungsgemäß. Ergebnis: READY_FOR_REVIEW. Der laufende Server wurde dabei nicht geprüft.

Kein nativer iOS-/Android-Build, keine Geräte-/Simulator- oder visuellen Paritätstests. Kein echter Zahlungs-/UAE-PASS-Ablauf oder APNs-/FCM-Versand. Die produktiv deployte Portal-Version ist nicht verifiziert. Der Backend-Patch wurde nicht installiert.

Die App ist ein Entwicklungsstand, keine App-Store-Freigabe. Mac-Buildzugang, Apple-Developer-Einrichtung, Firebase/APNs, endgültige App-Symbole und native Domain-Zuordnungen bleiben erforderlich.
