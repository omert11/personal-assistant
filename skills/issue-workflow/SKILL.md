---
name: issue-workflow
description: Issue/ticket/doc/gorsel kaynagini uctan uca cozer, kanitlar ve commit eder.
when_to_use: Trigger — "su ticket'i coz", "issue-workflow ile bak", "bu hatayi worktree'de coz", "ticket analiz et ve duzelt", "su dokumandaki sorunu hallet", "yonetici modunda", "fazlandirarak yap", "/issue-workflow <ref|metin>". Bir issue/ticket/dokuman/gorsel/mesaj kaynagi verilip uctan uca (kaynak → analiz → plan → cozum → kanit → commit) cozulmesi istendiginde. Orta/buyuk islerde yonetici modu: tum is fazli sub-agent dalgalarina bolunur, kontrol sonda tek seferde. Tek seferlik kucuk duzeltmeler icin gerekmez.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: max
allowed-tools: Bash, BashOutput, KillShell, Read, Write, Edit, Grep, Glob, AskUserQuestion, Monitor, TaskList, TaskGet, TaskStop, TaskCreate, TaskUpdate, WebFetch, EnterWorktree, ExitWorktree, Skill
---

# Issue Workflow — Kaynak → Analiz → Plan → Cozum → Kanit → Commit

Delegasyon: teslimat + code-review → `commit`, log → `diji-logs` (kapsamli tarama `log-triage`), Plane → `plane-cli`.

## Genel kurallar

- **Duraklamasiz tek akis**: adimlar arasinda onay/kapı yok; basindan sonuna kesintisiz yurut. Yalniz gercekten belirsiz bir karar veya sert durak (mimari ihlal, cozulemeyen hata) varsa soru araciyla sor.
- **Kontrol sonda, tek seferde**: ara commit, ara build, ara review, asamali teslim YOK. Surec icindeki kirik noktalar normal. Dogrulama, review, kanit isin sonunda bir kez; tek PR. Butunluk sozlesme faziyla (yonetici modu) saglanir.
- Istegin arkasindaki ihtiyaci coz; en dogru yolu sen belirle:
  - Kolay olani degil dogru olani sec; ilk calisan cozumde durma, daha zarif/basit yol ara
  - Sektorde/framework'te yerlesik pattern varsa onu tercih et
  - Yapisal imkansizligi "olur" deme, ek kazanimi gizleme; ikisini de sonuc raporuna yaz
- Kullaniciya her soruyu soru araciyla sor; duz metin soru yok.
- Kanit dosyalari `/tmp/issue-<isim>/` altinda, repo disi; repo'ya kanit/credential sizmaz.

---

## Adim 1 — AGENTS.md "## Issue Workflow" alanini oku (ILK IS)

```bash
grep -n "## Issue Workflow" AGENTS.md 2>/dev/null
```

Varsa tamamini oku ve uygula (kurulum, baslatma, test, port, akis notlari). Yoksa zorlama; is sirasinda proje-ozel ihtiyac dogarsa bolumu Ek'teki sablonla olustur.

## Adim 2 — Kaynak toplama (ATLANAMAZ)

Her kaynagi tek tek, tam detayli incele — gorseller dahil; ozetle gecme.

| Kaynak | Nasil al |
|---|---|
| **Plane issue** (`PROJ-123`) | `plane-cli` skill → `issue get-id` + `issue get` + `comment list` (tum yazismalar) + ekler; ekli gorseli indir ve oku |
| **Serbest metin / mesaj** | Dogrudan oku, talebi madde madde cikar |
| **Gorsel** | Gorseli incele — hata metni, kod, URL cikar. TR hata mesajiysa orijinal msgid'i `locale/*/LC_MESSAGES/*.po` icinde ara |
| **Dokuman** (PDF/Word/HTML) | Markdown'a cevirip oku; URL ise icerigini cek |
| **Log / hata ciktisi** | VictoriaLogs'lu diji projesiyse `diji-logs` skill; kapsamli tarama `log-triage`; degilse icerikte ara |

Obsidian vault tanimliysa `obsidian-search` ile onceki cozum ara.

Cikti: anahtar veriler (ref, hata kodu, kullanici, tarih, modul/dosya/endpoint) context'te hazir.

## Adim 3 — Analiz (ULTRATHINK)

