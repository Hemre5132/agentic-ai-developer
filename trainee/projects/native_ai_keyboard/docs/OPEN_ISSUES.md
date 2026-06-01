# Open issues (native_ai_keyboard)

Bilinen, henüz kapatılmamış veya takip edilmesi gereken konular. Kapatıldığında maddeyi güncelle veya bu dosyadan kaldır.

---

## 1. Sorun bildirimi: Resend e-postası gelmiyor (DB kaydı oluşuyor)

**Durum:** Açık — `issue_reports` satırı oluşuyor; Edge yanıtında `mailSent` / `mailDetail` veya Resend tarafında teslimat net değil.

**Olası nedenler (kontrol listesi):**

- Supabase **Edge Secrets:** `RESEND_API_KEY`, `REPORT_TO_EMAIL` tanımlı mı? (`supabase secrets list`)
- **`onboarding@resend.dev`** (varsayılan `RESEND_FROM`) ile Resend çoğu senaryoda yalnızca **Resend hesabı e-postasına** teslim eder; `REPORT_TO_EMAIL` farklıysa kutuda görünmeyebilir.
- Kalıcı çözüm: Resend’de **domain doğrulama** + `RESEND_FROM` olarak o domainden adres.
- Spam / Promotions; Resend **Dashboard → Emails / Logs**.

**Teknik referans:**

- Edge: [`supabase/functions/submit-issue-report/index.ts`](../supabase/functions/submit-issue-report/index.ts) — `mailDetail`, `console.log` / `console.warn` logları.
- Dokümantasyon: [`supabase/functions/README.md`](../supabase/functions/README.md) (Secrets + “Mail gelmiyorsa”).

**Sonraki adımlar (isteğe bağlı):**

- [ ] `REPORT_TO_EMAIL`’i Resend kayıt e-postası ile eşleştirip bir rapor daha dene.
- [ ] Domain + `RESEND_FROM` ile uçtan uca doğrula.
- [ ] İstenirse: uygulama içinde başarılı cevapta `mailSent == false` iken kullanıcıya kısa bilgi (şu an yalnızca DB güvencesi var).

---

## Yeni madde eklerken

Kısa başlık, durum (Açık / İzleniyor), gözlemlenen davranış, ilgili dosya yolu ve bir kontrol listesi yeterli.
