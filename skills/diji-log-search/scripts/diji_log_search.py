"""Basket (UserBookingBasket) lifecycle log analyzer for diji b2c Django apps.

Runs INSIDE the target Django project via: manage.py shell < basket_lifecycle.py
Config is passed through environment variables (set by the caller over SSH), because
`manage.py shell -c` inline quoting is fragile with $, ^, ~ and indentation.

Env vars:
  BL_REF        basket reference (e.g. 4BVVXK2O). Empty in diagnose-by-error mode.
  BL_MODE       lifecycle | provider | payment | raw | diagnose   (default: lifecycle)
  BL_WINDOW_H   usersession +/- hour window around the real transaction span (default: 3)
  BL_SCOPE      diagnose time scope: today | since   (default: today — o gunun loglari)
  BL_SINCE_MIN  diagnose mode (scope=since): scan errors in the last N minutes (default: 120)
  BL_LIMIT      diagnose mode: max error rows to scan (default: 50)
  BL_OUT_DIR    output directory; each search writes here. Per-record request/response
                payloads are split into format-aware files (.json/.xml) like the
                basket_api_logs panel modal. (default: /tmp/diji_log_search/<ref-or-diagnose>)

A human-readable summary goes to stdout (the caller may also redirect it to a file);
detailed raw payloads are written under BL_OUT_DIR.
"""
import os
import re
import json
import ast
import datetime

from django.db.models import Q, Min, Max
from django.utils import timezone

from common.models.logging import AppLog


def _now():
    """TZ-aware now when USE_TZ, naive otherwise — matches AppLog.created_at storage."""
    return timezone.now()


def _aware(dt):
    """Make a naive datetime comparable to created_at (aware when USE_TZ)."""
    if dt is not None and timezone.is_naive(dt) and timezone.is_aware(timezone.now()):
        return timezone.make_aware(dt, timezone.get_current_timezone())
    return dt

REF = os.environ.get("BL_REF", "").strip()
MODE = os.environ.get("BL_MODE", "lifecycle").strip()
WINDOW_H = int(os.environ.get("BL_WINDOW_H", "3"))
SCOPE = os.environ.get("BL_SCOPE", "today").strip()
SINCE_MIN = int(os.environ.get("BL_SINCE_MIN", "120"))
LIMIT = int(os.environ.get("BL_LIMIT", "50"))
QUERY = os.environ.get("BL_QUERY", "").strip()   # find mode: error message text or COMxxx code
DAYS = int(os.environ.get("BL_DAYS", "2"))        # diagnose/find: how many days back to scan
_query_slug = re.sub(r"[^A-Za-z0-9_.-]+", "_", QUERY)[:40].strip("_") if QUERY else ""
OUT_DIR = os.environ.get("BL_OUT_DIR", "").strip() or (
    "/tmp/diji_log_search/%s" % (REF or _query_slug or "diagnose"))

FRONTEND_LOGGER = "diji.common.api.frontend"
PROVIDER_NEEDLE = "gateway.provider"
ERROR_CODE_RE = re.compile(r"\bCOM[A-Z0-9]{6,}\b")


def ensure_out_dir(sub=""):
    path = os.path.join(OUT_DIR, sub) if sub else OUT_DIR
    os.makedirs(path, exist_ok=True)
    return path


def _slug(s):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", str(s))[:60].strip("_")


def is_xml(s):
    """Same heuristic as the panel modal isXML()."""
    return isinstance(s, str) and s.strip().startswith("<")