`effort: max`. Ilk hipotezde durma; kodu/logu gerektigi kadar incele; semptomu degil kok nedeni bul. Context'te netlestir:

- Suanki durum: bugunku davranis, modul haritasi, hata
- Ne isteniyor: talep, somut ve madde madde
- Neden isteniyor: ihtiyacin koku — is degeri, etkilenen kullanici/akis
- Ne hazir / ne yapilacak / nasil yapilacak
- Oneriler: talebin otesindeki firsatlar
- Acik konular: her biri icin en iyi secenegi sen sec; yalniz gercekten belirsizse soru araciyla sor (onerilen isaretli)
- Riskler, durust avantaj/dezavantaj

## Adim 4 — Uygulama modu (sormadan)

| Durum | Mod | Ne degisir |
|---|---|---|
| Tek is paketi, dar kapsam, tek dosya kumesi | **Tek akis** (varsayilan) | Adim 7 aynen |
| 2+ ayrik gorev veya sirali bagimlilik iceren orta/buyuk is | **Yonetici modu** | Adim 7 yerine **7Y** ([references/yonetici-modu.md](references/yonetici-modu.md)); plan fazlanir |

- Kullanici soylediyse yonetici modu: "yonetici modunda", "fazlandirarak yap", "is paketlerine bol", "sub-agent'larla yurut".
- Aksi halde asagidaki sinyallerden en az ikisi varsa yonetici modu, yoksa tek akis:
  - Analizde birbirinden bagimsiz 2+ gorev (ayrik dosya kumeleri)
  - Sirali baglilik: bir isin ciktisi digerinin girdisi
  - Tek oturumda bitmeyecek buyukluk (genis refactor, coklu modul, migration + UI + API)

## Adim 5 — Worktree ac + plan

- Kebab-case isim: Plane issue → `fix-<issue-ident>`, bug → `fix-<konu>`, feature → `feat-<konu>`.
- `EnterWorktree({ name })`. Session cwd worktree'ye gecer; kanit klasoru `/tmp/issue-<isim>/`.
- `SESSION_NAME` = bu isim; context'te sabit tut (Adim 7 log etiketi, Adim 8 temizlik).

Plani context'te kur ve onay beklemeden uygula:

- Hangi dosyada ne degisecek
- Acik konularin kararlari
- Yan etki / risk ve nasil dogrulanacagi
- Dilin logger'i varsa `[SESSION_NAME]` etiketli log eklenecegi
- Yonetici modundaysa faz tablosu: sozlesme fazi + sirali fazlar, her fazin gorevleri ve gorev basina yazilabilir dosya yollari (ayni dosyaya yazan gorevler ayni fazda olamaz)

## Adim 6 — Plane issue'yu isleme al (kaynak Plane issue ise; OTOMATIK)

Kaynak Plane issue degilse veya proje tanimli degilse atla. Onay sorma; uygula, tek satir bildir. Sozdizimi `plane-cli` skill'inden (`--json`). Idempotent — dolu alani bozma:

1. `issue get` — mevcut assignee / `start_date` / state group
2. Yalniz `backlog`/`unstarted` ise `started`'a cek; started/completed/cancelled ise DOKUNMA
3. Assignee bossa self ata (`issue assignee --add`; REPLACE yapan `update --assignees` KULLANMA)
4. `start_date` bossa bugunu ata

Label/priority/target-date `commit` skill'in isi.

## Adim 7 — Uygula + Test + Kanit

Yonetici modunda bunun yerine **7Y** ([references/yonetici-modu.md](references/yonetici-modu.md)) kosar; kanit isin sonunda 7a-7d ile uretilir.

Plani uygula: hatalari wrap et (Go `fmt.Errorf("...: %w", err)`, Python `raise X from err`), sonradan tamamlanacak yerlere `TODO:` yorumu, workaround yok (`~/.claude/rules/core.md`).

Dil izin veriyorsa kritik akis noktalarina `[SESSION_NAME]` prefix'li detayli log ekle (orn `logger.debug("[fix-proj-123] payment intent %s created", pid)`); logger yoksa zorlama.

```bash
EVID=/tmp/issue-<isim>
mkdir -p "$EVID"
```

