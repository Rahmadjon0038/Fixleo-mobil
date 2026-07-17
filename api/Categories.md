# Xizmat kategoriyalari (Categories)

Reference (ma'lumotnoma) ma'lumotlari — masterlar o'z xizmatlarini taklif qilishda, mijozlar va buyurtmalar esa tanlashda shu kategoriyalardan foydalanadi. O'qish **public**, CRUD esa **admin**ga tegishli.

Base URL: `https://api.fixleo.com/api/v1`

> **Til:** barcha `message` (va validatsiya `errors[].message`) `Accept-Language` (uz / ru / en) bo'yicha tarjimalanadi — misollarda inglizcha keltirilgan. Umumiy format/qoidalar: `Backend Config for client.md`.

Barcha javoblar standart konvertda:

```json
{ "success": true, "message": "...", "data": {} }
```

Xatolar:

```json
{ "success": false, "message": "...", "statusCode": 404, "path": "...", "timestamp": "...", "requestId": "..." }
```

> Har bir javobda `X-Request-Id` header bo'ladi; xato konvertidagi `requestId` shu bilan bir xil — log/qo'llab-quvvatlash uchun korrelyatsiya id'si.

`CategoryResponseDto` maydonlari:

| Maydon      | Turi   | Izoh                                          |
| ----------- | ------ | --------------------------------------------- |
| `id`        | number | Raqamli id (masalan `1`)                      |
| `name`      | string | Kategoriya nomi                               |
| `order`     | number | Saralash tartibi — o'sish bo'yicha (ascending) |
| `createdAt` | string | ISO sana                                      |
| `updatedAt` | string | ISO sana                                      |

> **Admin route'lari** (`/admin/categories`) admin token talab qiladi (qarang `AdminLogin.md`): `Authorization: Bearer <admin accessToken>`. `admin` va `superadmin` rollarining ikkalasi ham kira oladi.
>
> **Public route'lari** (`/categories`) auth talab qilmaydi.

---

## 🔄 Jarayon sxemasi (workflow)

```mermaid
flowchart TD
    Start(["📱 Client / Master / Admin"]):::start
    Start --> Kind{"o'qish yoki yozish ?"}:::decide

    subgraph PUB["🌐 Public (auth talab qilmaydi)"]
        Read["GET /categories<br/>GET /categories/:id"]:::action
        Found{"kategoriya topildimi ?"}:::decide
        Ok200(["✅ 200<br/>ro'yxat / detallar<br/>(order asc)"]):::ok
        NotFoundR(["❌ 404<br/>category_not_found"]):::bad
        Read --> Found
        Found -->|"ha"| Ok200
        Found -->|"yo'q"| NotFoundR
    end

    subgraph ADM["👤 Admin (/admin/categories)"]
        Auth{"🔒 admin token bormi ?"}:::decide
        Unauthorized(["❌ 401<br/>token_missing"]):::bad
        Op{"POST / PATCH / DELETE ?"}:::decide
        Exists{"kategoriya bor ?"}:::decide
        NotFoundW(["❌ 404<br/>category_not_found"]):::bad
        Unique{"nom band emasmi ?"}:::decide
        Conflict(["❌ 409<br/>category_name_conflict"]):::bad
        Created(["✅ 201<br/>category_created"]):::ok
        Updated(["✅ 200<br/>category_updated"]):::ok
        Deleted(["✅ 200<br/>category_deleted"]):::ok

        Auth -->|"yo'q"| Unauthorized
        Auth -->|"🔑 ha"| Op
        Op -->|"POST"| Unique
        Op -->|"PATCH"| Exists
        Op -->|"DELETE"| Exists
        Exists -->|"yo'q"| NotFoundW
        Exists -->|"PATCH"| Unique
        Exists -->|"DELETE"| Deleted
        Unique -->|"band"| Conflict
        Unique -->|"POST ok"| Created
        Unique -->|"PATCH ok"| Updated
    end

    Kind -->|"read"| Read
    Kind -->|"write"| Auth

    classDef start fill:#eef2ff,stroke:#6366f1,stroke-width:2px,color:#312e81;
    classDef action fill:#e0f2fe,stroke:#0ea5e9,stroke-width:1.5px,color:#0c4a6e;
    classDef ok fill:#dcfce7,stroke:#22c55e,stroke-width:1.5px,color:#14532d;
    classDef bad fill:#fee2e2,stroke:#ef4444,stroke-width:1.5px,color:#7f1d1d;
    classDef wait fill:#fef9c3,stroke:#eab308,stroke-width:1.5px,color:#713f12;
    classDef decide fill:#ffedd5,stroke:#f97316,stroke-width:1.5px,color:#7c2d12;
    classDef muted fill:#f1f5f9,stroke:#94a3b8,stroke-width:1.5px,color:#334155;
```

---

## 1. Kategoriyalar ro'yxati (public)

`GET /categories`

Auth shart emas. Barcha kategoriyalar `order` bo'yicha (o'sish) qaytadi.

**Response `200`:**