def write_section(rec_dir, name, value):
    """Write one request/response/last_sent section to its own format-aware file.

    JSON-like dict/list -> <name>.json (deep-parsed, indented)
    XML string          -> <name>.xml
    other string        -> <name>.txt
    Returns the written file path (or None).
    """
    if value is None:
        return None
    if isinstance(value, str) and is_xml(value):
        path = os.path.join(rec_dir, name + ".xml")
        with open(path, "w") as f:
            f.write(value)
        return path
    if isinstance(value, (dict, list)):
        path = os.path.join(rec_dir, name + ".json")
        with open(path, "w") as f:
            json.dump(deep_parse(value), f, indent=2, ensure_ascii=False)
        return path
    # string that might itself be JSON
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            path = os.path.join(rec_dir, name + ".json")
            with open(path, "w") as f:
                json.dump(deep_parse(parsed), f, indent=2, ensure_ascii=False)
            return path
        except Exception:
            path = os.path.join(rec_dir, name + ".txt")
            with open(path, "w") as f:
                f.write(value)
            return path
    path = os.path.join(rec_dir, name + ".txt")
    with open(path, "w") as f:
        f.write(str(value))
    return path


def split_record_payload(data_obj):
    """Mirror panel buildSections: detect request/response/last_sent/last_received.
    Returns list of (section_name, value). Falls back to a single 'data' section.
    """
    sections = []
    if isinstance(data_obj, dict):
        for key in ("request", "response", "last_sent", "last_received"):
            if key in data_obj and data_obj[key] not in (None, ""):
                sections.append((key, data_obj[key]))
    if not sections:
        sections.append(("data", data_obj))
    return sections


def deep_parse(o):
    """Mirror of the panel's client-side parseNestedJSON: recursively parse JSON-in-strings."""
    if isinstance(o, str):
        try:
            return deep_parse(json.loads(o))
        except Exception:
            return o
    if isinstance(o, dict):
        return {k: deep_parse(v) for k, v in o.items()}
    if isinstance(o, list):
        return [deep_parse(x) for x in o]
    return o


def pretty_data(raw):
    if not raw or not raw.strip():
        return ""
    try:
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = ast.literal_eval(raw)
        return json.dumps(deep_parse(parsed), indent=2, ensure_ascii=False)
    except Exception as e:
        return "!! parse fail: %s\n%s" % (e, raw[:4000])


def collect_trace_ids(basket):
    """BasketLogsMixin logic: gather all trace (type, id) pairs tied to this basket."""
    from common.api.gateway.utils.product.booking import get_bookings_by_basket
    from common.api.gateway.utils.basket import get_item_id_map

    ids = set()
    payment_ids = set()
    booking_ids = set()
    gateway_session_ids = set()

    def add(t, i):
        if i is not None:
            ids.add((t, str(i)))

    add("common.userbookingbasket", basket.pk)
    add("common.usersession", basket.session.id)

    try:
        bookings = get_bookings_by_basket(basket.reference, get_item_id_map(basket.reference))
        for bk in bookings:
            add(bk._meta.label_lower, bk.pk)
            booking_ids.add(bk.pk)
            pt = getattr(bk, "payment_transaction", None)
            if pt:
                add(pt._meta.label_lower, pt.pk)
                payment_ids.add(pt.pk)
            se = getattr(bk, "session", None)
            if se:
                add(se._meta.label_lower, se.pk)
                gateway_session_ids.add(se.pk)
                for ss in se.search_sessions.all():
                    add(ss._meta.label_lower, ss.pk)
                pf = getattr(se, "payment_form", None)
                if pf:
                    add(pf._meta.label_lower, pf.pk)
    except Exception as e:
        print("# WARN trace collect failed: %s" % e)

    return ids, payment_ids, booking_ids, gateway_session_ids


def q_for_ids(ids):
    q = Q()
    for t, i in ids:
        q |= Q(trace_type=t, trace_id=i)
    return q


def real_window(basket):
    """Real transaction span from the basket's own trace (NOT usersession)."""
    core = AppLog.objects.filter(
        trace_type="common.userbookingbasket", trace_id=str(basket.pk)
    )
    agg = core.aggregate(mn=Min("created_at"), mx=Max("created_at"))
    mn, mx = agg["mn"], agg["mx"]
    if not mn:
        # fallback: basket.created_at +/- window
        base = getattr(basket, "created_at", None) or _now()
        mn = mx = base
    lo = mn - datetime.timedelta(hours=WINDOW_H)
    hi = mx + datetime.timedelta(hours=WINDOW_H)
    return mn, mx, lo, hi


