---
name: project-init
description: Yeni bir projede CLAUDE.md, CLAUDE.local.md, solo.yml dosyalarini kontrol edip eksikleri interaktif sekilde tamamlayan skill. Vikunja projesi olusturma, Solo proje baglama ve solo.yml yapilandirmasi dahil. Bu skill'i su durumlarda kullan - "projeyi kur", "init", "proje baslat", "yapilandirma", "setup", "CLAUDE.md olustur", "solo.yml ekle", "vikunja projesi ac". Ayrica her konusmanin basinda eksik yapilandirma tespit edildiginde otomatik olarak onerilerek tetiklenmeli.
disable-model-invocation: false
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# Project Init

Yeni projeyi Claude Code ile entegre eden skill. Eksikleri tespit eder, **tek toplu soruyla** bilgileri toplar, dosyaları oluşturur.

## Temel İlke

**Kullanıcıyı az kes.** Önce sessizce analiz yap, tüm soruları tek `AskUserQuestion` bloğunda topla, sonra oluştur.

## Tetikleme

1. Kullanıcı `/project-init` veya "projeyi kur" dediğinde
2. `init.md` rule'u her oturum başında eksik yapılandırma tespit edildiğinde bu skill'i önerir (AskUserQuestion ile)

## İş Akışı

### 1. Mevcut Durumu Tespit

Sessizce kontrol et:

```bash
CWD=$(pwd)
PROJECT_NAME=$(basename "$CWD")

# Dosya varlıkları
HAS_CLAUDE_MD=$([ -f "CLAUDE.md" ] && echo true || echo false)
HAS_CLAUDE_LOCAL=$([ -f "CLAUDE.local.md" ] && echo true || echo false)
HAS_SOLO=$([ -f "solo.yml" ] && echo true || echo false)
HAS_GITIGNORE=$([ -f ".gitignore" ] && echo true || echo false)
IS_GIT=$([ -d ".git" ] && echo true || echo false)

# CLAUDE.local.md içinde ID'ler var mı
VIKUNJA_ID=$(grep -oE "Vikunja.*ID:\s*\K[0-9]+" CLAUDE.local.md 2>/dev/null || echo "")
SOLO_ID=$(grep -oE "Solo.*ID:\s*\K[0-9]+" CLAUDE.local.md 2>/dev/null || echo "")
OBSIDIAN_FOLDER=$(grep -oE "Obsidian Folder:\s*\K.+" CLAUDE.local.md 2>/dev/null || echo "")
```

### 2. Stack Tespiti

Kısa tarama ile otomatik:

| Dosya | Stack |
|-------|-------|
| `package.json` | Node/JS/TS (React/Svelte/Next içeriğinden ayır) |
| `pyproject.toml` veya `requirements.txt` | Python (Django `manage.py` varsa Django) |
| `go.mod` | Go |
| `Cargo.toml` | Rust (Tauri için `src-tauri/` var mı) |
| `pubspec.yaml` | Flutter |
| Hiçbiri | "Belirsiz" |

Sonucu sakla, sorularda default olarak sun.

### 3. Eksik Listesi Çıkar

Hangi işlemler gerekli:
- `CLAUDE.md` yok mu → oluşturulacak
- `CLAUDE.local.md` yok mu → oluşturulacak
- `solo.yml` yok mu → oluşturulacak
- `.gitignore` yok veya `CLAUDE.local.md` içinde yok mu → eklenecek
- Vikunja ID yok mu → proje oluşturulacak (sorulacak)
- Solo ID yok mu → oluşturulacak (sorulacak)
- Obsidian Folder yok mu → vault içinde klasör oluşturulacak (sorulacak)
- Projeye özel bilgiler → sorulacak

### 4. Toplu Soru Bloğu

`AskUserQuestion` ile **tek seferde** sor (max 4 soru/blok, gerekirse art arda):

**Soru Grubu 1 — Proje Temel Bilgileri**

- **Proje adı**: default `$PROJECT_NAME`
- **Stack**: otomatik tespit edilen + "Başka" seçeneği
- **Açıklama**: kısa proje tanımı (1-2 cümle)

**Soru Grubu 2 — Entegrasyonlar**

- **Vikunja**: header "Vikunja", question "Vikunja'da proje oluşturayım mı?", options ["Evet, oluştur", "Mevcut projeyi seç", "Hayır"]
- **Solo**: header "Solo", question "Solo projesi oluşturayım mı?", options ["Evet (boş solo.yml)", "Hayır"]
- **Obsidian**: header "Obsidian", question "Obsidian vault içinde proje klasörü oluşturayım mı?", options ["Evet, oluştur", "Mevcut klasörü seç", "Hayır"]

**Soru Grubu 3 — Projeye Özel**

- header: "Ekstra Bilgi"
- question: "CLAUDE.local.md'ye eklemek istediğin projeye özel bilgi var mı? (Örn: staging URL, özel endpoint, test hesabı)"
- options: ["Var, yazayım", "Hayır, boş bırak"]

**Soru Grubu 4 — Solo.yml İçeriği (eğer Solo seçildiyse)**

- Kullanıcıya solo.yml process'lerini sor (backend, frontend, admin vb.)
- Her process için command'i aç uç soru ile al

**Soru Grubu 5 — Git (opsiyonel)**

- header: "Git"
- question: ".gitignore'a CLAUDE.local.md ve .claude/settings.local.json eklensin mi?"
- options: ["Evet, ekle", "Hayır"]

### 5. Dosya Oluşturma

Cevaplara göre sessizce:

#### CLAUDE.md Şablonu

