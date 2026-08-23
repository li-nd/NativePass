#!/usr/bin/env python3
"""Add it, ko, nl, pl, uk to NativePass string catalogs."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALIZABLE = ROOT / "NativePass/Localizable.xcstrings"
INFOPLIST = ROOT / "NativePass/InfoPlist.xcstrings"
PBXPROJ = ROOT / "NativePass.xcodeproj/project.pbxproj"

NEW_LANGS = ("it", "ko", "nl", "pl", "uk")

# en -> (it, ko, nl, pl, uk)
T: dict[str, tuple[str, str, str, str, str]] = {
    "%@ not found": ("%@ non trovato", "%@ 없음", "%@ niet gevonden", "Nie znaleziono %@", "%@ не знайдено"),
    "%@ was not found on this system.": ("%@ non è stato trovato su questo sistema.", "이 시스템에서 %@을(를) 찾을 수 없습니다.", "%@ is niet gevonden op dit systeem.", "Nie znaleziono %@ w tym systemie.", "%@ не знайдено в цій системі."),
    "%@: missing %@": ("%@: manca %@", "%@: %@ 없음", "%@: %@ ontbreekt", "%@: brak %@", "%@: відсутній %@"),
    "%lld changed": ("%lld modificati", "%lld개 변경됨", "%lld gewijzigd", "%lld zmienione", "%lld змінено"),
    "%lld commit(s) to pull": ("%lld commit da scaricare", "받을 커밋 %lld개", "%lld commit(s) om te pullen", "%lld commit(ów) do pobrania", "%lld коміт(ів) для pull"),
    "%lld commit(s) to push": ("%lld commit da inviare", "보낼 커밋 %lld개", "%lld commit(s) om te pushen", "%lld commit(ów) do wysłania", "%lld коміт(ів) для push"),
    "%lld file(s)": ("%lld file", "파일 %lld개", "%lld bestand(en)", "%lld plik(ów)", "%lld файл(ів)"),
    "%lld Items": ("%lld elementi", "%lld개 항목", "%lld items", "%lld elementów", "%lld елементів"),
    "%lld minutes": ("%lld minuti", "%lld분", "%lld minuten", "%lld min", "%lld хв"),
    "1 Item": ("1 elemento", "항목 1개", "1 item", "1 element", "1 елемент"),
    "About %@": ("Informazioni su %@", "%@ 정보", "Over %@", "O programie %@", "Про %@"),
    "Actions": ("Azioni", "동작", "Acties", "Akcje", "Дії"),
    "Active": ("Attivo", "활성", "Actief", "Aktywny", "Активний"),
    "active": ("attivo", "활성", "actief", "aktywny", "активний"),
    "active v%@": ("attivo v%@", "활성 v%@", "actief v%@", "aktywny v%@", "активний v%@"),
    "Add Field": ("Aggiungi campo", "필드 추가", "Veld toevoegen", "Dodaj pole", "Додати поле"),
    "Add pinentry to GPG agent config": ("Aggiungi pinentry alla config dell'agente GPG", "GPG 에이전트 설정에 pinentry 추가", "pinentry toevoegen aan GPG-agentconfig", "Dodaj pinentry do konfiguracji agenta GPG", "Додати pinentry до конфігурації GPG agent"),
    "After unlocking, press Try Again below.": ("Dopo lo sblocco, premi Riprova qui sotto.", "잠금 해제 후 아래의 다시 시도를 누르세요.", "Druk na het ontgrendelen hieronder op Opnieuw.", "Po odblokowaniu naciśnij Ponów poniżej.", "Після розблокування натисніть «Повторити» нижче."),
    "Ahead": ("Avanti", "앞섬", "Vooruit", "Do przodu", "Попереду"),
    "All": ("Tutti", "전체", "Alles", "Wszystkie", "Усі"),
    "App Lock": ("Blocco app", "앱 잠금", "App-vergrendeling", "Blokada aplikacji", "Блокування програми"),
    "Append this line to ~/.gnupg/gpg-agent.conf": ("Aggiungi questa riga a ~/.gnupg/gpg-agent.conf", "~/.gnupg/gpg-agent.conf에 이 줄을 추가하세요", "Voeg deze regel toe aan ~/.gnupg/gpg-agent.conf", "Dodaj tę linię do ~/.gnupg/gpg-agent.conf", "Додайте цей рядок до ~/.gnupg/gpg-agent.conf"),
    "Apply Store Path": ("Applica percorso", "경로 적용", "Pad toepassen", "Zastosuj ścieżkę", "Застосувати шлях"),
    "Authentication failed.": ("Autenticazione non riuscita.", "인증에 실패했습니다.", "Authenticatie mislukt.", "Uwierzytelnianie nie powiodło się.", "Помилка автентифікації."),
    "Authentication failed. App Lock was not turned off.": ("Autenticazione non riuscita. Il blocco app non è stato disattivato.", "인증에 실패했습니다. 앱 잠금이 해제되지 않았습니다.", "Authenticatie mislukt. App-vergrendeling is niet uitgeschakeld.", "Uwierzytelnianie nie powiodło się. Blokada aplikacji nie została wyłączona.", "Помилка автентифікації. Блокування програми не вимкнено."),
    "Authentication failed. Lock timeout was not changed.": ("Autenticazione non riuscita. Il timeout di blocco non è stato modificato.", "인증에 실패했습니다. 잠금 시간이 변경되지 않았습니다.", "Authenticatie mislukt. Vergrendeltime-out is niet gewijzigd.", "Uwierzytelnianie nie powiodło się. Czas blokady nie został zmieniony.", "Помилка автентифікації. Тайм-аут блокування не змінено."),
    "Authentication Required": ("Autenticazione richiesta", "인증 필요", "Authenticatie vereist", "Wymagane uwierzytelnianie", "Потрібна автентифікація"),
    "Auto-hide revealed password after %llds": ("Nascondi automaticamente la password dopo %lld s", "표시된 비밀번호를 %lld초 후 자동 숨김", "Onthuld wachtwoord na %lld s verbergen", "Ukryj ujawnione hasło po %lld s", "Приховувати показаний пароль через %lld с"),
    "Behind": ("Dietro", "뒤처짐", "Achter", "Do tyłu", "Позаду"),
    "Binary": ("Binario", "바이너리", "Binary", "Plik binarny", "Двійковий файл"),
    "Branch": ("Branch", "브랜치", "Branch", "Gałąź", "Гілка"),
    "Cancel": ("Annulla", "취소", "Annuleren", "Anuluj", "Скасувати"),
    "Capabilities: %@": ("Funzionalità: %@", "기능: %@", "Mogelijkheden: %@", "Możliwości: %@", "Можливості: %@"),
    "Change App Lock settings": ("Modifica impostazioni blocco app", "앱 잠금 설정 변경", "App-vergrendelingsinstellingen wijzigen", "Zmień ustawienia blokady aplikacji", "Змінити налаштування блокування"),
    "Changed files": ("File modificati", "변경된 파일", "Gewijzigde bestanden", "Zmienione pliki", "Змінені файли"),
    "Changes": ("Modifiche", "변경 사항", "Wijzigingen", "Zmiany", "Зміни"),
    "Check Again": ("Controlla di nuovo", "다시 확인", "Opnieuw controleren", "Sprawdź ponownie", "Перевірити знову"),
    "Check available secret keys": ("Controlla le chiavi segrete disponibili", "사용 가능한 비밀 키 확인", "Beschikbare geheime sleutels controleren", "Sprawdź dostępne klucze tajne", "Перевірити доступні секретні ключі"),
    "Check ~/.password-store/.gpg-id for the expected recipient.": ("Controlla ~/.password-store/.gpg-id per il destinatario previsto.", "예상 수신자는 ~/.password-store/.gpg-id를 확인하세요.", "Controleer ~/.password-store/.gpg-id voor de verwachte ontvanger.", "Sprawdź ~/.password-store/.gpg-id pod kątem oczekiwanego odbiorcy.", "Перевірте ~/.password-store/.gpg-id для очікуваного отримувача."),
    "Checking plugins…": ("Controllo plugin…", "플러그인 확인 중…", "Plugins controleren…", "Sprawdzanie wtyczek…", "Перевірка плагінів…"),
    "Clean": ("Pulito", "깨끗함", "Schoon", "Czyste", "Чисто"),
    "Clear after %llds": ("Cancella dopo %lld s", "%lld초 후 지우기", "Wissen na %lld s", "Wyczyść po %lld s", "Очищати через %lld с"),
    "Clipboard": ("Appunti", "클립보드", "Klembord", "Schowek", "Буфер обміну"),
    "Close": ("Chiudi", "닫기", "Sluiten", "Zamknij", "Закрити"),
    "Code": ("Codice", "코드", "Code", "Kod", "Код"),
    "Command timed out: %@": ("Comando scaduto: %@", "명령 시간 초과: %@", "Time-out van opdracht: %@", "Przekroczono limit czasu polecenia: %@", "Час очікування команди вичерпано: %@"),
    "Configure pinentry-mac for in-app prompts": ("Configura pinentry-mac per i prompt nell'app", "앱 내 프롬프트용 pinentry-mac 구성", "pinentry-mac configureren voor in-app-prompts", "Skonfiguruj pinentry-mac do monitu w aplikacji", "Налаштувати pinentry-mac для запитів у програмі"),
    "Configured": ("Configurato", "구성됨", "Geconfigureerd", "Skonfigurowano", "Налаштовано"),
    "Copied": ("Copiato", "복사됨", "Gekopieerd", "Skopiowano", "Скопійовано"),
    "Copied.": ("Copiato.", "복사됨.", "Gekopieerd.", "Skopiowano.", "Скопійовано."),
    "Copied. Clears in %llds.": ("Copiato. Cancella tra %lld s.", "복사됨. %lld초 후 지워집니다.", "Gekopieerd. Wordt over %lld s gewist.", "Skopiowano. Wyczyszczenie za %lld s.", "Скопійовано. Очищення через %lld с."),
    "Copies to clipboard": ("Copia negli appunti", "클립보드에 복사", "Kopieert naar klembord", "Kopiuje do schowka", "Копіює до буфера обміну"),
    "Copy": ("Copia", "복사", "Kopieer", "Kopiuj", "Копіювати"),
    "Copy Command": ("Copia comando", "명령 복사", "Opdracht kopiëren", "Kopiuj polecenie", "Копіювати команду"),
    "Copy Password": ("Copia password", "비밀번호 복사", "Wachtwoord kopiëren", "Kopiuj hasło", "Копіювати пароль"),
    "Copy Report": ("Copia report", "보고서 복사", "Rapport kopiëren", "Kopiuj raport", "Копіювати звіт"),
    "Copyright © %lld Markus Lind": ("Copyright © %lld Markus Lind", "Copyright © %lld Markus Lind", "Copyright © %lld Markus Lind", "Copyright © %lld Markus Lind", "Copyright © %lld Markus Lind"),
    "Could Not Decrypt Entry": ("Impossibile decifrare la voce", "항목을 복호화할 수 없음", "Kan item niet ontsleutelen", "Nie można odszyfrować wpisu", "Не вдалося розшифрувати запис"),
    "Could not detect GPG version": ("Impossibile rilevare la versione GPG", "GPG 버전을 감지할 수 없음", "Kon GPG-versie niet detecteren", "Nie można wykryć wersji GPG", "Не вдалося визначити версію GPG"),
    "Could not list entries via pass: %@": ("Impossibile elencare le voci via pass: %@", "pass로 항목을 나열할 수 없음: %@", "Kon items niet via pass tonen: %@", "Nie można wyświetlić wpisów przez pass: %@", "Не вдалося отримати список через pass: %@"),
    "Could not load git status.": ("Impossibile caricare lo stato Git.", "Git 상태를 불러올 수 없습니다.", "Kon Git-status niet laden.", "Nie można wczytać statusu Git.", "Не вдалося завантажити статус Git."),
    "Could not read pass version: %@": ("Impossibile leggere la versione di pass: %@", "pass 버전을 읽을 수 없음: %@", "Kon pass-versie niet lezen: %@", "Nie można odczytać wersji pass: %@", "Не вдалося прочитати версію pass: %@"),
    "Create a new entry with ⌘N or run pass insert in Terminal.": ("Crea una voce con ⌘N oppure esegui pass insert nel Terminale.", "⌘N으로 새 항목을 만들거나 Terminal에서 pass insert를 실행하세요.", "Maak een item met ⌘N of voer pass insert uit in Terminal.", "Utwórz wpis za pomocą ⌘N lub uruchom pass insert w Terminalu.", "Створіть запис через ⌘N або виконайте pass insert у Terminal."),
    "Created by %@": ("Creato da %@", "작성자: %@", "Gemaakt door %@", "Autor: %@", "Автор: %@"),
    "Created by Markus Lind": ("Creato da Markus Lind", "작성자: Markus Lind", "Gemaakt door Markus Lind", "Autor: Markus Lind", "Автор: Markus Lind"),
    "Decrypting…": ("Decifratura…", "복호화 중…", "Ontsleutelen…", "Odszyfrowywanie…", "Розшифрування…"),
    "Decryption succeeded for %@": ("Decifratura riuscita per %@", "%@ 복호화 성공", "Ontsleuteling geslaagd voor %@", "Odszyfrowanie powiodło się dla %@", "Розшифрування успішне для %@"),
    "Default: ~/.password-store": ("Predefinito: ~/.password-store", "기본값: ~/.password-store", "Standaard: ~/.password-store", "Domyślnie: ~/.password-store", "Типово: ~/.password-store"),
    "Degraded": ("Degradato", "제한됨", "Beperkt", "Ograniczony", "З обмеженнями"),
    "degraded %@(%@)": ("degradato %@(%@)", "제한됨 %@(%@)", "beperkt %@(%@)", "ograniczony %@(%@)", "з обмеженнями %@(%@)"),
    "Delete": ("Elimina", "삭제", "Verwijderen", "Usuń", "Видалити"),
    "Delete \"%@\"?": ("Eliminare «%@»?", "«%@»을(를) 삭제할까요?", "„%@” verwijderen?", "Usunąć „%@”?", "Видалити «%@»?"),
    "Details: %@": ("Dettagli: %@", "세부정보: %@", "Details: %@", "Szczegóły: %@", "Подробиці: %@"),
    "Diagnostics": ("Diagnostica", "진단", "Diagnose", "Diagnostyka", "Діагностика"),
    "Dirty": ("Con modifiche", "변경 있음", "Met wijzigingen", "Ze zmianami", "Є зміни"),
    "Edit": ("Modifica", "편집", "Wijzigen", "Edytuj", "Змінити"),
    "Enter your GPG passphrase when prompted, then try again in NativePass.": ("Inserisci la passphrase GPG quando richiesto, poi riprova in NativePass.", "GPG 패스프레이즈를 입력한 다음 NativePass에서 다시 시도하세요.", "Voer je GPG-passphrase in wanneer gevraagd en probeer opnieuw in NativePass.", "Wprowadź passphrase GPG, gdy zostaniesz o to poproszony, a następnie spróbuj ponownie w NativePass.", "Введіть passphrase GPG за запитом, потім повторіть у NativePass."),
    "Enter your passphrase when prompted.": ("Inserisci la passphrase quando richiesto.", "요청되면 패스프레이즈를 입력하세요.", "Voer je passphrase in wanneer gevraagd.", "Wprowadź passphrase, gdy zostaniesz o to poproszony.", "Введіть passphrase за запитом."),
    "Entries": ("Voci", "항목", "Items", "Wpisy", "Записи"),
    "Entries with OTP secrets appear here after you view them.": ("Le voci con segreti OTP compaiono qui dopo averle visualizzate.", "OTP 시크릿이 있는 항목은 확인 후 여기에 표시됩니다.", "Items met OTP-geheimen verschijnen hier nadat je ze bekijkt.", "Wpisy z sekretami OTP pojawią się tutaj po ich wyświetleniu.", "Записи з OTP-секретами з’являться тут після перегляду."),
    "Entry": ("Voce", "항목", "Item", "Wpis", "Запис"),
    "Environment": ("Ambiente", "환경", "Omgeving", "Środowisko", "Оточення"),
    "Error": ("Errore", "오류", "Fout", "Błąd", "Помилка"),
    "Expected recipient: %@": ("Destinatario previsto: %@", "예상 수신자: %@", "Verwachte ontvanger: %@", "Oczekiwany odbiorca: %@", "Очікуваний отримувач: %@"),
    "Extension command failed.": ("Comando estensione non riuscito.", "확장 명령이 실패했습니다.", "Extensieopdracht mislukt.", "Polecenie rozszerzenia nie powiodło się.", "Команда розширення не виконана."),
    "failed to generate secure random bytes": ("generazione di byte casuali sicuri non riuscita", "보안 난수 바이트 생성 실패", "kon geen veilige willekeurige bytes genereren", "nie udało się wygenerować bezpiecznych bajtów losowych", "не вдалося згенерувати криптостійкі випадкові байти"),
    "Failed to parse pass output: %@": ("Analisi dell'output di pass non riuscita: %@", "pass 출력을 구문 분석하지 못함: %@", "Kon pass-uitvoer niet parseren: %@", "Nie udało się przeanalizować wyjścia pass: %@", "Не вдалося розібрати вивід pass: %@"),
    "Focus Search": ("Focus ricerca", "검색에 포커스", "Zoeken focussen", "Skupienie na wyszukiwaniu", "Фокус на пошук"),
    "Found": ("Trovato", "찾음", "Gevonden", "Znaleziono", "Знайдено"),
    "found": ("trovato", "찾음", "gevonden", "znaleziono", "знайдено"),
    "General": ("Generali", "일반", "Algemeen", "Ogólne", "Основні"),
    "Generate Password…": ("Genera password…", "비밀번호 생성…", "Wachtwoord genereren…", "Generuj hasło…", "Згенерувати пароль…"),
    "Generated length: %lld": ("Lunghezza generata: %lld", "생성 길이: %lld", "Gegenereerde lengte: %lld", "Długość generowania: %lld", "Довжина генерації: %lld"),
    "Generated: %@": ("Generato: %@", "생성: %@", "Gegenereerd: %@", "Wygenerowano: %@", "Створено: %@"),
    "Git": ("Git", "Git", "Git", "Git", "Git"),
    "Git repository: %@": ("Repository Git: %@", "Git 저장소: %@", "Git-repository: %@", "Repozytorium Git: %@", "Git-репозиторій: %@"),
    "Git Status": ("Stato Git", "Git 상태", "Git-status", "Status Git", "Статус Git"),
    "Git status unavailable.": ("Stato Git non disponibile.", "Git 상태를 사용할 수 없습니다.", "Git-status niet beschikbaar.", "Status Git niedostępny.", "Статус Git недоступний."),
    "Git Sync": ("Sync Git", "Git 동기화", "Git-sync", "Synchronizacja Git", "Синхронізація Git"),
    "Global hotkey: ⌥⌘P": ("Scorciatoia globale: ⌥⌘P", "전역 단축키: ⌥⌘P", "Globale sneltoets: ⌥⌘P", "Globalny skrót: ⌥⌘P", "Глобальна гаряча клавіша: ⌥⌘P"),
    "GPG": ("GPG", "GPG", "GPG", "GPG", "GPG"),
    "GPG Agent Unavailable": ("Agente GPG non disponibile", "GPG 에이전트 사용 불가", "GPG-agent niet beschikbaar", "Agent GPG niedostępny", "GPG agent недоступний"),
    "GPG could not decrypt this entry. Try the steps below or open Diagnostics for more details.": ("GPG non è riuscito a decifrare questa voce. Prova i passaggi sotto o apri Diagnostica.", "GPG가 이 항목을 복호화하지 못했습니다. 아래 단계를 시도하거나 진단을 여세요.", "GPG kon dit item niet ontsleutelen. Volg de stappen of open Diagnose.", "GPG nie mógł odszyfrować tego wpisu. Spróbuj poniższych kroków lub otwórz Diagnostykę.", "GPG не зміг розшифрувати цей запис. Виконайте кроки нижче або відкрийте Діагностику."),
    "GPG did not receive a passphrase. Try again when you're ready to unlock your key.": ("GPG non ha ricevuto una passphrase. Riprova quando sei pronto a sbloccare la chiave.", "GPG가 패스프레이즈를 받지 못했습니다. 키를 잠금 해제할 준비가 되면 다시 시도하세요.", "GPG heeft geen passphrase ontvangen. Probeer opnieuw wanneer je de sleutel wilt ontgrendelen.", "GPG nie otrzymał passphrase. Spróbuj ponownie, gdy będziesz gotowy odblokować klucz.", "GPG не отримав passphrase. Повторіть, коли будете готові розблокувати ключ."),
    "GPG IDs: %@": ("ID GPG: %@", "GPG ID: %@", "GPG-ID's: %@", "ID GPG: %@", "GPG ID: %@"),
    "GPG Key Needs to Be Unlocked": ("La chiave GPG deve essere sbloccata", "GPG 키 잠금 해제가 필요합니다", "GPG-sleutel moet worden ontgrendeld", "Klucz GPG musi zostać odblokowany", "Потрібно розблокувати GPG-ключ"),
    "GPG Touch ID": ("GPG Touch ID", "GPG Touch ID", "GPG Touch ID", "GPG Touch ID", "GPG Touch ID"),
    "GPG version: %@": ("Versione GPG: %@", "GPG 버전: %@", "GPG-versie: %@", "Wersja GPG: %@", "Версія GPG: %@"),
    "Hide Password": ("Nascondi password", "비밀번호 숨기기", "Wachtwoord verbergen", "Ukryj hasło", "Приховати пароль"),
    "Import": ("Importa", "가져오기", "Importeren", "Import", "Імпорт"),
    "Import your private key": ("Importa la chiave privata", "개인 키 가져오기", "Privésleutel importeren", "Zaimportuj klucz prywatny", "Імпортувати закритий ключ"),
    "Inactive": ("Inattivo", "비활성", "Inactief", "Nieaktywny", "Неактивний"),
    "inactive (%@)": ("inattivo (%@)", "비활성 (%@)", "inactief (%@)", "nieaktywny (%@)", "неактивний (%@)"),
    "Initialized": ("Inizializzato", "초기화됨", "Geïnitialiseerd", "Zainicjalizowano", "Ініціалізовано"),
    "Install pass via Homebrew: brew install pass": ("Installa pass tramite Homebrew: brew install pass", "Homebrew로 pass 설치: brew install pass", "Installeer pass via Homebrew: brew install pass", "Zainstaluj pass przez Homebrew: brew install pass", "Встановіть pass через Homebrew: brew install pass"),
    "Install pass-otp to add or change verification codes.": ("Installa pass-otp per aggiungere o modificare i codici.", "확인 코드를 추가하거나 변경하려면 pass-otp를 설치하세요.", "Installeer pass-otp om verificatiecodes toe te voegen of te wijzigen.", "Zainstaluj pass-otp, aby dodawać lub zmieniać kody weryfikacyjne.", "Встановіть pass-otp, щоб додавати або змінювати коди підтвердження."),
    "Install pinentry-mac": ("Installa pinentry-mac", "pinentry-mac 설치", "pinentry-mac installeren", "Zainstaluj pinentry-mac", "Встановити pinentry-mac"),
    "Install pinentry-mac and set pinentry-program in ~/.gnupg/gpg-agent.conf for Touch ID with GPG.": ("Installa pinentry-mac e imposta pinentry-program in ~/.gnupg/gpg-agent.conf per Touch ID con GPG.", "GPG에서 Touch ID를 사용하려면 pinentry-mac을 설치하고 ~/.gnupg/gpg-agent.conf에 pinentry-program을 설정하세요.", "Installeer pinentry-mac en stel pinentry-program in ~/.gnupg/gpg-agent.conf in voor Touch ID met GPG.", "Zainstaluj pinentry-mac i ustaw pinentry-program w ~/.gnupg/gpg-agent.conf dla Touch ID z GPG.", "Встановіть pinentry-mac і вкажіть pinentry-program у ~/.gnupg/gpg-agent.conf для Touch ID з GPG."),
    "Installed": ("Installato", "설치됨", "Geïnstalleerd", "Zainstalowano", "Встановлено"),
    "installed": ("installato", "설치됨", "geïnstalleerd", "zainstalowano", "встановлено"),
    "Key": ("Chiave", "키", "Sleutel", "Klucz", "Ключ"),
    "Last synced %@": ("Ultima sync %@", "최근 동기화 %@", "Laatst gesynchroniseerd %@", "Ostatnia sync %@", "Остання синхронізація %@"),
    "List secret keys": ("Elenca chiavi segrete", "비밀 키 목록", "Geheime sleutels tonen", "Lista kluczy tajnych", "Список секретних ключів"),
    "Loading OTP…": ("Caricamento OTP…", "OTP 로드 중…", "OTP laden…", "Ładowanie OTP…", "Завантаження OTP…"),
    "Loading status…": ("Caricamento stato…", "상태 로드 중…", "Status laden…", "Ładowanie statusu…", "Завантаження статусу…"),
    "Local": ("Locale", "로컬", "Lokaal", "Lokalne", "Локальний"),
    "Location": ("Posizione", "위치", "Locatie", "Lokalizacja", "Розташування"),
    "Lock after": ("Blocca dopo", "잠금 시간", "Vergrendelen na", "Zablokuj po", "Блокувати через"),
    "Lock Now": ("Blocca ora", "지금 잠금", "Nu vergrendelen", "Zablokuj teraz", "Заблокувати"),
    "Name": ("Nome", "이름", "Naam", "Nazwa", "Ім’я"),
    "NativePass": ("NativePass", "NativePass", "NativePass", "NativePass", "NativePass"),
    "NativePass Diagnostic Report": ("Report diagnostico NativePass", "NativePass 진단 보고서", "NativePass-diagnoserapport", "Raport diagnostyczny NativePass", "Діагностичний звіт NativePass"),
    "NativePass does not integrate with this extension yet.": ("NativePass non integra ancora questa estensione.", "NativePass는 아직 이 확장과 통합되지 않았습니다.", "NativePass integreert deze extensie nog niet.", "NativePass nie integruje jeszcze tego rozszerzenia.", "NativePass ще не інтегрований із цим розширенням."),
    "NativePass is Locked": ("NativePass è bloccato", "NativePass가 잠김", "NativePass is vergrendeld", "NativePass jest zablokowany", "NativePass заблоковано"),
    "NativePass is locked.": ("NativePass è bloccato.", "NativePass가 잠겼습니다.", "NativePass is vergrendeld.", "NativePass jest zablokowany.", "NativePass заблоковано."),
    "NativePass runs GPG in the background and cannot show a terminal password prompt. Install pinentry-mac so GPG can ask for your passphrase in a macOS dialog.": ("NativePass esegue GPG in background e non può mostrare un prompt del terminale. Installa pinentry-mac per una finestra di dialogo macOS.", "NativePass는 백그라운드에서 GPG를 실행하므로 터미널 암호 프롬프트를 표시할 수 없습니다. pinentry-mac을 설치하세요.", "NativePass voert GPG op de achtergrond uit en kan geen terminalwachtwoordprompt tonen. Installeer pinentry-mac voor een macOS-dialoog.", "NativePass uruchamia GPG w tle i nie może pokazać monitu terminala. Zainstaluj pinentry-mac, aby GPG mógł zapytać o passphrase w oknie macOS.", "NativePass запускає GPG у фоні і не може показати термінальний запит пароля. Встановіть pinentry-mac, щоб GPG міг запитати passphrase у діалозі macOS."),
    "New Entry": ("Nuova voce", "새 항목", "Nieuw item", "Nowy wpis", "Новий запис"),
    "New Entry (⌘N)": ("Nuova voce (⌘N)", "새 항목 (⌘N)", "Nieuw item (⌘N)", "Nowy wpis (⌘N)", "Новий запис (⌘N)"),
    "No": ("No", "아니요", "Nee", "Nie", "Ні"),
    "No Diagnostic Data": ("Nessun dato diagnostico", "진단 데이터 없음", "Geen diagnosegegevens", "Brak danych diagnostycznych", "Немає даних діагностики"),
    "No entries in \"%@\".": ("Nessuna voce in «%@».", "«%@»에 항목이 없습니다.", "Geen items in „%@”.", "Brak wpisów w „%@”.", "Немає записів у «%@»."),
    "No Entry Selected": ("Nessuna voce selezionata", "선택한 항목 없음", "Geen item geselecteerd", "Nie wybrano wpisu", "Запис не вибрано"),
    "No pass extensions found.": ("Nessuna estensione pass trovata.", "pass 확장을 찾을 수 없습니다.", "Geen pass-extensies gevonden.", "Nie znaleziono rozszerzeń pass.", "Розширення pass не знайдено."),
    "No Passwords": ("Nessuna password", "비밀번호 없음", "Geen wachtwoorden", "Brak haseł", "Немає паролів"),
    "No Results": ("Nessun risultato", "결과 없음", "Geen resultaten", "Brak wyników", "Нічого не знайдено"),
    "No upstream configured.": ("Nessun upstream configurato.", "upstream이 구성되지 않았습니다.", "Geen upstream geconfigureerd.", "Nie skonfigurowano upstream.", "Upstream не налаштовано."),
    "No Verification Codes": ("Nessun codice di verifica", "확인 코드 없음", "Geen verificatiecodes", "Brak kodów weryfikacyjnych", "Немає кодів підтвердження"),
    "Not found": ("Non trovato", "없음", "Niet gevonden", "Nie znaleziono", "Не знайдено"),
    "not found": ("non trovato", "없음", "niet gevonden", "nie znaleziono", "не знайдено"),
    "Note": ("Nota", "메모", "Notitie", "Notatka", "Нотатка"),
    "OK": ("OK", "확인", "OK", "OK", "OK"),
    "Open": ("Apri", "열기", "Openen", "Otwórz", "Відкрити"),
    "Open in Browser": ("Apri nel browser", "브라우저에서 열기", "Openen in browser", "Otwórz w przeglądarce", "Відкрити в браузері"),
    "Open in NativePass": ("Apri in NativePass", "NativePass에서 열기", "Openen in NativePass", "Otwórz w NativePass", "Відкрити в NativePass"),
    "Open NativePass": ("Apri NativePass", "NativePass 열기", "NativePass openen", "Otwórz NativePass", "Відкрити NativePass"),
    "Open Store in Finder": ("Apri store nel Finder", "Finder에서 스토어 열기", "Store openen in Finder", "Otwórz magazyn w Finderze", "Відкрити сховище у Finder"),
    "Pass": ("Pass", "Pass", "Pass", "Pass", "Pass"),
    "pass binary not found": ("binario pass non trovato", "pass 바이너리 없음", "pass-binary niet gevonden", "nie znaleziono pliku binarnego pass", "двійковий файл pass не знайдено"),
    "Pass command failed.": ("Comando pass non riuscito.", "pass 명령이 실패했습니다.", "Pass-opdracht mislukt.", "Polecenie pass nie powiodło się.", "Команда pass не виконана."),
    "pass not found": ("pass non trovato", "pass 없음", "pass niet gevonden", "nie znaleziono pass", "pass не знайдено"),
    "pass-import is available. Full import wizard is not implemented yet.": ("pass-import è disponibile. La procedura guidata di importazione completa non è ancora implementata.", "pass-import를 사용할 수 있습니다. 전체 가져오기 마법사는 아직 구현되지 않았습니다.", "pass-import is beschikbaar. Een volledige importwizard is nog niet geïmplementeerd.", "pass-import jest dostępny. Pełny kreator importu nie jest jeszcze zaimplementowany.", "pass-import доступний. Повний майстер імпорту ще не реалізовано."),
    "Pass: %@": ("Pass: %@", "Pass: %@", "Pass: %@", "Pass: %@", "Pass: %@"),
    "Passphrase Entry Cancelled": ("Inserimento passphrase annullato", "패스프레이즈 입력 취소됨", "Passphrase-invoer geannuleerd", "Anulowano wprowadzanie passphrase", "Ввід passphrase скасовано"),
    "Password": ("Password", "비밀번호", "Wachtwoord", "Hasło", "Пароль"),
    "password charset is empty": ("set di caratteri password vuoto", "비밀번호 문자 집합이 비어 있음", "wachtwoordtekenset is leeg", "zestaw znaków hasła jest pusty", "набір символів пароля порожній"),
    "password length must be greater than zero": ("la lunghezza della password deve essere maggiore di zero", "비밀번호 길이는 0보다 커야 합니다", "wachtwoordlengte moet groter dan nul zijn", "długość hasła musi być większa od zera", "довжина пароля має бути більшою за нуль"),
    "Password Prompt Not Configured": ("Prompt password non configurato", "비밀번호 프롬프트가 구성되지 않음", "Wachtwoordprompt niet geconfigureerd", "Monit hasła nie jest skonfigurowany", "Запит пароля не налаштовано"),
    "Password Store": ("Store password", "비밀번호 스토어", "Wachtwoordstore", "Magazyn haseł", "Сховище паролів"),
    "Password store is not initialized": ("Lo store password non è inizializzato", "비밀번호 스토어가 초기화되지 않음", "Wachtwoordstore is niet geïnitialiseerd", "Magazyn haseł nie jest zainicjalizowany", "сховище паролів не ініціалізовано"),
    "Password store is not initialized. Run `pass init` first.": ("Lo store non è inizializzato. Esegui prima `pass init`.", "스토어가 초기화되지 않았습니다. 먼저 `pass init`을 실행하세요.", "Store is niet geïnitialiseerd. Voer eerst `pass init` uit.", "Magazyn nie jest zainicjalizowany. Najpierw uruchom `pass init`.", "Сховище паролів не ініціалізовано. Спочатку виконайте `pass init`."),
    "Password store not initialized": ("Store password non inizializzato", "비밀번호 스토어 미초기화", "Wachtwoordstore niet geïnitialiseerd", "Magazyn haseł niezainicjalizowany", "Сховище паролів не ініціалізовано"),
    "Passwords": ("Password", "비밀번호", "Wachtwoorden", "Hasła", "Паролі"),
    "Path": ("Percorso", "경로", "Pad", "Ścieżka", "Шлях"),
    "Pinentry": ("Pinentry", "Pinentry", "Pinentry", "Pinentry", "Pinentry"),
    "pinentry-program not configured in gpg-agent.conf": ("pinentry-program non configurato in gpg-agent.conf", "gpg-agent.conf에 pinentry-program이 구성되지 않음", "pinentry-program niet geconfigureerd in gpg-agent.conf", "pinentry-program nie jest skonfigurowany w gpg-agent.conf", "pinentry-program не налаштовано в gpg-agent.conf"),
    "Plugins": ("Plugin", "플러그인", "Plugins", "Wtyczki", "Плагіни"),
    "Plugins (%lld):": ("Plugin (%lld):", "플러그인 (%lld):", "Plugins (%lld):", "Wtyczki (%lld):", "Плагіни (%lld):"),
    "Preparing workspace…": ("Preparazione area di lavoro…", "작업 공간 준비 중…", "Werkruimte voorbereiden…", "Przygotowywanie obszaru roboczego…", "Підготовка робочої області…"),
    "Private Key Not Found": ("Chiave privata non trovata", "개인 키를 찾을 수 없음", "Privésleutel niet gevonden", "Nie znaleziono klucza prywatnego", "Закритий ключ не знайдено"),
    "Pull": ("Pull", "Pull", "Pull", "Pull", "Pull"),
    "Pull completed.": ("Pull completato.", "Pull 완료.", "Pull voltooid.", "Pull ukończony.", "Pull виконано."),
    "Push": ("Push", "Push", "Push", "Push", "Push"),
    "Push completed.": ("Push completato.", "Push 완료.", "Push voltooid.", "Push ukończony.", "Push виконано."),
    "Quick Access": ("Accesso rapido", "빠른 접근", "Snelle toegang", "Szybki dostęp", "Швидкий доступ"),
    "Quit": ("Esci", "종료", "Stop", "Zakończ", "Вийти"),
    "Re-run Checks": ("Riesegui controlli", "검사 다시 실행", "Controles opnieuw uitvoeren", "Ponów sprawdzenia", "Повторити перевірки"),
    "Ready": ("Pronto", "준비됨", "Gereed", "Gotowe", "Готово"),
    "Recipient IDs": ("ID destinatari", "수신자 ID", "Ontvanger-ID's", "ID odbiorców", "ID отримувачів"),
    "Refresh": ("Aggiorna", "새로고침", "Vernieuwen", "Odśwież", "Оновити"),
    "Refresh Git Status": ("Aggiorna stato Git", "Git 상태 새로고침", "Git-status vernieuwen", "Odśwież status Git", "Оновити статус Git"),
    "Refresh Status": ("Aggiorna stato", "상태 새로고침", "Status vernieuwen", "Odśwież status", "Оновити статус"),
    "Refreshes in %llds": ("Aggiornamento tra %lld s", "%lld초 후 갱신", "Vernieuwt over %lld s", "Odświeżenie za %lld s", "Оновиться через %lld с"),
    "Remote": ("Remoto", "원격", "Remote", "Zdalne", "Віддалений"),
    "Replace the path with your exported secret key file.": ("Sostituisci il percorso con il file della chiave segreta esportata.", "내보낸 비밀 키 파일 경로로 바꾸세요.", "Vervang het pad door je geëxporteerde geheime-sleutelbestand.", "Zastąp ścieżkę wyeksportowanym plikiem klucza tajnego.", "Замініть шлях на файл експортованого секретного ключа."),
    "Require authentication": ("Richiedi autenticazione", "인증 필요", "Authenticatie vereisen", "Wymagaj uwierzytelniania", "Вимагати автентифікацію"),
    "Restart the GPG agent": ("Riavvia l'agente GPG", "GPG 에이전트 다시 시작", "GPG-agent herstarten", "Uruchom ponownie agenta GPG", "Перезапустити GPG agent"),
    "Retry": ("Riprova", "다시 시도", "Opnieuw", "Ponów", "Повторити"),
    "Reveal": ("Rivela", "표시", "Tonen", "Ujawnij", "Показ"),
    "Reveal Password": ("Mostra password", "비밀번호 표시", "Wachtwoord tonen", "Pokaż hasło", "Показати пароль"),
    "Run a system check to inspect pass and plugins.": ("Esegui un controllo di sistema per ispezionare pass e i plugin.", "pass와 플러그인을 검사하려면 시스템 점검을 실행하세요.", "Voer een systeemcontrole uit om pass en plugins te inspecteren.", "Uruchom sprawdzenie systemu, aby zbadać pass i wtyczki.", "Запустіть перевірку системи, щоб оглянути pass і плагіни."),
    "Run Diagnostics": ("Esegui diagnostica", "진단 실행", "Diagnose uitvoeren", "Uruchom diagnostykę", "Запустити діагностику"),
    "Run in Terminal: pass init your-gpg-id": ("Nel Terminale: pass init your-gpg-id", "Terminal에서 실행: pass init your-gpg-id", "In Terminal: pass init your-gpg-id", "W Terminalu: pass init your-gpg-id", "У Terminal: pass init your-gpg-id"),
    "Save": ("Salva", "저장", "Bewaren", "Zapisz", "Зберегти"),
    "Scanning password store…": ("Scansione dello store…", "비밀번호 스토어 스캔 중…", "Wachtwoordstore scannen…", "Skanowanie magazynu haseł…", "Сканування сховища…"),
    "Search": ("Cerca", "검색", "Zoeken", "Szukaj", "Пошук"),
    "Search entries…": ("Cerca voci…", "항목 검색…", "Items zoeken…", "Szukaj wpisów…", "Пошук записів…"),
    "Security": ("Sicurezza", "보안", "Beveiliging", "Bezpieczeństwo", "Безпека"),
    "Select a password entry to view details.": ("Seleziona una voce per visualizzare i dettagli.", "세부정보를 보려면 항목을 선택하세요.", "Selecteer een item om details te bekijken.", "Wybierz wpis, aby zobaczyć szczegóły.", "Виберіть запис, щоб переглянути деталі."),
    "Select a password from the list.": ("Seleziona una password dall'elenco.", "목록에서 비밀번호를 선택하세요.", "Selecteer een wachtwoord uit de lijst.", "Wybierz hasło z listy.", "Виберіть пароль зі списку."),
    "Select an entry to copy its password.": ("Seleziona una voce per copiarne la password.", "비밀번호를 복사할 항목을 선택하세요.", "Selecteer een item om het wachtwoord te kopiëren.", "Wybierz wpis, aby skopiować hasło.", "Виберіть запис, щоб скопіювати пароль."),
    "Set Up Code…": ("Configura codice…", "코드 설정…", "Code instellen…", "Skonfiguruj kod…", "Налаштувати код…"),
    "Settings": ("Impostazioni", "설정", "Instellingen", "Ustawienia", "Налаштування"),
    "Settings…": ("Impostazioni…", "설정…", "Instellingen…", "Ustawienia…", "Налаштування…"),
    "Setup Required": ("Configurazione richiesta", "설정 필요", "Installatie vereist", "Wymagana konfiguracja", "Потрібне налаштування"),
    "Show pass import --help": ("Mostra pass import --help", "pass import --help 표시", "pass import --help tonen", "Pokaż pass import --help", "Показати pass import --help"),
    "Sort": ("Ordina", "정렬", "Sorteren", "Sortuj", "Сортування"),
    "Sort By": ("Ordina per", "정렬 기준", "Sorteren op", "Sortuj według", "Сортувати за"),
    "Starting NativePass…": ("Avvio di NativePass…", "NativePass 시작 중…", "NativePass starten…", "Uruchamianie NativePass…", "Запуск NativePass…"),
    "Status": ("Stato", "상태", "Status", "Status", "Статус"),
    "Steps": ("Passaggi", "단계", "Stappen", "Kroki", "Кроки"),
    "Store": ("Store", "스토어", "Store", "Magazyn", "Сховище"),
    "Store initialized: %@": ("Store inizializzato: %@", "스토어 초기화: %@", "Store geïnitialiseerd: %@", "Magazyn zainicjalizowany: %@", "Сховище ініціалізовано: %@"),
    "Store path": ("Percorso store", "스토어 경로", "Storepad", "Ścieżka magazynu", "Шлях до сховища"),
    "Store recipient IDs": ("ID destinatari dello store", "스토어 수신자 ID", "Ontvanger-ID's van store", "ID odbiorców magazynu", "ID отримувачів сховища"),
    "Sync": ("Sync", "동기화", "Sync", "Synchronizacja", "Синхронізація"),
    "Test Decrypt": ("Prova decifratura", "복호화 테스트", "Ontsleuteling testen", "Test odszyfrowania", "Тест розшифрування"),
    "Test decryption in Terminal": ("Prova la decifratura nel Terminale", "Terminal에서 복호화 테스트", "Ontsleuteling in Terminal testen", "Przetestuj odszyfrowanie w Terminalu", "Перевірити розшифрування в Terminal"),
    "Test in Terminal": ("Prova nel Terminale", "Terminal에서 테스트", "Testen in Terminal", "Przetestuj w Terminalu", "Перевірити в Terminal"),
    "The GPG agent is not running or cannot be reached. Restart it and try again.": ("L'agente GPG non è in esecuzione o non è raggiungibile. Riavvialo e riprova.", "GPG 에이전트가 실행 중이 아니거나 연결할 수 없습니다. 다시 시작한 후 재시도하세요.", "De GPG-agent draait niet of is niet bereikbaar. Start opnieuw en probeer opnieuw.", "Agent GPG nie działa lub jest niedostępny. Uruchom go ponownie i spróbuj jeszcze raz.", "GPG agent не запущено або недоступний. Перезапустіть його та повторіть спробу."),
    "This password store is encrypted for a GPG key that is not available on this Mac. Import the matching private key or use the machine where the key already exists.": ("Questo store è cifrato per una chiave GPG non disponibile su questo Mac. Importa la chiave privata corrispondente.", "이 스토어는 이 Mac에 없는 GPG 키로 암호화되어 있습니다. 일치하는 개인 키를 가져오세요.", "Deze store is versleuteld voor een GPG-sleutel die niet op deze Mac beschikbaar is. Importeer de bijbehorende privésleutel.", "Ten magazyn jest zaszyfrowany kluczem GPG niedostępnym na tym Macu. Zaimportuj pasujący klucz prywatny.", "Це сховище зашифроване для GPG-ключа, якого немає на цьому Mac. Імпортуйте відповідний закритий ключ."),
    "This will permanently remove the entry from your password store.": ("Questo rimuoverà definitivamente la voce dallo store password.", "항목이 비밀번호 스토어에서 영구적으로 제거됩니다.", "Dit verwijdert het item permanent uit je wachtwoordstore.", "To trwale usunie wpis z magazynu haseł.", "Запис буде остаточно видалено зі сховища паролів."),
    "To use Touch ID when decrypting passwords, install pinentry-mac and add to ~/.gnupg/gpg-agent.conf:": ("Per usare Touch ID durante la decifratura, installa pinentry-mac e aggiungi a ~/.gnupg/gpg-agent.conf:", "복호화 시 Touch ID를 사용하려면 pinentry-mac을 설치하고 ~/.gnupg/gpg-agent.conf에 추가하세요:", "Om Touch ID te gebruiken bij ontsleutelen, installeer pinentry-mac en voeg toe aan ~/.gnupg/gpg-agent.conf:", "Aby używać Touch ID podczas odszyfrowywania, zainstaluj pinentry-mac i dodaj do ~/.gnupg/gpg-agent.conf:", "Щоб використовувати Touch ID під час розшифрування, встановіть pinentry-mac і додайте до ~/.gnupg/gpg-agent.conf:"),
    "Try a different search term.": ("Prova un altro termine di ricerca.", "다른 검색어를 시도하세요.", "Probeer een andere zoekterm.", "Spróbuj innego hasła wyszukiwania.", "Спробуйте інший пошуковий запит."),
    "Try Again": ("Riprova", "다시 시도", "Opnieuw", "Ponów", "Повторити"),
    "Try again in NativePass": ("Riprova in NativePass", "NativePass에서 다시 시도", "Opnieuw proberen in NativePass", "Spróbuj ponownie w NativePass", "Повторити в NativePass"),
    "Turn off App Lock": ("Disattiva blocco app", "앱 잠금 끄기", "App-vergrendeling uitschakelen", "Wyłącz blokadę aplikacji", "Вимкнути блокування програми"),
    "Unlock": ("Sblocca", "잠금 해제", "Ontgrendelen", "Odblokuj", "Розблокувати"),
    "Unlock in Terminal": ("Sblocca nel Terminale", "Terminal에서 잠금 해제", "Ontgrendelen in Terminal", "Odblokuj w Terminalu", "Розблокувати в Terminal"),
    "Unlock NativePass": ("Sblocca NativePass", "NativePass 잠금 해제", "NativePass ontgrendelen", "Odblokuj NativePass", "Розблокувати NativePass"),
    "Unlock NativePass to change settings.": ("Sblocca NativePass per modificare le impostazioni.", "설정을 변경하려면 NativePass를 잠금 해제하세요.", "Ontgrendel NativePass om instellingen te wijzigen.", "Odblokuj NativePass, aby zmienić ustawienia.", "Розблокуйте NativePass, щоб змінити налаштування."),
    "Unlock your GPG key in Terminal": ("Sblocca la chiave GPG nel Terminale", "Terminal에서 GPG 키 잠금 해제", "GPG-sleutel ontgrendelen in Terminal", "Odblokuj klucz GPG w Terminalu", "Розблокувати GPG-ключ у Terminal"),
    "Unlock your key in Terminal": ("Sblocca la chiave nel Terminale", "Terminal에서 키 잠금 해제", "Sleutel ontgrendelen in Terminal", "Odblokuj klucz w Terminalu", "Розблокувати ключ у Terminal"),
    "Up to date": ("Aggiornato", "최신 상태", "Up-to-date", "Aktualne", "Актуально"),
    "Use the sync button in the main toolbar for Pull and Push.": ("Usa il pulsante Sync nella barra degli strumenti per Pull e Push.", "Pull과 Push에는 메인 도구 모음의 Sync 버튼을 사용하세요.", "Gebruik de Sync-knop in de werkbalk voor Pull en Push.", "Użyj przycisku Sync na pasku narzędzi do Pull i Push.", "Для Pull і Push використовуйте кнопку синхронізації на панелі інструментів."),
    "Uses Touch ID or device password to unlock the app UI. GPG decryption still uses pinentry-mac.": ("Usa Touch ID o la password del dispositivo per sbloccare l'UI. La decifratura GPG usa ancora pinentry-mac.", "앱 UI 잠금 해제에 Touch ID 또는 기기 암호를 사용합니다. GPG 복호화는 계속 pinentry-mac을 사용합니다.", "Gebruikt Touch ID of het apparaatwachtwoord om de UI te ontgrendelen. GPG-ontsleuteling gebruikt nog steeds pinentry-mac.", "Używa Touch ID lub hasła urządzenia do odblokowania UI. Odszyfrowanie GPG nadal używa pinentry-mac.", "Для розблокування інтерфейсу використовуються Touch ID або пароль пристрою. Розшифрування GPG і далі через pinentry-mac."),
    "Value": ("Valore", "값", "Waarde", "Wartość", "Значення"),
    "Verification Code": ("Codice di verifica", "확인 코드", "Verificatiecode", "Kod weryfikacyjny", "Код підтвердження"),
    "Verification Codes": ("Codici di verifica", "확인 코드", "Verificatiecodes", "Kody weryfikacyjne", "Коди підтвердження"),
    "Version": ("Versione", "버전", "Versie", "Wersja", "Версія"),
    "Waiting for authentication…": ("In attesa di autenticazione…", "인증 대기 중…", "Wachten op authenticatie…", "Oczekiwanie na uwierzytelnianie…", "Очікування автентифікації…"),
    "Warnings": ("Avvisi", "경고", "Waarschuwingen", "Ostrzeżenia", "Попередження"),
    "Warnings:": ("Avvisi:", "경고:", "Waarschuwingen:", "Ostrzeżenia:", "Попередження:"),
    "Without this, NativePass cannot show a passphrase dialog.": ("Senza questo, NativePass non può mostrare una finestra di passphrase.", "이것이 없으면 NativePass는 패스프레이즈 대화상자를 표시할 수 없습니다.", "Zonder dit kan NativePass geen passphrase-dialoog tonen.", "Bez tego NativePass nie może pokazać okna passphrase.", "Без цього NativePass не зможе показати діалог passphrase."),
    "Working tree": ("Working tree", "작업 트리", "Working tree", "Drzewo robocze", "Робоче дерево"),
    "Yes": ("Sì", "예", "Ja", "Tak", "Так"),
    "Your private key is present but locked. Unlock it once in Terminal, or configure pinentry-mac so NativePass can prompt for your passphrase.": ("La chiave privata è presente ma bloccata. Sbloccala nel Terminale o configura pinentry-mac.", "개인 키는 있지만 잠겨 있습니다. Terminal에서 잠금 해제하거나 pinentry-mac을 구성하세요.", "Je privésleutel is aanwezig maar vergrendeld. Ontgrendel hem in Terminal of configureer pinentry-mac.", "Klucz prywatny jest obecny, ale zablokowany. Odblokuj go w Terminalu lub skonfiguruj pinentry-mac.", "Закритий ключ є, але він заблокований. Розблокуйте його один раз у Terminal або налаштуйте pinentry-mac."),
    "↵ copy password · ⌘O open": ("↵ copia password · ⌘O apri", "↵ 비밀번호 복사 · ⌘O 열기", "↵ wachtwoord kopiëren · ⌘O openen", "↵ kopiuj hasło · ⌘O otwórz", "↵ копіювати пароль · ⌘O відкрити"),

}

def unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def merge_catalog(path: Path) -> list[str]:
    catalog = json.loads(path.read_text(encoding="utf-8"))
    missing: list[str] = []

    for key, entry in catalog["strings"].items():
        locs = entry.setdefault("localizations", {})
        en_value = locs.get("en", {}).get("stringUnit", {}).get("value", key)

        if key not in T:
            missing.append(key)
            translations = (en_value,) * 5
        else:
            translations = T[key]

        for lang, value in zip(NEW_LANGS, translations):
            locs[lang] = unit(value)

    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return missing


def merge_infoplist() -> None:
    catalog = json.loads(INFOPLIST.read_text(encoding="utf-8"))
    locs = catalog["strings"]["NSFaceIDUsageDescription"]["localizations"]
    locs["it"] = unit("NativePass usa Touch ID per sbloccare l'app.")
    locs["ko"] = unit("NativePass는 Touch ID를 사용하여 앱 잠금을 해제합니다.")
    locs["nl"] = unit("NativePass gebruikt Touch ID om de app te ontgrendelen.")
    locs["pl"] = unit("NativePass używa Touch ID do odblokowania aplikacji.")
    locs["uk"] = unit("NativePass використовує Touch ID для розблокування програми.")
    INFOPLIST.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_pbxproj() -> None:
    text = PBXPROJ.read_text(encoding="utf-8")
    # Ensure each language is listed once in knownRegions
    if "\t\t\t\tit,\n" not in text and "\t\t\t\tit,\r\n" not in text:
        # insert after fr,
        needle = "\t\t\t\tfr,\n"
        if needle in text:
            insert = needle + "".join(f"\t\t\t\t{lang},\n" for lang in NEW_LANGS)
            text = text.replace(needle, insert, 1)
        else:
            # fallback: before closing of knownRegions
            text = text.replace(
                "\t\t\t\tfr,\n\t\t\t);",
                "\t\t\t\tfr,\n"
                + "".join(f"\t\t\t\t{lang},\n" for lang in NEW_LANGS)
                + "\t\t\t);",
            )
    PBXPROJ.write_text(text, encoding="utf-8")


def main() -> None:
    missing = merge_catalog(LOCALIZABLE)
    merge_infoplist()
    update_pbxproj()

    if missing:
        print(f"Warning: {len(missing)} keys used English fallback:")
        for key in missing:
            print(f"  - {key}")
    else:
        print("All keys translated.")

    print("Updated catalogs and project regions.")


if __name__ == "__main__":
    main()
