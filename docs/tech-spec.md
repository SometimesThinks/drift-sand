# drift-sand 기술 스펙 (v1)

기준 문서: [plan.md](plan.md), [spec.md](spec.md)

---

## 1. 스택·환경

| 항목 | 내용 |
|------|------|
| **프레임워크** | Flutter |
| **언어** | Dart 3.x (null safety) |
| **Flutter 버전** | 최신 안정 채널 기준. LTS 이슈 없으면 3.x 안정 버전 고정. |
| **1차 타깃** | Android (구글 플레이) → 2차 Windows, 3차 iOS |

---

## 2. 프로젝트 구조

- **레이아웃**: feature 단위 폴더 + **core·shared**로 공통 분리.
- **네이밍**: 파일·폴더는 `snake_case`. 클래스·위젯은 `PascalCase`. Dart 공식 스타일 따름.

```
lib/
  main.dart
  app.dart                    # MaterialApp, 라우팅, 테마
  core/                       # 앱 전역 설정, 상수
    constants.dart
    theme.dart
  features/
    timer/
      data/                  # 타이머 상태 소스, persistence(필요 시)
      domain/                # 타이머 로직(남은 시간 계산, 상태 전이)
      presentation/
        screens/              # 설정·실행·완료 화면
        widgets/              # 모래시계, 슬라이더 등
  shared/                     # 여러 feature에서 쓰는 위젯·유틸
    widgets/
    utils/
```

- <!-- TODO: data 레이어 persistence는 v1 미적용(spec §6.2). 구현 시 결정 후 위 data/ 주석 반영. -->
- **화면 매핑**: 설정/대기 = `SetupScreen`, 실행 = `RunningScreen`, 완료 = `FinishedScreen`. 라우팅 이름은 `/`, `/running`, `/finished` 등으로 통일. <!-- TODO: 라우팅 방식(go_router vs Navigator) 구현 시 결정. -->

---

## 3. 상태 관리

- **선택**: Riverpod (`flutter_riverpod` 패키지).
- **이유**: Flutter 권장에 가깝고, 테스트·의존성 주입이 쉬움. 단일 타이머 상태면 Provider 1~2개로 충분.
- **타이머 상태**: 다음을 보유하는 단일 Notifier(또는 StateNotifier) 권장.
  - `TimerStatus`: idle | running | paused | finished (spec §3.1과 동일)
  - `durationSeconds`: 설정된 총 시간(초)
  - `remainingSeconds`: 남은 시간(초)
  - `finishedAt`: 종료 알림을 울릴 시점(DateTime, 백그라운드 알람용)
- **UI는 이 상태를 구독**하고, 버튼·슬라이더는 상태 변경 메서드만 호출.
  - <!-- TODO: 재시작 시 직전 설정 시간 사용(spec §3.2). finished 상태에서 durationSeconds 유지 여부 구현 시 결정 후 이 문서 반영. -->

---

## 4. 백그라운드 타이머·알림

- **요구**: 앱이 백그라운드여도 타이머 종료 시점까지 경과가 유지되고, 종료 시 알림(소리·진동) 재생. (spec §6, §5)
- **전략**:
  1. **종료 시각 저장**: 타이머 시작/재개 시 `finishedAt = now + remainingSeconds` 계산 후 저장.
  2. **포그라운드**: `running`일 때 1초마다 `remainingSeconds = finishedAt - now` 로 갱신. `paused`에서는 `remainingSeconds` 고정.
  3. **일시정지 정책**: `paused` 진입 시 예약 알림 취소. `running` 재개 시 종료 시각 재계산 후 알림 재예약.
  4. **백그라운드**: OS 알람(또는 스케줄 작업)으로 **종료 시각에 한 번** 실행. 그 시점에 로컬 알림 + 소리·진동 재생.
  5. **정확도 보장**: 앱이 포그라운드로 돌아오면 `finishedAt` 기준으로 즉시 재계산해 정확한 남은 시간을 표시하고, 종료 시각이 이미 지났다면 즉시 완료 처리/알림을 수행. 플랫폼 제약으로 정확도 보장이 어려운 경우, 구현 단계에서 보완하고 본 문서를 갱신.