### 7a. Test ortamini worktree'de hazirla
Uygulamayi worktree'de kur, ana checkout'a dokunma. Komutlar Adim 1'den; yoksa proje tipinden cikar (Python `uv venv` + requirements, Node `npm install`, Go `go build ./...`).

### 7b. Unique port ile ARKA PLANDA calistir
```bash
PORT=$(python3 -c "import socket;s=socket.socket();s.bind(('',0));print(s.getsockname()[1]);s.close()")
echo "$PORT" > "$EVID/.port"
# run_in_background: true — orn:
#   Django: .venv/bin/python manage.py runserver 127.0.0.1:$PORT 2>&1 | tee $EVID/server.log
#   Node:   PORT=$PORT npm run dev 2>&1 | tee $EVID/server.log
```
Bound port'u bekle, sonra testlere gec.

### 7c. Testler + kanit dosyalari
| Sorun tipi | Kanit araci | Cikti |
|---|---|---|
| **Gorsel / UI / akis** | tarayicida ac (`PORT`'a baglan), ekran goruntusu al | `$EVID/screenshot-*.png` (before/after) |
| API / backend endpoint | HTTP istegi (`localhost:$PORT`) | `$EVID/api-before.json`, `api-after.json` |
| Mantik / fonksiyon | test (`pytest` / `npm test`) | `$EVID/test-output.txt` |
| Veri / DB / log | shell sorgu | `$EVID/query-result.txt` |
| Her durum | before/after diff | `$EVID/diff.txt` |

- Gorsel degisiklikte screenshot ZORUNLU; yoksa cozum kanitlanmis sayilmaz.
- Teshis: `grep "\[SESSION_NAME\]" $EVID/server.log`.

### 7d. Arka plandaki uygulamayi DURDUR (ZORUNLU)
Arka plan islemini sonlandir (gerekirse `kill $(lsof -ti tcp:$PORT)`); tarayici aciksa kapat. Hata/iptalde de yap — orphan process/port birakma. Kanit dosyalarinda credential kontrolu yap.

## Adim 8 — `[SESSION_NAME]` log temizligi (BLOKLAYICI)

Log eklenmediyse atla.

```bash
grep -rn "\[<SESSION_NAME>\]" .
```

- Gecici debug (akis izleme, degisken dump) → satiri komple sil
- Prod'da anlamli kalici log → kalir, `[SESSION_NAME]` etiketi cikarilir

`grep` bos donene kadar Adim 9'a gecme. Temizlikten sonra kritik akisi bir kez daha dogrula.

## Adim 9 — Commit skill (tek teslimat, tek PR)

`commit` skill'e delege et. Code-review akisin tek review noktasi, orada kosar (buyuk diff'te dosya kumesine gore paralel `claude -p` oturumlarina bolunur; bulgu duzeltmesi sub-agent'lara dagitilabilir — yonetici modunda diff tum isi kapsar, bolunme normal). Tek commit + tek PR; Plane kapama da `commit` skill'de.

## Adim 10 — Sonuc raporu (`user-report`)

`user-report` skill'i ile HTML rapor olustur ve kullanicinin tarayicisinda ac; sohbete dosya yolu + tek satir ozet. Icerik:
- Acik konularin kararlari + uygulanma durumu; yeni doganlar
- Kanitlar: `$EVID/` dosyalari (ekran goruntuleri gomulu), her birinin neyi ispatladigi tek cumleyle
- Ek kazanclar: yan iyilestirmeler (temizlenen kod, kapatilan baska bug, performans)
- Son durum: cozum sonrasi davranis, once/sonra karsilastirmasi
- Commit/PR ve Plane sonucu

## Ek — `AGENTS.md` "## Issue Workflow" sablonu

```markdown
## Issue Workflow

- **Bagimlilik kurulum**: <orn `uv venv && source .venv/bin/activate && uv pip install -r requirements.txt`>
- **Baslatma komutu**: <orn `.venv/bin/python manage.py runserver 127.0.0.1:$PORT`>
- **Test komutu**: <orn `pytest`, `npm test`, `playwright test`>
- **Build/lint komutu**: <orn `cargo build`, `npm run lint`, `mypy .`>
- **Port**: unique (otomatik) | sabit gerekiyorsa: <port>
- **Ek servisler**: <redis/postgres gerekli mi, nasil ayaga kalkar>
- **Akis notlari**: <bu projede dikkat edilecekler>
```
