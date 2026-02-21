@echo off
flutter run -d chrome ^
  --web-port=3000 ^
  --dart-define=WEB_SOCIAL_REDIRECT_URI=http://localhost:3000 ^
  --dart-define=GOOGLE_CLIENT_ID=666748471519-j64u791pkatfus7c3hu5fi98akuqv2bc.apps.googleusercontent.com ^
  --dart-define=GOOGLE_SERVER_CLIENT_ID=666748471519-j64u791pkatfus7c3hu5fi98akuqv2bc.apps.googleusercontent.com ^
  --dart-define=KAKAO_REST_API_KEY=91cad79c79703a53ac47994e328c2f13 ^
  --dart-define=KAKAO_NATIVE_APP_KEY=e5f10d7e9297ae72a3dd08a2d512a223 ^
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY=91cad79c79703a53ac47994e328c2f13