- **패키지**:
  - **Android**: `android_alarm_manager_plus` 또는 `workmanager`로 `finishedAt` 시각에 콜백 실행. 그 안에서 `flutter_local_notifications`로 알림 표시 + 소리·진동.
  - **iOS**: `flutter_local_notifications` + 스케줄 알림(날짜 지정). iOS 정책상 백그라운드 실행 제한 있으므로, “알림 예약” 위주로 구현 후 동작 검증.
  - **Windows (2차)**: 데스크톱은 백그라운드 제한이 덜하므로, 포그라운드 타이머 + 필요 시 플랫폼 알림 API 검토.
- **앱 재실행 시**: v1에서는 세션 복원 없음. 대기 화면부터 시작. 앱이 비정상 종료/강제 종료된 경우 기존 예약 알림은 **취소를 시도**하되, OS 정책상 취소가 보장되지 않을 수 있음을 명시. 타이머는 복구하지 않음. (spec §6.2)

---

## 5. 종료 알림 (소리·진동)

- **소리**: `audioplayers` 또는 `flutter_ringtone_player` 등으로 짧은 알림음 재생. 또는 `flutter_local_notifications` 채널에 사운드 연결.
- **진동**: `vibration` 또는 `flutter_vibrate`. Android는 Vibrator, iOS는 정책 확인 후 구현.
- **권한**: Android 알림 채널·진동 권한. iOS 알림·사운드 권한. 권한 요청 시 “타이머 종료 알림용” 문구 사용. (spec §5.3)

---

## 6. 광고

- **SDK**: Google AdMob. Flutter 패키지 `google_mobile_ads`.
- **노출**: 배너만. 하단 고정. (plan §4)
- **노출 화면**: v1에서는 대기/설정·완료 화면에서만. 실행 화면에서는 배너 숨김. (plan §4)
- **플랫폼**: 1차 Android에서 연동. Windows/iOS는 해당 플랫폼 출시 시 AdMob 지원 여부 확인 후 적용.

---

## 7. 모래시계 시각화

- **구현**: CustomPainter 또는 위젯 조합으로 “위쪽 모래 감소 / 아래쪽 모래 증가” 표현. 진행률(0~1)을 받아서 높이·클리핑으로 연동. (spec §4.1)
- **애니메이션**: `AnimationController` + `Tween` 또는 `CustomPainter` 내부에서 `progress` 값에 따라 그리기. 일시정지 시 애니메이션 정지. (spec §4.1, §4.2)
- **성능**: 1초 단위 갱신으로도 충분. 필요 시 0.1초 단위로 보간해 부드럽게 표현.

---

## 8. 플랫폼별 설정

| 플랫폼 | 최소 버전·비고 |
|--------|----------------|
| **Android** | minSdk 21 이상. 알림 채널, 진동, AdMob 적용. (1차) |
| **Windows** | 2차 출시. MS Store 패키징 시 요구사항 따름. |
| **iOS** | 3차. iOS 12 이상(또는 Flutter 권장 버전에 맞춤). 알림·사운드·진동 정책 확인. |

---

## 9. 빌드·배포

- **Android**: Release 빌드 후 AAB로 구글 플레이 업로드. 서명 키·키스토어 관리 별도.
- **버전 관리**: `pubspec.yaml`의 `version` 필드로 앱 버전 관리. (예: 1.0.0+1)
- **환경 변수**: AdMob 앱 ID 등은 `--dart-define` 또는 환경별 설정 파일로 분리. 리포지터리에 시크릿 커밋 금지.

---

## 10. 참고·비고

- **테스트**: 단위 테스트는 `domain`(타이머 로직, 남은 시간·상태 전이) 위주. 위젯 테스트는 핵심 화면·버튼 동작만.
- **오프라인**: v1에서는 네트워크 의존 최소(광고 로드 실패 시 빈 영역만 처리).
- 기술 스펙 변경 시 이 문서를 갱신하고, 큰 변경은 plan/spec과의 정합성 확인.