def dedup(qs):
    seen = set()
    rows = []
    for r in qs:
        key = (r.created_at.replace(microsecond=0), r.message)
        if key in seen:
            continue
        seen.add(key)
        rows.append(r)
    return rows


def get_basket(ref):
    from common.models.booking.basket.models import UserBookingBasket

    return UserBookingBasket.objects.get(reference=ref)


def logreader_health():
    """Check LogReaderTask import freshness BEFORE analyzing.

    If CSV logs are newer than what got imported into AppLog, the analysis will be
    incomplete (logs not yet read). We compare the newest AppLog.created_at against
    the newest line written to the diji CSV, and report the lag.
    """
    print("#" * 80)
    print("# LOGREADER SAGLIK KONTROLU (arastirma oncesi)")
    last_db = (AppLog.objects.order_by("-created_at")
               .values_list("created_at", flat=True).first())
    print("# Son AppLog kaydi (DB) : %s" % last_db)

    csv_mtime = None
    import os as _os

    def _find_diji_csv():
        # 1) Django LOGGING handlers
        try:
            from django.conf import settings
            for h in (getattr(settings, "LOGGING", {}).get("handlers", {}) or {}).values():
                fn = h.get("filename", "")
                if fn.endswith("diji.csv"):
                    return fn
        except Exception:
            pass
        # 2) common BASE_DIR / server/logs/diji.csv
        try:
            from django.conf import settings
            for cand in (
                _os.path.join(str(getattr(settings, "BASE_DIR", "")), "server", "logs", "diji.csv"),
                _os.path.join(str(getattr(settings, "BASE_DIR", "")), "logs", "diji.csv"),
            ):
                if _os.path.exists(cand):
                    return cand
        except Exception:
            pass
        return None

    try:
        log_file = _find_diji_csv()
        if log_file and _os.path.exists(log_file):
            csv_mtime = _aware(datetime.datetime.fromtimestamp(_os.path.getmtime(log_file)))
            print("# diji.csv son yazma     : %s (%s)" % (csv_mtime, log_file))
        else:
            print("# diji.csv bulunamadi    : path tespit edilemedi (cursor ile dogrula)")
    except Exception as e:
        print("# diji.csv mtime okunamadi: %s" % e)

    # cursor file
    try:
        import os as _os
        from common.helpers import tasks as _t
        cursor_file = getattr(_t, "_CURSOR_FILE", None)
        if cursor_file and _os.path.exists(cursor_file):
            with open(cursor_file) as f:
                cursors = json.load(f)
            if cursors:
                newest = max(cursors.values())
                cur_dt = _aware(datetime.datetime.fromtimestamp(newest))
                print("# cursor en yeni ts      : %s" % cur_dt)
                now = _now()
                if cur_dt > now + datetime.timedelta(minutes=5):
                    print("# !! UYARI: cursor GELECEK tarihte — cursor poisoning suphesi, import durmus olabilir")
    except Exception as e:
        print("# cursor okunamadi       : %s" % e)

    if last_db and csv_mtime:
        try:
            lag = (csv_mtime - last_db).total_seconds()
        except TypeError:
            # naive/aware mismatch (USE_TZ edge case) — skip lag report, don't crash
            print("# diji.csv-DB lag      : hesaplanamadi (TZ uyumsuzlugu)")
            print("#" * 80)
            return
        if lag > 120:
            print("# !! UYARI: CSV, DB'den ~%d sn daha yeni — bazi loglar HENUZ IMPORT EDILMEMIS olabilir." % lag)
            print("#    Eksik gorursen LogReaderTask'i tetikle: async_to_sync(LogReaderTask().task)()")
        else:
            print("# OK: import guncel (CSV-DB farki ~%ss)" % int(lag))
    print("#" * 80)


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

