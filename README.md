# English Anki Preview (Android-only MVP)

AnkiDroid를 사용 중일 때, **오늘 볼 “새 카드(is:new)”를 앱에서 미리 익히는** Flutter(Android) 앱 MVP입니다.

중요: **AnkiWeb 직접 로그인/스크래핑은 하지 않습니다.**  
오직 **AnkiDroid 로컬 ContentProvider(`com.ichi2.anki.flashcards`)** 를 통해 로컬 DB 내용을 읽습니다.

## 기능(1차 MVP)
- Home: AnkiDroid 연결 상태 표시 + “학습 시작” 버튼
- 덱 선택: 학습 전 덱 1개 선택
- Study:
  - 상단: Total / Remaining
  - 상단: 회독/목표(덱별/오늘 기준, 디바이스 저장) + 목표 탭해서 수정
  - 카드 덱(겹겹이 스택, 최소 3장 레이어)
  - 카드 표시 설정(노트 타입별): 필드명 표시/숨김 + 폰트 크기 조절(디바이스 저장)
  - 앞면: 자동 TTS 1회, 탭 시 TTS 1회 + Y축 180도 플립(뒷면)
  - 뒷면: 탭(또는 오른쪽 스와이프)으로 다음 카드(Remaining 감소)
  - 완료 화면: “오늘 미리보기 완료” + 다시 시작/홈으로
- TTS: `flutter_tts` (기본 `en-US`, speechRate `0.5`)
- Anki 스케줄 변경: **MVP에서는 하지 않음(안전).**

## “오늘 새 카드 목록” 정의(MVP)
- Anki의 실제 “오늘 제시될 새 카드”는 덱 옵션(일일 제한/섞기 등)에 따라 달라질 수 있으므로,
- MVP는 **새 카드(카드 queue/type 기반) 중 상위 N개**를 “오늘 미리보기 대상”으로 보여줍니다.
- 기본 `N = 20` (`lib/src/state/home_controller.dart`의 `todayLimit`)

## AnkiDroid 연동(핵심)
### AndroidManifest 반영(필수)
`android/app/src/main/AndroidManifest.xml`에 다음이 포함되어 있습니다.
- 권한 선언:
  - `com.ichi2.anki.permission.READ_WRITE_DATABASE`
- Android 11+(API 30+) 패키지 가시성:
  - `<queries>`에 `com.ichi2.anki` package + `com.ichi2.anki.flashcards` provider

### Kotlin(MethodChannel) 구현
- Flutter ↔ Kotlin `MethodChannel('anki_provider')`
- Kotlin에서 `contentResolver.query(...)`로 AnkiDroid ContentProvider 조회
- 코드 위치:
  - `android/app/src/main/kotlin/com/example/englishankiapp/AnkiProviderClient.kt`
  - `android/app/src/main/kotlin/com/example/englishankiapp/MainActivity.kt`

## 프로젝트 구조(주요 파일 트리)
```
lib/
  main.dart
  src/
    app.dart
    models/
      anki_status.dart
      card_item.dart
    services/
      anki_native_api.dart
    state/
      home_controller.dart
      study_session_controller.dart
    ui/
      home_screen.dart
      study_screen.dart
      widgets/
        card_stack.dart
        swipe_flip_card.dart
    utils/
      html_sanitizer.dart

android/app/src/main/
  AndroidManifest.xml
  kotlin/com/example/englishankiapp/
    MainActivity.kt
    AnkiProviderClient.kt
    AnkiApiException.kt
```

## 실행 방법(에뮬레이터 데모 시나리오)
1. Android Studio → AVD 생성 (가능하면 **Google Play 포함** 이미지)
2. 에뮬레이터에서 AnkiDroid 설치
3. **AnkiDroid를 최소 1회 실행** → 로그인/동기화(또는 로컬 덱/카드 준비)
4. Flutter 앱 실행:
   - `flutter pub get`
   - `flutter run`
5. 앱 Home에서 상태가 OK가 되면 “학습 시작” → 카드 스택/플립/스와이프/TTS 확인

## 흔한 오류/해결
### 1) AnkiDroid 미설치
- Home에 “AnkiDroid 설치 필요”가 뜹니다.
- “Play Store로 이동” 버튼을 눌러 설치 후 다시 시도.

### 2) SecurityException / 접근 권한 문제
- “AnkiDroid API 접근 권한 필요” 안내가 뜹니다.
- 해결:
  - 앱에서 “권한 요청” 버튼을 눌러 시스템 권한 허용
  - AnkiDroid를 열고(가능하면 덱 화면까지 진입) 한 번 동기화
  - AnkiDroid 설정에서 API/권한 관련 옵션이 있다면 활성화
  - 다시 앱으로 돌아와 새로고침

### 3) 일부 환경에서 “AnkiDroid를 한 번 열어야” 동작
- Provider 쿼리가 실패하거나 카드가 0개로 나올 수 있습니다.
- AnkiDroid를 먼저 실행 → 동기화/덱 진입 후 다시 시도.

### 4) “데이터 조회 실패(ANKI_QUERY_FAILED)”가 계속 뜨는 경우
- 앱이 표시하는 오류 문구의 맨 아래 괄호(`(...)`) 안에 **상세 원인(details)** 이 같이 표시됩니다.
- 가장 흔한 원인 중 하나는 ContentProvider가 `LIMIT` 같은 SQL 조각을 허용하지 않는 경우인데, 현재 버전은 커서에서 직접 상위 N개만 읽도록 수정되어 있습니다.
- 여전히 실패하면:
  - AnkiDroid를 열어 동기화/덱 진입 후 재시도
  - AnkiDroid 버전 업데이트
  - (개발자용) `adb logcat | rg AnkiProviderClient`로 실제 예외 확인
