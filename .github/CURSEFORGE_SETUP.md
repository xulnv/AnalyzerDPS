# CurseForge Automatic Release Setup

## Krok 1: Uzyskaj CurseForge API Key

1. Zaloguj się na https://www.curseforge.com/
2. Przejdź do **My Account** → **API Keys**
3. Wygeneruj nowy API key dla swojego projektu
4. Skopiuj wygenerowany klucz

## Krok 2: Znajdź CurseForge Project ID

1. Przejdź do swojego projektu na CurseForge
2. URL projektu wygląda tak: `https://www.curseforge.com/wow/addons/TWOJA-NAZWA`
3. Kliknij **Edit Project** → **About Project**
4. Znajdź **Project ID** (liczba)

## Krok 3: Dodaj Secrets do GitHub

1. Przejdź do repozytorium: https://github.com/xulnv/AnalyzerDPS
2. Kliknij **Settings** → **Secrets and variables** → **Actions**
3. Kliknij **New repository secret**
4. Dodaj:
   - Name: `CF_API_KEY`
   - Value: [Twój CurseForge API key]
5. (Opcjonalnie) Dodaj `WOWI_API_TOKEN` dla WoWInterface

## Krok 4: Zaktualizuj Project ID w workflow

1. Otwórz plik `.github/workflows/release.yml`
2. Znajdź linię: `args: -p 1234567 -w 0`
3. Zamień `1234567` na swój **CurseForge Project ID**
4. Zapisz i commituj zmiany

## Krok 5: Tworzenie Release

### Automatyczny release (przez tag):
```bash
git tag v0.87
git push origin v0.87
```

### Ręczny release (przez GitHub):
1. Przejdź do: https://github.com/xulnv/AnalyzerDPS/releases
2. Kliknij **Create a new release**
3. Wybierz tag (np. `v0.87`) lub utwórz nowy
4. Wypełnij tytuł i opis
5. Kliknij **Publish release**

GitHub Actions automatycznie:
- Spakuje addon
- Wyśle do CurseForge
- Wyśle do WoWInterface (jeśli skonfigurowane)
- Utworzy GitHub Release

## Sprawdzanie statusu

1. Przejdź do: https://github.com/xulnv/AnalyzerDPS/actions
2. Znajdź workflow **Release to CurseForge**
3. Sprawdź logi jeśli coś poszło nie tak

## Troubleshooting

### "CF_API_KEY not found"
- Sprawdź czy dodałeś secret w GitHub Settings → Secrets

### "Invalid project ID"
- Sprawdź czy Project ID w `.github/workflows/release.yml` jest poprawny

### "Permission denied"
- Sprawdź czy API key ma uprawnienia do uploadu plików