def mode_lifecycle(basket):
    ids, payment_ids, booking_ids, _ = collect_trace_ids(basket)
    mn, mx, lo, hi = real_window(basket)

    q = q_for_ids(ids)
    qs = (AppLog.objects.filter(q)
          .exclude(logger=FRONTEND_LOGGER)
          .exclude(logger__icontains=PROVIDER_NEEDLE)
          .filter(created_at__gte=lo, created_at__lte=hi)
          .order_by("created_at", "id"))
    rows = dedup(qs)
    base = ensure_out_dir()

    lines = []
    lines.append("=" * 80)
    lines.append(" BASKET LIFECYCLE — %s" % basket.reference)
    lines.append("=" * 80)
    lines.append(" status        : %s" % basket.status)
    lines.append(" session       : %s (kalici kullanici oturumu)" % basket.session.id)
    lines.append(" bookings      : %s" % sorted(booking_ids))
    lines.append(" payment txns  : %s" % sorted(payment_ids))
    lines.append(" real span     : %s -> %s" % (mn, mx))
    lines.append(" window (+-%sh) : %s -> %s" % (WINDOW_H, lo, hi))
    lines.append(" rows          : %s (raw %s)" % (len(rows), qs.count()))
    lines.append(" excluded      : %s , *%s*" % (FRONTEND_LOGGER, PROVIDER_NEEDLE))
    lines.append("-" * 80)
    for r in rows:
        logger_short = r.logger.split("gateway.")[-1]
        lines.append("%s | %-22s | %-14s | %s" % (
            r.created_at.strftime("%Y-%m-%d %H:%M:%S"),
            logger_short[:22],
            r.trace_type.split(".")[-1][:14],
            r.message[:200].replace("\n", " "),
        ))

    summary = "\n".join(lines)
    print(summary)
    with open(os.path.join(base, "summary.txt"), "w") as f:
        f.write(summary + "\n")
    print("-" * 80)
    print(" summary: %s/summary.txt" % base)


def _dump_payloads(qs, title, sub):
    """Write each record's request/response into its own format-aware file.

    Layout:  <OUT_DIR>/<sub>/<NN>_<logger-tail>_<id>/{request.json,response.xml,...}
    Plus an index.txt listing every record. Mirrors the basket_api_logs modal which
    splits request/response (JSON) and last_sent/last_received (XML) into sections.
    """
    base = ensure_out_dir(sub)
    rows = dedup(qs)  # drop per-worker duplicates (same second + message)
    index_lines = []
    print("=" * 80)
    print(" %s — count=%s" % (title, len(rows)))
    print(" out: %s" % base)
    print("=" * 80)

    for n, r in enumerate(rows, 1):
        # parse the data column (json or python-repr) into an object
        data_obj = None
        raw = r.data or ""
        if raw.strip():
            try:
                try:
                    data_obj = json.loads(raw)
                except Exception:
                    data_obj = ast.literal_eval(raw)
            except Exception:
                data_obj = raw  # keep as raw string

        logger_tail = _slug(r.logger.split("gateway.")[-1].split(".")[-1])
        rec_dir = os.path.join(base, "%02d_%s_%s" % (n, logger_tail, r.id))
        os.makedirs(rec_dir, exist_ok=True)

        # meta file
        with open(os.path.join(rec_dir, "meta.txt"), "w") as f:
            f.write("id=%s\ncreated_at=%s\nlogger=%s\ntrace_type=%s\ntrace_id=%s\nlevel=%s\nmessage=%s\n"
                    % (r.id, r.created_at, r.logger, r.trace_type, r.trace_id, r.level, r.message))

        written = []
        if data_obj is not None and data_obj != "":
            for name, value in split_record_payload(data_obj):
                p = write_section(rec_dir, name, value)
                if p:
                    written.append(os.path.basename(p))

        line = "%02d | %s | %s | %s | %s -> [%s]" % (
            n, r.created_at.strftime("%Y-%m-%d %H:%M:%S"),
            r.logger.split("gateway.")[-1][:40], r.trace_type.split(".")[-1],
            r.message[:80].replace("\n", " "), ", ".join(written) or "no-data")
        index_lines.append(line)
        print(line)

    with open(os.path.join(base, "index.txt"), "w") as f:
        f.write("%s — count=%s\n%s\n" % (title, len(rows), "\n".join(index_lines)))
    print("-" * 80)
    print(" index: %s/index.txt" % base)