```json
{
  "success": true,
  "message": "Categories list",
  "data": [
    {
      "id": 1,
      "name": "Сантехника",
      "order": 0,
      "createdAt": "2026-06-14T00:00:00.000Z",
      "updatedAt": "2026-06-14T00:00:00.000Z"
    },
    {
      "id": 2,
      "name": "Электрика",
      "order": 1,
      "createdAt": "2026-06-14T00:00:00.000Z",
      "updatedAt": "2026-06-14T00:00:00.000Z"
    }
  ]
}
```

> Ro'yxat odatda kichik (10–20 ta), shuning uchun **pagination yo'q** — to'liq massiv qaytadi.

---

## 2. Bitta kategoriyani ko'rish (public)

`GET /categories/:id`

Auth shart emas.

**Response `200`:**

```json
{
  "success": true,
  "message": "Category details",
  "data": {
    "id": 1,
    "name": "Сантехника",
    "order": 0,
    "createdAt": "2026-06-14T00:00:00.000Z",
    "updatedAt": "2026-06-14T00:00:00.000Z"
  }
}
```

**Xatolar:**

| Kod | Sabab                | Izoh                    |
| --- | -------------------- | ----------------------- |
| 404 | Kategoriya topilmadi | `Category #1 not found` |

---

## 3. Kategoriya yaratish (admin)

`POST /admin/categories`

Admin token talab qilinadi. `name` **unique** bo'lishi shart.

**Request:**

```json
{
  "name": "Сантехника",
  "order": 0
}
```

| Maydon  | Majburiy | Qoidalar                                       |
| ------- | -------- | ---------------------------------------------- |
| `name`  | ✅       | 2–100 belgi. Unique bo'lishi shart             |
| `order` | ❌       | Butun son, `≥ 0`. Berilmasa default `0`        |

**Response `201`:**

```json
{
  "success": true,
  "message": "Category created",
  "data": {
    "id": 3,
    "name": "Сантехника",
    "order": 0,
    "createdAt": "2026-06-14T00:00:00.000Z",
    "updatedAt": "2026-06-14T00:00:00.000Z"
  }
}
```

**Xatolar:**

| Kod | Sabab                                  | Izoh                                          |
| --- | -------------------------------------- | --------------------------------------------- |
| 400 | Validatsiya — `name` majburiy/qisqa    | validatsiya xabari                            |
| 401 | Admin token yo'q / noto'g'ri           | `Access token is missing`                     |
| 409 | Shu nomli kategoriya allaqachon mavjud | `A category named "Сантехника" already exists` |

---

## 4. Kategoriyani tahrirlash — qisman (admin)

`PATCH /admin/categories/:id`

Admin token talab qilinadi. Faqat **yuborilgan maydonlar** o'zgaradi.

**Request (masalan, faqat nom):**

```json
{ "name": "Электрика" }
```

| Maydon  | Qoidalar                            |
| ------- | ----------------------------------- |
| `name`  | 2–100 belgi. Unique bo'lishi shart  |
| `order` | Butun son, `≥ 0`                    |

**Response `200`:**

```json
{
  "success": true,
  "message": "Category updated",
  "data": {
    "id": 3,
    "name": "Электрика",
    "order": 0,
    "createdAt": "2026-06-14T00:00:00.000Z",
    "updatedAt": "2026-06-14T00:10:00.000Z"
  }
}
```

**Xatolar:**

| Kod | Sabab                          | Izoh                                         |
| --- | ------------------------------ | -------------------------------------------- |
| 400 | Validatsiya (`name`/`order`)   | validatsiya xabari                           |
| 401 | Admin token yo'q / noto'g'ri   | `Access token is missing`                    |
| 404 | Kategoriya topilmadi           | `Category #3 not found`                      |
| 409 | Shu nom allaqachon band        | `A category named "Электрика" already exists` |

---

## 5. Kategoriyani o'chirish (admin)

`DELETE /admin/categories/:id`

Admin token talab qilinadi.

**Response `200`:**

```json
{ "success": true, "message": "Category deleted", "data": null }
```

**Xatolar:**

| Kod | Sabab                          | Izoh                      |
| --- | ------------------------------ | ------------------------- |
| 401 | Admin token yo'q / noto'g'ri   | `Access token is missing` |
| 404 | Kategoriya topilmadi           | `Category #3 not found`   |

---

## Endpointlar xulosasi

| Method   | Route                    | Auth   | Vazifa             | Message           |
| -------- | ------------------------ | ------ | ------------------ | ----------------- |
| `GET`    | `/categories`            | public | Ro'yxat            | `Categories list` |
| `GET`    | `/categories/:id`        | public | Bitta kategoriya   | `Category details`|
| `POST`   | `/admin/categories`      | admin  | Yaratish (`201`)   | `Category created`|
| `PATCH`  | `/admin/categories/:id`  | admin  | Qisman tahrirlash  | `Category updated`|
| `DELETE` | `/admin/categories/:id`  | admin  | O'chirish          | `Category deleted`|

Swagger: `https://api.fixleo.com/api/docs` ("Categories" va "Admin: Categories" bo'limlari).
