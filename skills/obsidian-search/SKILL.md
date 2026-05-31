---
name: obsidian-search
description: Vault'ta sorgu bazlı arama — ilgili notları bulur, okur, sentezleyip [[wikilink]]'lerle bağlar.
when_to_use: Trigger — "obsidian'da ara", "vault'ta bul", "X hakkında ne not almışım", "Y sorununu nasıl çözmüştük", "Z hakkında ne biliyoruz", "obsidian search", "/obsidian-search". obsidian-searcher agent'ını background çağırır; sorgu hedefli (recall rastgele, bu hedefli).
disable-model-invocation: false
allowed-tools: Task, Bash, Read, Grep, Glob
argument-hint: [arama-sorgusu]
---

# Obsidian Search

Proje vault'unda **sorgu bazlı** arama yapar: kullanıcının aradığı konuyu bulur, ilgili notları okur, **sentezlenmiş bir cevap + `[[wikilink]]` kaynak listesi** döner. `obsidian-recall`'dan farkı: bu **hedefli** (kullanıcının sorgusunu dinler), recall rastgele/spaced-repetition.

## İş Akışı

### 1. Sorguyu Al

`$ARGUMENTS` varsa onu kullan. Yoksa kullanıcının son mesajındaki arama niyetini al (örn. "vesentur'da flight tax 0 sorunu ne yapmalı").

### 2. Proje Klasörünü Tespit Et

`CLAUDE.local.md`'de `Obsidian Folder` tanımlıysa onu `FOLDER` olarak kullan (path filtresi gürültüyü ciddi azaltır). Yoksa `FOLDER` boş geç — searcher tüm vault'ta arar.

```bash
# Taşınabilir extraction (BSD/GNU uyumlu, markdown + düz format)
grep "Obsidian Folder" "$(pwd)/CLAUDE.local.md" 2>/dev/null \
  | grep -v "^>" | grep -v "init-check" | head -1 \
  | sed -E 's/.*Obsidian Folder[*]*:[[:space:]]*//;s/[*]*[[:space:]]*$//'
```

### 3. CLI Durumunu Kontrol Et

```bash
obsidian vault info=name 2>&1
```

Vault adı dönerse `CLI_ACTIVE: yes`, hata dönerse `CLI_ACTIVE: no` (searcher filesystem fallback kullanır).

### 4. obsidian-searcher Agent'ını BACKGROUND Çağır

`Task` ile, **`run_in_background: true`** (workflow kuralı: spawned agent her zaman background):

```
Task(
  subagent_type: "obsidian-searcher",
  run_in_background: true,
  prompt: "QUERY: <kullanıcı sorgusu>
FOLDER: <obsidian folder veya boş>
VAULT: ~/Documents/ObsidianVault
CLI_ACTIVE: <yes|no>"
)
```

Başlattıktan sonra kullanıcıya tek cümle bilgi ver ("Vault'ta '<sorgu>' araması başlattım"), `task-notification` gelene kadar bekle.

### 5. Sonucu Sun

Agent'ın döndürdüğü sentezi (sentezlenmiş cevap + `[[wikilink]]` kaynaklar) kullanıcıya aktar.

### 6. Aksiyon Önerisi (opsiyonel)

Kullanıcı bulunan bir notu **güncellemek/düzeltmek** isterse (searcher salt-okur, yazamaz), `AskUserQuestion` ile sor ve onaylanırsa `obsidian-writer MODE: append`'i ayrıca tetikle (recall'daki "Güncelle→writer" pattern'i).

## Kurallar

- **Agent salt-okur** — bu skill de arama sırasında vault'a yazmaz. Yazma gerekirse writer'a delege.
- **Background zorunlu** — searcher agent'ı `run_in_background: true` ile çağrılır (workflow kuralı).
- **Proje filtresi** — `Obsidian Folder` belliyse `FOLDER` olarak geç, arama isabeti artar.
- **CLI kapalıysa** — searcher otomatik filesystem fallback'e geçer; skill ekstra bir şey yapmaz.

## İlişkili

- `agents/obsidian-searcher.md` — bu skill'in çağırdığı arama agent'ı
- `skills/obsidian-recall/SKILL.md` — rastgele/spaced-repetition (bu skill hedefli)
- `skills/obsidian-note/SKILL.md` — yazma (Task→writer pattern referansı)
- `rules/obsidian.md` — "Önce MOC, sonra search" akışı + CLI komut repertuarı