def mode_provider(basket):
    ids, _, _, _ = collect_trace_ids(basket)
    _, _, lo, hi = real_window(basket)
    qs = (AppLog.objects.filter(q_for_ids(ids))
          .filter(logger__icontains=PROVIDER_NEEDLE)
          .filter(created_at__gte=lo, created_at__lte=hi)
          .order_by("created_at", "id"))
    _dump_payloads(qs, "PROVIDER RAW LOGS — %s" % basket.reference, "provider")


def mode_payment(basket):
    ids, payment_ids, _, _ = collect_trace_ids(basket)
    _, _, lo, hi = real_window(basket)
    # payment-related loggers + paymenttransaction trace
    pay_q = q_for_ids({("common.paymenttransaction", str(p)) for p in payment_ids})
    pay_q |= Q(logger__icontains="payment.base") | Q(logger__icontains="payment.gateway") \
        | Q(logger__icontains="payment.views") | Q(logger__icontains="payment.session")
    qs = (AppLog.objects.filter(q_for_ids(ids) & pay_q)
          .exclude(logger=FRONTEND_LOGGER)
          .filter(created_at__gte=lo, created_at__lte=hi)
          .order_by("created_at", "id"))
    _dump_payloads(qs, "PAYMENT RAW LOGS — %s" % basket.reference, "payment")


def mode_raw(basket):
    ids, _, _, _ = collect_trace_ids(basket)
    _, _, lo, hi = real_window(basket)
    qs = (AppLog.objects.filter(q_for_ids(ids))
          .exclude(logger=FRONTEND_LOGGER)
          .filter(created_at__gte=lo, created_at__lte=hi)
          .order_by("created_at", "id"))
    _dump_payloads(qs, "RAW APPLOG DUMP — %s" % basket.reference, "raw")


def resolve_error_code(code):
    """Look up a COMxxx error code in core.messages.messages and return its English text."""
    if not code:
        return None
    try:
        from core.messages import messages as _m
        md = getattr(_m, code, None)
        if md is not None:
            for attr in ("message", "text", "default", "value"):
                v = getattr(md, attr, None)
                if isinstance(v, str) and v:
                    return v
            return str(md)
    except Exception:
        pass
    return None


def _diag_since(now):
    """Compute scan start. SCOPE=since -> last N min; else -> last DAYS days (today inclusive)."""
    if SCOPE == "since":
        return now - datetime.timedelta(minutes=SINCE_MIN), "son %s dk" % SINCE_MIN
    start = (now - datetime.timedelta(days=max(0, DAYS - 1))).replace(
        hour=0, minute=0, second=0, microsecond=0)
    return start, "son %s gun (%s ->)" % (DAYS, start.date())


