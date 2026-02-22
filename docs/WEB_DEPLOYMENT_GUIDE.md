# ??諛고룷 媛?대뱶

## ????諛고룷 媛???щ?

**?? ?뱀뿉??諛고룷 媛?ν빀?덈떎!** Flutter???밸룄 吏?먰븯誘濡?釉뚮씪?곗??먯꽌 ?ㅽ뻾?????덉뒿?덈떎.

?꾩옱 ?꾨줈?앺듃?먮뒗 ?대? ???ㅼ젙???ы븿?섏뼱 ?덉뒿?덈떎:

- ??`web/` ?대뜑 議댁옱
- ??`index.html` ?ㅼ젙 ?꾨즺
- ??`manifest.json` (PWA ?ㅼ젙) ?꾨즺
- ???꾩씠肄??뚯씪 以鍮??꾨즺

## ?? 濡쒖뺄?먯꽌 ???ㅽ뻾

### 1. 媛쒕컻 紐⑤뱶濡??ㅽ뻾

```bash
# Chrome?먯꽌 ?ㅽ뻾
flutter run -d chrome

# ?먮뒗 湲곕낯 釉뚮씪?곗?
flutter run -d web-server
```

### 2. ?뱀젙 ?ы듃濡??ㅽ뻾

```bash
flutter run -d chrome --web-port=8080
```

## ?벀 ????鍮뚮뱶

### 媛쒕컻 鍮뚮뱶

```bash
flutter build web
```

鍮뚮뱶 寃곌낵臾??꾩튂: `build/web/`

### 由대━??鍮뚮뱶 (理쒖쟻??

```bash
flutter build web --release
```

由대━??鍮뚮뱶???ㅼ쓬 理쒖쟻?붾? ?ы븿?⑸땲??

- 肄붾뱶 ?뺤텞 諛?理쒖냼??
- ?몃━ ?먯씠??(?ъ슜?섏? ?딅뒗 肄붾뱶 ?쒓굅)
- ???묒? 踰덈뱾 ?ш린

### 異붽? 鍮뚮뱶 ?듭뀡

```bash
# Base URL ?ㅼ젙 (?쒕툕?붾젆?좊━??諛고룷 ??
flutter build web --base-href=/sync/

# ?뚯뒪留??ы븿 (?붾쾭源낆슜)
flutter build web --source-maps

# PWA 紐⑤뱶 (?쒕퉬???뚯빱 ?ы븿)
flutter build web --pwa-strategy=offline-first
```

## ?뙋 Nginx濡?????諛고룷

?꾩옱 ?꾨줈?앺듃???대? Nginx瑜??ъ슜?섍퀬 ?덉쑝誘濡? ???깆쓣 Nginx濡??쒕튃?????덉뒿?덈떎.

### 諛⑸쾿 1: Nginx??????異붽? (沅뚯옣)

`nginx/nginx.conf` ?뚯씪???섏젙?섏뿬 ???깆쓣 ?쒕튃?⑸땲??

```nginx
server {
    listen 80;
    server_name localhost;

    # API ?붿껌? FastAPI濡??꾨줉??
    location /api {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ?????뺤쟻 ?뚯씪 ?쒕튃
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        index index.html;
    }

    # ?뺤쟻 ?뚯씪 罹먯떛
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /usr/share/nginx/html;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 諛⑸쾿 2: Docker Compose?????쒕퉬??異붽?

`docker-compose.yml`?????쒕퉬?ㅻ? 異붽??⑸땲??

```yaml
services:
  # ... 湲곗〈 ?쒕퉬?ㅻ뱾 ...

  web:
    image: nginx:alpine
    container_name: sync_web
    ports:
      - "8080:80"
    volumes:
      - ./build/web:/usr/share/nginx/html:ro
      - ./nginx/web.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - nginx
    networks:
      - sync_network