```markdown
# {PROJE_ADI}

{AÇIKLAMA}

## Stack
- {STACK_DETAY}

## Dil
Türkçe iletişim, İngilizce kod yorumu ve commit mesajları.

## Kullanılabilir MCP Araçları
{PROJEYE UYGUN MCP'LER — örneğin Django projesiyse vikunja, solo, context7, github}

## Kod Konvansiyonları
{STACK'E ÖZEL — örn Django: pre-commit + black + isort + dijilint; Go: golangci-lint; Rust: clippy}

## Proje Yapısı
{STACK'E GÖRE TIPIK YAPI}

## Komutlar
{YAYGIN KOMUTLAR — test, lint, build, deploy}
```

Gereksiz bölümleri atlama: kullanıcının verdiği bilgiyle gerekeni yaz, yapay olarak şişirme.

#### CLAUDE.local.md Şablonu

```markdown
# Local Yapılandırma

## Vikunja
- **Proje**: {AD} (ID: {VIKUNJA_ID})

## Solo
- **Proje**: {AD} (ID: {SOLO_ID})

## Obsidian
- **Obsidian Folder**: {OBSIDIAN_FOLDER}

> NOT: `Obsidian Folder: <isim>` satırı init-check regex tarafından aranır. Formatı koru.

## Projeye Özel
{KULLANICININ VERDIĞI EKSTRA BILGILER}
```

#### solo.yml Şablonu (boş, kullanıcı dolduracak)

```yaml
name: {PROJE_ADI}
icon: null
processes:
  # Process'lerini buraya ekle
  # Örnek:
  # backend:
  #   command: ...
  #   auto_start: true
```

Kullanıcı soru grubu 4'te process verdiyse buraya doldur.

#### .gitignore Güncelleme

Kullanıcı onayladıysa:
```
echo "CLAUDE.local.md" >> .gitignore
echo ".claude/settings.local.json" >> .gitignore
```

Duplicate eklememek için önce grep ile kontrol et.

### 6. Entegrasyon İşlemleri

#### Vikunja (seçildiyse)

**Evet, oluştur:**
```
vikunja-cli project create --title "<isim>" --json ile yeni proje oluştur
ID'yi al, CLAUDE.local.md'ye yaz
```

**Mevcut projeyi seç:**
```
vikunja-cli project list --json ile listele
AskUserQuestion ile seçtir (options olarak projeleri göster)
Seçileni CLAUDE.local.md'ye yaz
```

#### Solo (seçildiyse)

Solo MCP ile proje oluşturma tool'u var mı test et. Yoksa kullanıcıya Solo UI'dan manuel eklemesini söyle ve ID'yi bekle (soru sor).

#### Obsidian (seçildiyse)

Vault root: `~/Documents/ObsidianVault` (default).

**Evet, oluştur:**
```bash
VAULT="$HOME/Documents/ObsidianVault"
FOLDER="$VAULT/$PROJECT_NAME"
mkdir -p "$FOLDER"
# Opsiyonel: ilk not
touch "$FOLDER/index.md"
```
`CLAUDE.local.md`'ye `Obsidian Folder: <PROJECT_NAME>` yaz.

**Mevcut klasörü seç:**
```bash
ls -1 "$HOME/Documents/ObsidianVault"
```
Listele, `AskUserQuestion` ile seçtir. Seçileni `Obsidian Folder:` olarak yaz.

**Sonrasında:**

- **Yeni klasör oluşturulduysa** → Obsidian klasörü boş, doğrudan `obsidian-init` skill'ini / `obsidian-initializer` agent'ını **otomatik çağır** (sormadan). Rapor sonunda yazılan dosyaları göster.
- **Mevcut klasör seçildiyse** → İçinde dosyalar olabilir, `AskUserQuestion` ile sor:
  - header: "Obsidian"
  - question: "Mevcut klasöre proje belleği (MOC + wikilinks) eklensin mi? (Çakışan dosyalar atlanır)"
  - options: ["Evet, obsidian-init çalıştır", "Hayır, dokunma"]
  - Evet seçilirse agent'ı çağır.

### 7. Mevcut Proje Modu

Projede **bazı dosyalar zaten varsa**:
- Sadece eksikleri listele
- `AskUserQuestion` ile "Şu eksikler var: X, Y. Tamamlayayım mı?" sor
- Onaylı eksikleri tamamla
- Mevcut dosyalara dokunma (override etme)

### 8. Rapor

Skill bitince kısa bir özet:

```
✅ Oluşturulanlar:
  - CLAUDE.md (N satır)
  - CLAUDE.local.md
  - solo.yml (M process)
  - .gitignore güncellendi (2 satır)

✅ Entegrasyonlar:
  - Vikunja: Proje "X" oluşturuldu (ID: 42)

📝 Sonraki adımlar:
  - solo.yml process'lerini doldur
  - İlk commit'i at
```

## Kritik Kurallar

- **Tek seferde soru sor** (ask-first.md kuralına uyum)
- **Mevcut dosyaları override etme** — sadece eksikleri doldur
- **CLAUDE.local.md'yi git'e sakın commit'leme** — .gitignore'a ekle
- **Projeye uygun MCP listesi yaz** — Flutter'a Django MCP'si verme
- **Stack tespitinde dur, sor** — emin değilsen kullanıcıya danış
- Türkçe iletişim, dosya içeriği de Türkçe (kullanıcı istemezse)

## İlişkili

- `~/.claude/rules/init.md` (eski yer) → plugin `rules/init.md` — bu skill'in tetikleyici kaynağı
- `project-analyzer` skill → proje sağlık kontrolü (init sonrası çalışabilir)
- `commit` skill → init sonrası ilk commit için