def mode_diagnose():
    """No ref given: scan recent error/fail logs, map to baskets, resolve codes.

    Scope: 'today'/default -> last BL_DAYS days (default 2, so dunku vakalar da gelir);
    'since' -> last BL_SINCE_MIN minutes.
    """
    now = _now()
    since, scope_label = _diag_since(now)
    err_q = (Q(level__gte=AppLog.LogLevels.ERROR)
             | Q(message__icontains="FAIL")
             | Q(message__icontains="Traceback")
             | Q(message__icontains="exception"))
    qs = (AppLog.objects.filter(err_q)
          .filter(created_at__gte=since)
          .exclude(logger=FRONTEND_LOGGER)
          .order_by("-created_at")[:LIMIT])

    print("=" * 80)
    print(" DIAGNOSE — %s hata taramasi (limit %s)" % (scope_label, LIMIT))
    print("=" * 80)

    basket_refs = []
    seen_refs = set()
    codes = {}
    for r in qs:
        code_m = ERROR_CODE_RE.search(r.message or "")
        code = code_m.group(0) if code_m else ""
        if code:
            codes.setdefault(code, resolve_error_code(code))
        print("%s | L%s | %s | %s | %s" % (
            r.created_at.strftime("%m-%d %H:%M:%S"), r.level,
            r.logger.split(".")[-1][:22], r.trace_type.split(".")[-1][:16],
            r.message[:150].replace("\n", " ")))
        if r.trace_type == "common.userbookingbasket" and r.trace_id not in seen_refs:
            seen_refs.add(r.trace_id)
            basket_refs.append(r.trace_id)

    print("-" * 80)
    if codes:
        print(" Hata kodlari:")
        for c, txt in sorted(codes.items()):
            print("   %s = %s" % (c, txt or "(messages.py'de bulunamadi)"))
    print(" Hata sinyali tasiyan basket trace_id'leri: %s" % basket_refs)
    print(" Birini incele: BL_REF=<ref> BL_MODE=lifecycle")


def _log_dir():
    """Locate this project's server/logs dir (where diji.csv + module CSVs live)."""
    import os as _os
    # explicit override
    d = os.environ.get("BL_LOG_DIR", "").strip()
    if d and _os.path.isdir(d):
        return d
    try:
        from django.conf import settings
        for h in (getattr(settings, "LOGGING", {}).get("handlers", {}) or {}).values():
            fn = h.get("filename", "")
            if fn.endswith(".csv"):
                return _os.path.dirname(fn)
        base = str(getattr(settings, "BASE_DIR", ""))
        for cand in (_os.path.join(base, "server", "logs"), _os.path.join(base, "logs")):
            if _os.path.isdir(cand):
                return cand
    except Exception:
        pass
    return None


def raw_csv_fallback(terms):
    """Grep the raw CSV logs for `terms` when AppLog import is lagging.

    Returns a list of (file, line) matches. Reads the last ~4000 lines of each CSV
    (recent activity) to stay cheap. This catches errors that happened but haven't
    been imported into AppLog yet (LogReaderTask runs every 30 min).
    """
    import os as _os
    log_dir = _log_dir()
    if not log_dir:
        return None, []
    hits = []
    try:
        for name in sorted(_os.listdir(log_dir)):
            # .csv (flight/hotel/diji.csv) + rotated diji.csv.YYYY-MM-DD (no .csv suffix)
            if not (name.endswith(".csv") or name.startswith("diji.csv")):
                continue
            path = _os.path.join(log_dir, name)
            try:
                with open(path, "r", errors="replace") as f:
                    tail = f.readlines()[-4000:]
            except Exception:
                continue
            for ln in tail:
                if any(t in ln for t in terms):
                    hits.append((name, ln.rstrip("\n")))
    except Exception:
        pass
    return log_dir, hits


