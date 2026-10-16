# Claude Code -> jcode mechanical text mapping.
# Applied by scripts/build-jcode.py via `LC_ALL=C sed -E -f jcode/translate.sed`
# to copies of rules/*.md and skills/**/*.md, local-skills/**/*.md.
# jcode has no question tool: questions are asked inline (format: jcode/rules.md).
# "soru aracı" -> "inline soru biçimi"; Turkish case suffixes change with the
# noun (aracına -> biçimine), so each form has its own rule, longest first.
# ASCII-only spellings (araci) are matched alongside.

# --- Question tool -> inline question ---
s/\(soru aracı, `multiSelect: true`\)/(inline soru, çok seçimli)/g
s/Soru arac(ı|i)yla/Inline soru biçimiyle/g
s/soru arac(ı|i)yla/inline soru biçimiyle/g
s/Soru arac(ı|i)ndan/Inline soru biçiminden/g
s/soru arac(ı|i)ndan/inline soru biçiminden/g
s/Soru arac(ı|i)nda/Inline soru biçiminde/g
s/soru arac(ı|i)nda/inline soru biçiminde/g
s/Soru arac(ı|i)n(ı|i)n/Inline soru biçiminin/g
s/soru arac(ı|i)n(ı|i)n/inline soru biçiminin/g
s/Soru arac(ı|i)n(ı|i)/Inline soru biçimini/g
s/soru arac(ı|i)n(ı|i)/inline soru biçimini/g
s/Soru arac(ı|i)na/Inline soru biçimine/g
s/soru arac(ı|i)na/inline soru biçimine/g
s/Soru arac(ı|i)([^[:alnum:]_]|$)/Inline soru biçimi\2/g
s/soru arac(ı|i)([^[:alnum:]_]|$)/inline soru biçimi\2/g
s/(Düz metin soru|Duz metin soru)/Biçimsiz soru/g
s/(düz metin soru|duz metin soru)/biçimsiz soru/g
s/AskUserQuestion/inline soru/g

# --- Recommended label ---
s/`\(Recommended\)`/`(Önerilen)`/g
s/ \(Recommended\)/ (Önerilen)/g
s/^- Recommended:/- Önerilen:/
