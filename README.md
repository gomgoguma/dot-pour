# Dot Pour

TIMEMORE Black Mirror Dot(TES017)과 BLE로 연결해 목표 물량 대비 추출 진행률을 보여주는 Flutter 앱입니다.

**개발 중인 프로토타입입니다. 실제 도트 연결 및 Android/iOS 기기 검증은 아직 완료하지 않았습니다.**

## 사용 방법

1. 도트를 켜고 기존에 연결된 앱을 종료합니다.
2. **도트 연결**에서 기기를 선택합니다. Android에서는 근처 기기 권한을 허용합니다. Android 11 이하는 위치 권한과 위치 서비스가 필요할 수 있습니다.
3. 서버, 드리퍼, 필터, 원두를 모두 저울 위에 올립니다.
4. 원두량과 비율을 입력하고 **추출 시작**을 누릅니다.
5. 시작 시점의 무게를 기준으로 부은 물의 진행률을 표시합니다. 물이 0.5g 이상 증가한 두 번의 측정 후 앱 타이머가 시작됩니다.
6. 추출이 끝나면 **추출 마치기**를 누릅니다.

원두 20g, 비율 1:16이면 목표는 320g입니다. 물 160g → 50%, 320g → 100%, 352g → 110%로 표시합니다.

저울 없이 **데모로 체험**에서 물량 슬라이더 또는 자동 붓기를 사용할 수 있습니다. 데모는 실제 BLE 통신 검증을 대신하지 않습니다.

추출 중에는 용기와 드리퍼를 저울에서 빼거나 영점을 변경하지 않습니다. 서버만 저울에 놓으면 투입한 물 대신 서버에 모인 음료 무게를 측정하게 됩니다. 목표 물량과 별개로 용기를 포함한 전체 무게가 저울 용량 이내여야 합니다.

## 개발 환경

- Flutter 3.29.3 / Dart 3.7.2 이상
- `bluetooth_low_energy` 6.1.0: Android / iOS / Windows 네이티브 BLE
- `shared_preferences`: 마지막 원두량과 비율 저장
- `wakelock_plus`: 추출 중 화면 켜짐 유지

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Android는 Android SDK, NDK 27.0.12077973 및 라이선스 설정이 필요합니다. Java는 `jlink`를 포함하는 **정식 JDK 17**을 사용합니다. IDE에 포함된 경량 Java 런타임은 빌드에 필요한 도구가 없을 수 있습니다. 실제 BLE는 실물 기기에서 테스트합니다.

```sh
flutter run -d <android-device-id>
flutter build apk --debug
```

Windows에서 다른 Java 버전이 기본으로 선택되는 경우, 빌드할 터미널의 `JAVA_HOME`을 JDK 17 설치 폴더로 설정한 뒤 실행합니다. 시스템 전역 설정을 변경할 필요는 없습니다.

iOS는 macOS, Xcode, 서명 설정과 실물 iPhone이 필요합니다. Windows에서 iOS 빌드나 기기 테스트를 할 수는 없습니다.

```sh
flutter build ios --no-codesign
```

Windows 빌드에는 Visual Studio C++ 빌드 도구가 필요합니다. Flutter 플러그인 링크 오류가 발생하면 Windows 개발자 모드를 사용하거나 `powershell -File tool/windows-plugin-links.ps1`로 프로젝트 내부에 junction을 생성할 수 있습니다. 링크를 만든 뒤 **`flutter pub get`을 다시 실행**해 네이티브 플러그인 등록까지 완료합니다.

## 동작과 제한

- 비율·원두량은 추출 시작 시 고정합니다. 목표 도달 후에도 계속 측정합니다.
- 타이머는 앱에서 동작합니다. 저울 타이머와 동기화하지 않습니다.
- 연결 시 저울의 g 단위 설정에 대한 응답을 확인합니다.
- 시작 시 앱 내부 기준 무게를 잡습니다. 저울의 **영점 맞추기**는 별도 기능이며 추출 전만 사용합니다.
- 연결 해제, 2초 이상 데이터 중단, 과부하, 시작 무게 대비 2g 이상 감소 시 세션을 중단합니다. 중단한 세션은 자동 재개하지 않습니다.
- 화면을 켠 채 사용하는 것을 기준으로 합니다. 백그라운드 연결 유지, 추출 이력, 레시피 단계, 자동 재연결은 아직 구현하지 않았습니다.
- 도트의 기본 BLE 서비스와 모델 정보를 검사합니다. 펌웨어에 따른 응답·페어링 차이는 실기기 검증이 필요합니다.
- 수신 CRC가 0인 reserved 필드를 허용하며, 0이 아닌 CRC는 검증합니다. 실제 펌웨어 수신 프레임은 아직 캡처하지 않았습니다.

## 코드 구조

- `lib/timemore_protocol.dart`: 프레임 인코딩, CRC, 스트림 디코딩
- `lib/dot_scale.dart`: 검색, 연결, 알림 수신, 단위·영점 명령
- `lib/brew_session.dart`: 비율 계산과 추출 상태
- `lib/main.dart`: 한국어 UI와 데모
- `test/`: 프로토콜, 계산, 화면 흐름 검증

Windows 실행 파일을 전달할 때는 `Release` 폴더 전체가 필요합니다. Android debug APK는 개발 테스트용이며 스토어 배포용 서명이 아닙니다.

## 검증 현황

- `flutter analyze`: 문제 없음
- `flutter test`: 12개 통과 (계산, 프로토콜, 모바일 크기 데모 화면)
- Windows release 빌드: 성공, 네이티브 BLE 플러그인 DLL 포함
- Android debug APK 빌드: 성공 (JDK 17, NDK 27)
- Windows 데모 화면: 진행률 표시 확인
- 실제 도트 통신과 iOS 빌드·실행: 미검증