def mode_find():
    """BL_QUERY = a user-facing error message (or fragment) OR a COMxxx code.

    Finds matching AppLog rows across the last BL_DAYS days, resolves the code text,
    and maps each match to its basket reference — bridging "kullanici bir hata gosterdi,
    ref yok" to a concrete basket without manual scripts. Falls back to raw-CSV grep
    when AppLog has not imported the logs yet.
    """
    if not QUERY:
        print("# ERROR: BL_QUERY bos (aranan hata mesaji/kodu gerekli)")
        return
    now = _now()
    since, scope_label = _diag_since(now)

    # If QUERY itself is/contains a COMxxx code, resolve + also search by its English text.
    code_m = ERROR_CODE_RE.search(QUERY)
    search_terms = [QUERY]
    resolved = None
    if code_m:
        resolved = resolve_error_code(code_m.group(0))
        if resolved:
            search_terms.append(resolved)

    mq = Q()
    for t in search_terms:
        mq |= Q(message__icontains=t) | Q(data__icontains=t)

    qs = (AppLog.objects.filter(mq)
          .filter(created_at__gte=since)
          .exclude(logger=FRONTEND_LOGGER)
          .order_by("-created_at")[:LIMIT])

    rows = dedup(qs)
    print("=" * 80)
    print(" FIND — query=%r (%s)" % (QUERY, scope_label))
    if code_m:
        print(" kod %s = %s" % (code_m.group(0), resolved or "(messages.py'de yok)"))
    print(" eslesen kayit: %s" % len(rows))
    print("=" * 80)

    basket_refs = []
    seen = set()
    for r in rows:
        c = ERROR_CODE_RE.search(r.message or "")
        ref = r.trace_id if r.trace_type == "common.userbookingbasket" else ""
        print("%s | L%s | %s | %s=%s | %s%s" % (
            r.created_at.strftime("%m-%d %H:%M:%S"), r.level,
            r.logger.split(".")[-1][:22], r.trace_type.split(".")[-1][:14], r.trace_id,
            ("[%s] " % c.group(0)) if c else "", r.message[:130].replace("\n", " ")))
        if ref and ref not in seen:
            seen.add(ref)
            basket_refs.append(ref)

    print("-" * 80)
    print(" Eslesen basket reference'lari: %s" % basket_refs)
    if basket_refs:
        print(" Incele: BL_REF=%s BL_MODE=lifecycle" % basket_refs[0])

    # Fallback: AppLog'da 0 ise (import gecikmis olabilir) ham CSV'leri tara.
    if not rows:
        log_dir, hits = raw_csv_fallback(search_terms)
        print("-" * 80)
        print(" AppLog'da eslesme YOK — ham CSV fallback (import gecikmesi ihtimaline karsi)")
        if log_dir is None:
            print(" ! log dizini tespit edilemedi (BL_LOG_DIR ile elle ver)")
        elif not hits:
            print(" ham CSV'lerde de eslesme yok (%s). Bu ortamda hata olmamis olabilir —" % log_dir)
            print(" BASKA ORTAMI dene (prod yerine dev/stage; bkz SKILL.md ortam tablosu).")
        else:
            print(" ham CSV eslesmeleri (%s) — son %s:" % (log_dir, min(len(hits), 15)))
            csv_refs = []
            for fname, ln in hits[-15:]:
                m = re.findall(r'"([0-9A-Z]{8})"', ln)  # 8-char basket ref kolonu
                ref = next((x for x in m if x.isalnum() and not x.isdigit()), "")
                print("   [%s] %s" % (fname, ln[:200]))
                if ref and ref not in csv_refs:
                    csv_refs.append(ref)
            if csv_refs:
                print(" Ham CSV'den olasi basket ref'leri: %s" % csv_refs)
                print(" Incele: BL_REF=%s BL_MODE=lifecycle" % csv_refs[0])


# ---------------------------------------------------------------------------

def main():
    # Her arastirma oncesi logreader import tazeligini kontrol et (kural).
    try:
        logreader_health()
    except Exception as e:
        # health kontrolu asla ana analizi bloklamasin
        print("# WARN: logreader saglik kontrolu basarisiz: %s" % e)
        print("#" * 80)

    if MODE == "diagnose" and not REF:
        mode_diagnose()
        return
    if MODE == "find" or (QUERY and not REF):
        mode_find()
        return
    if not REF:
        print("# ERROR: BL_REF bos (lifecycle/provider/payment/raw icin gerekli). "
              "diagnose veya find modu ref'siz calisir.")
        return
    try:
        basket = get_basket(REF)
    except Exception as e:
        print("# ERROR: basket bulunamadi (%s): %s" % (REF, e))
        return

    handlers = {
        "lifecycle": mode_lifecycle,
        "provider": mode_provider,
        "payment": mode_payment,
        "raw": mode_raw,
    }
    handler = handlers.get(MODE, mode_lifecycle)
    handler(basket)


main()
