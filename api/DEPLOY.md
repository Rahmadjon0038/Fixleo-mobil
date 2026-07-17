# Deploy (joylashtirish)

Butun stack **`docker-compose.yml`** orqali **`./deploy.sh`** bilan ishga tushadi:
**frontend (cline)** · **backend** · **postgres** · **redis** · **minio**.

Har bir e'lon qilingan (published) port **`BIND_IP` (default `127.0.0.1`)** ga
bog'lanadi — ya'ni hech narsa server tashqarisidan ko'rinmaydi. Old tomonga
**o'zingizning reverse proxy'ngizni** (nginx, Caddy, Traefik, …) qo'yib, faqat
kerakligini TLS bilan ochasiz. Redis umuman host'ga chiqmaydi (faqat docker
tarmog'ida).

## 1. Talablar

- Docker + docker compose plugin o'rnatilgan host.
- O'zingizning reverse proxy + TLS (bu repo proxy bilan kelmaydi).

## 2. `.env` ni sozlash

`.env.example` → `.env` ko'chiring va **haqiqiy** qiymatlarni qo'ying.
`docker-compose.yml` backend'ni `NODE_ENV=production` da ishga tushiradi — bu
holatda dev-placeholder sirlar bilan ilova **umuman ishga tushmaydi**:

```env
# Portlar — yagona manba (single source). Bir joyda o'zgartirsangiz hammasi ergashadi.
BIND_IP=127.0.0.1                            # faqat localhost; old tomonda proxy'ngiz
APP_PORT=8080                                # backend host porti
CLINE_PORT=5173                              # frontend host porti

CORS_ORIGINS=https://app.fixleo.com          # aniq ro'yxat — "*" EMAS
JWT_ACCESS_SECRET=<openssl rand -hex 32>     # kuchli, noyob
JWT_REFRESH_SECRET=<openssl rand -hex 32>    # access'dan farqli
DB_PASSWORD=<kuchli parol>
STORAGE_ACCESS_KEY=<kuchli kalit>
STORAGE_SECRET_KEY=<kuchli kalit>
STORAGE_PUBLIC_ENDPOINT=https://s3.fixleo.com   # mijoz KYC presigned linklarni ochadigan URL
DEFAULT_ADMIN_EMAIL=admin@fixleo.com
DEFAULT_ADMIN_PASSWORD=<kuchli parol>
SWAGGER_ENABLED=false
```

Sir generatsiya qilish: `openssl rand -hex 32`. `deploy.sh` `.env` ni hech qachon
o'zgartirmaydi — uni o'zingiz boshqarasiz.

## 3. Ishga tushirish

```bash
./deploy.sh            # to'liq build (backend + frontend) → migratsiya → up → health
# NO_CACHE=1 ./deploy.sh   # noldan qayta build qilish
```

Muvaffaqiyatli bo'lsa, reverse proxy'ngiz mo'ljallashi kerak bo'lgan ikkita
portni chiqaradi:

```
FRONTEND  -> 127.0.0.1:5173
BACKEND   -> 127.0.0.1:8080   (API: /api , docs: /api/docs)
```

Proxy'ngizni shularga yo'naltiring, masalan API uchun `proxy_pass http://127.0.0.1:8080;`,
konsol uchun `http://127.0.0.1:5173;`. Health: `GET /api/health` → DB, Redis va
storage ishlasa `200` (aks holda `503` — shunda load-balancerlar to'g'ri filtrlaydi).
Swagger production'da default o'chiq.

## 4. Ma'lumotlar bazasi zaxiralari (backup)

`scripts/backup-db.sh` vaqt-belgili, gzip qilingan `pg_dump` ni `./backups/` ga
oladi va `BACKUP_RETENTION_DAYS` (default 14) dan eski fayllarni tozalaydi.

```bash
./scripts/backup-db.sh                                 # bir martalik
./scripts/restore-db.sh ./backups/fixleo_<ts>.sql.gz   # tiklash (MA'LUMOTNI O'CHIRADI)
```

Har kuni cron orqali rejalashtirish:

```cron
0 2 * * * cd /opt/fixleo/backend && ./scripts/backup-db.sh >> /var/log/fixleo-backup.log 2>&1
```

Zaxiralarni host'dan tashqariga ko'chiring (S3, rsync) — faqat lokal zaxira disk
yo'qolsa saqlanmaydi.

## 5. Operatsiyalar

- **Loglar**: `docker compose logs -f backend`
- **Migratsiya** (qo'lda): `docker compose run --rm --no-deps backend npm run migration:run:prod`
- **Korrelyatsiya**: har bir javobda `X-Request-Id` bor; xatolar uni javob ichida
  qaytaradi — bug-report'da shuni keltiring.
- **Audit**: admin mutatsiyalari yoziladi — `GET /api/v1/admin/audit-logs`.
- **Rolling update**: `docker compose up -d --build backend`
  (graceful shutdown jarayondagi so'rovlarni tugatadi + DB/Redis/WS ni toza yopadi).
- **Masshtablash**: WS qatlami Redis adapter ishlatadi, shuning uchun backend proxy
  ortida bir nechta replikada ishlay oladi. `migrate deploy` ni har relizda bir
  marta ishlating, har replikada emas.