```

## ?뱥 諛고룷 ?④퀎

### 1. ????鍮뚮뱶

```bash
# 由대━??鍮뚮뱶
flutter build web --release
```

### 2. 鍮뚮뱶 寃곌낵臾??뺤씤

`build/web/` ?대뜑???ㅼ쓬 ?뚯씪?ㅼ씠 ?앹꽦?⑸땲??

- `index.html`
- `main.dart.js` (?뺤텞??JavaScript)
- `flutter.js`
- `assets/` (?대?吏, ?고듃 ??
- `manifest.json`
- `favicon.png`

### 3. ?쒕쾭??諛고룷

#### ?듭뀡 A: Nginx濡?吏곸젒 ?쒕튃

```bash
# ?쒕쾭??鍮뚮뱶 寃곌낵臾?蹂듭궗
scp -r build/web/* user@server:/var/www/sync/

# Nginx ?ㅼ젙
# /etc/nginx/sites-available/sync
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/sync;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:8000;
        # ... ?꾨줉???ㅼ젙 ...
    }
}
```

#### ?듭뀡 B: Docker Compose濡?諛고룷

```bash
# 1. ????鍮뚮뱶
flutter build web --release

# 2. Docker Compose濡?諛고룷
docker-compose up -d
```

## ?뵩 ???ㅼ젙 ?뺤씤

### 1. API ?쒕쾭 二쇱냼 ?뺤씤

`lib/utils/api_client.dart`?먯꽌 ?쒕쾭 二쇱냼 ?뺤씤:

```dart
static const String baseUrl = 'http://192.168.1.102';
```

??諛고룷 ?쒖뿉??

- 媛쒕컻: `http://localhost` ?먮뒗 `http://192.168.1.102`
- ?꾨줈?뺤뀡: ?ㅼ젣 ?꾨찓???먮뒗 IP 二쇱냼

### 2. CORS ?ㅼ젙 ?뺤씤

諛깆뿏??`backend/app/main.py`?먯꽌 CORS ?ㅼ젙 ?뺤씤:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ?꾨줈?뺤뀡?먯꽌???뱀젙 ?꾨찓?몃쭔 ?덉슜
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 3. PWA ?ㅼ젙 (?좏깮?ы빆)

`web/manifest.json`?먯꽌 PWA ?ㅼ젙 ?뺤씤 諛??섏젙:

```json
{
  "name": "SYNC Project Manager",
  "short_name": "SYNC",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2"
}
```

## ?뙇 ?ㅼ뼇??諛고룷 ?듭뀡

### 1. ?뺤쟻 ?몄뒪???쒕퉬??

#### GitHub Pages

```bash
# 1. ??鍮뚮뱶
flutter build web --release --base-href=/SYNC/

# 2. build/web ?대뜑瑜?GitHub Pages??諛고룷
# GitHub ??μ냼 > Settings > Pages?먯꽌 ?ㅼ젙
```

#### Netlify

```bash
# 1. ??鍮뚮뱶
flutter build web --release

# 2. Netlify CLI濡?諛고룷
netlify deploy --prod --dir=build/web
```

#### Vercel

```bash
# 1. ??鍮뚮뱶
flutter build web --release

# 2. Vercel CLI濡?諛고룷
vercel --prod build/web
```

#### Firebase Hosting

```bash
# 1. Firebase CLI ?ㅼ튂
npm install -g firebase-tools

# 2. Firebase 珥덇린??
firebase init hosting

# 3. ??鍮뚮뱶
flutter build web --release

# 4. 諛고룷
firebase deploy --only hosting
```

### 2. ?먯껜 ?쒕쾭 諛고룷

#### Nginx ?ㅼ젙 ?덉떆

```nginx
server {
    listen 80;
    server_name sync.yourdomain.com;

    root /var/www/sync;
    index index.html;

    # SPA ?쇱슦??吏??
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API ?꾨줉??
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ?뺤쟻 ?뚯씪 罹먯떛
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip ?뺤텞
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

## ?뵍 HTTPS ?ㅼ젙 (?꾨줈?뺤뀡)

### Let's Encrypt ?ъ슜

```bash
# Certbot ?ㅼ튂
sudo apt-get install certbot python3-certbot-nginx

# SSL ?몄쬆??諛쒓툒
sudo certbot --nginx -d your-domain.com

# ?먮룞 媛깆떊 ?ㅼ젙
sudo certbot renew --dry-run
```

### Nginx HTTPS ?ㅼ젙

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # ... ?섎㉧吏 ?ㅼ젙 ...
}

# HTTP瑜?HTTPS濡?由щ떎?대젆??
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## ?㎦ ?뚯뒪??

### 濡쒖뺄 ?뚯뒪??

```bash
# 1. ??鍮뚮뱶
flutter build web --release

# 2. 濡쒖뺄 ?쒕쾭濡??뚯뒪??
cd build/web
python -m http.server 8080

# ?먮뒗
npx serve -s build/web -l 8080
```

### ?꾨줈?뺤뀡 ?뚯뒪??

1. 釉뚮씪?곗??먯꽌 ?묒냽: `http://your-domain.com`
2. 濡쒓렇???뚯뒪??
3. API ?곌껐 ?뺤씤
4. 紐⑤뱺 湲곕뒫 ?뚯뒪??

## ?벑 PWA (Progressive Web App) ?ㅼ젙

???깆쓣 PWA濡?留뚮뱾硫?

- ???붾㈃??異붽? 媛??
- ?ㅽ봽?쇱씤 吏??
- ?깆쿂???숈옉

### ?쒕퉬???뚯빱 ?쒖꽦??

```bash
flutter build web --pwa-strategy=offline-first
```

## ?뵇 臾몄젣 ?닿껐

### CORS ?ㅻ쪟

諛깆뿏?쒖뿉??CORS ?ㅼ젙 ?뺤씤:

```python
allow_origins=["http://your-domain.com", "https://your-domain.com"]
```

### ?쇱슦???ㅻ쪟 (404)

Nginx ?ㅼ젙?먯꽌 `try_files` ?뺤씤:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### API ?곌껐 ?ㅻ쪟

1. ?쒕쾭 二쇱냼 ?뺤씤 (`api_client.dart`)
2. CORS ?ㅼ젙 ?뺤씤
3. ?ㅽ듃?뚰겕 ?곌껐 ?뺤씤

## ?뱥 諛고룷 泥댄겕由ъ뒪??

- [ ] ??鍮뚮뱶 ?깃났 (`flutter build web --release`)
- [ ] API ?쒕쾭 二쇱냼 ?ㅼ젙 (`api_client.dart`)
- [ ] CORS ?ㅼ젙 ?뺤씤 (諛깆뿏??
- [ ] Nginx ?ㅼ젙 ?꾨즺
- [ ] HTTPS ?ㅼ젙 (?꾨줈?뺤뀡)
- [ ] ?꾨찓???ㅼ젙 (?좏깮?ы빆)
- [ ] 釉뚮씪?곗? ?뚯뒪???꾨즺
- [ ] 紐⑤컮??釉뚮씪?곗? ?뚯뒪???꾨즺

## ?뮕 ?붿빟

- ????諛고룷 媛??
- ??`flutter build web --release`濡?鍮뚮뱶
- ??Nginx濡??쒕튃 媛??
- ???뺤쟻 ?몄뒪???쒕퉬???ъ슜 媛??
- ??Windows, macOS, ??紐⑤몢 媛숈? 肄붾뱶 ?ъ슜
- ??媛숈? ?쒕쾭???곌껐?섏뿬 ?곗씠??怨듭쑀

## ?? 鍮좊Ⅸ ?쒖옉

```bash
# 1. ??鍮뚮뱶
flutter build web --release

# 2. 濡쒖뺄 ?뚯뒪??
cd build/web
python -m http.server 8080

# 3. 釉뚮씪?곗??먯꽌 http://localhost:8080 ?묒냽
```

??諛고룷媛 ?꾨즺?섎㈃ ?대뵒?쒕뱺 釉뚮씪?곗?濡??묒냽?섏뿬 ?ъ슜?????덉뒿?덈떎!
