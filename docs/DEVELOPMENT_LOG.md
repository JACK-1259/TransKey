# TransKey 개발 기록

개발하면서 만난 문제를 **증상 → 원인 → 해결 → 배운 점** 순서로 정리했어요.
최근 기록이 위에 있어요.

| # | 문제 | 분류 | 단계 |
|---|---|---|---|
| 8 | [한글 입력이 기본 키보드보다 버벅임](#8-한글-입력이-기본-키보드보다-버벅임) | 성능 | 실기기 테스트 |
| 7 | [실기기에서 번역이 전혀 안 됨 (TranslationErrorDomain#1)](#7-실기기에서-번역이-전혀-안-됨-translationerrordomain1) | 번역 | 실기기 테스트 |
| 6 | [무료 개발자 계정으로는 App Group 서명이 안 됨](#6-무료-개발자-계정으로는-app-group-서명이-안-됨) | 서명·배포 | 실기기 테스트 |
| 5 | [번역 언어가 영어·일본어·스페인어로 고정됨](#5-번역-언어가-영어일본어스페인어로-고정됨) | 기능 확장 | 기능 개발 |
| 4 | [시뮬레이터에서 Apple 번역이 동작하지 않음](#4-시뮬레이터에서-apple-번역이-동작하지-않음) | 개발 환경 | 기능 개발 |
| 3 | [Swift 6에서 TranslationSession을 넘기면 컴파일 오류](#3-swift-6에서-translationsession을-넘기면-컴파일-오류) | 동시성 | 기능 개발 |
| 2 | [키보드가 뜨자마자 크래시](#2-키보드가-뜨자마자-크래시) | 크래시 | 초기 구현 |
| 1 | [시뮬레이터에서 화면 키보드가 안 올라옴](#1-시뮬레이터에서-화면-키보드가-안-올라옴) | 개발 환경 | 초기 구현 |

---

## 8. 한글 입력이 기본 키보드보다 버벅임

**증상**
실기기(iPhone 16, iOS 27)에서 한글을 빠르게 치면 기본 키보드보다 반응이 느리게 느껴졌어요.

**원인** (세 가지가 겹쳐 있었어요)
1. **화면 가장자리 터치 지연**: iOS는 화면 좌우 끝과 맨 아래에서 시스템 제스처(뒤로 가기, 홈)를 먼저 확인하느라
   키보드 터치를 잠깐 붙잡아 둬요. 그래서 ㅂ·ㅔ·ㅁ·ㅣ 같은 끝 키와 스페이스 줄이 늦게 반응했어요.
2. **키 하나당 처리가 많음**: 글자를 넣을 때마다 번역 요청 준비, 리턴 키 갱신, 키보드 높이 재계산을 즉시 했고,
   iOS가 "텍스트가 바뀌었다"고 다시 알려줄 때(`textDidChange`) 같은 일을 한 번 더 했어요.
3. **개발용(Debug) 빌드**: 최적화가 꺼진 빌드로 시험하고 있었어요.

**해결** — [`KeyboardViewController.swift`](../Keyboard/Controller/KeyboardViewController.swift)
```swift
// 1) 창의 제스처 인식기가 터치를 지연시키지 않게 한다.
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
}

// 2) 키 입력 직후 꼭 필요하지 않은 일은 다음 실행 주기로 미루고, 여러 번 요청돼도 한 번만 처리한다.
private func scheduleDeferredUpdates() {
    guard !hasPendingDeferredUpdates else { return }
    hasPendingDeferredUpdates = true
    DispatchQueue.main.async { [weak self] in
        self?.hasPendingDeferredUpdates = false
        self?.updateReturnKey()
        self?.scheduleTranslation()
    }
}
```
3. 보안 입력창 여부가 **바뀌었을 때만** 키보드 높이를 다시 계산하도록 바꿨어요.
4. 체감 속도는 최적화된 Release 빌드로 확인했어요.

**결과**: 실기기에서 "훨씬 빨라졌다"는 체감을 확인했어요.

**배운 점**: 키보드 익스텐션은 키 입력 처리(touch → insertText)를 최대한 짧게 끝내야 해요.
부가 작업은 미루고 합쳐서 처리하고, 성능은 반드시 Release 빌드와 실기기로 판단해야 해요.

---

## 7. 실기기에서 번역이 전혀 안 됨 (TranslationErrorDomain#1)

**증상**
앱에서 언어 팩은 "설치됨"인데, 키보드에서 "사과"를 입력하면 영어·일본어·다른 언어 모두 번역 칩이 뜨지 않았어요.
(실패한 칩은 숨기도록 만들어 둬서 화면에는 아무것도 안 보였어요.)

**진단 과정**
1. 실기기 로그는 관리자 권한(sudo)이 필요해서, 대신 **개발용(Debug) 빌드에서만 실패 원인을 칩에 빨간 글씨로 보여주도록** 바꿨어요.
2. 앱 안에서 같은 번역 코드를 실행해 보는 **"번역 테스트" 버튼**도 넣었어요.
   (앱에서는 되는데 키보드에서만 안 되면 키보드 익스텐션 제약, 둘 다 안 되면 언어 팩·기기 문제로 구분하기 위해서예요.)
3. 결과는 `TranslationErrorDomain#1`. 그런데 Apple 번역은 오류 종류가 달라도 **코드가 모두 1**이라 번호만으로는 원인을 알 수 없었어요.

**원인**
키보드는 빠른 응답을 위해 iOS 26.4의 **저지연 모드**(`preferredStrategy: .lowLatency`)로 번역하고 있었어요.
반면 앱에서 받은 언어 팩과 "설치됨" 확인(`LanguageAvailability`)은 **기본 모드** 기준이었어요.
그래서 설치 확인은 통과했지만 실제 번역 단계에서 실패했어요.

**해결** — [`AppleOnDeviceProvider.swift`](../Packages/TransKeyCore/Sources/TransKeyCore/Translation/AppleOnDeviceProvider.swift)
```swift
// Before: 저지연 모드
session = TranslationSession(installedSource: source, target: target, preferredStrategy: .lowLatency)
// After: 언어 팩과 같은 기본 모드
let session = TranslationSession(installedSource: source, target: target)
```
- 프레임워크 오류를 종류별로 구분해서(`notInstalled` → "언어 팩 받기" 안내, 미지원 언어 → 미지원) 처리하고,
  나머지는 `"종류 (도메인#코드): 설명"` 형태로 남기도록 했어요. 사용자 원문은 담지 않아요.
- 첫 번역 때 기기가 번역 모델을 불러오는 시간을 고려해 키보드의 번역 타임아웃을 3초 → 10초로 늘렸어요.

**결과**: 실기기에서 한국어 → 영어·일본어 번역이 정상 동작해요.

**배운 점**: 처음부터 가장 큰 위험이었던 "키보드 익스텐션 안에서 Apple 번역이 동작하는가"는 **동작한다**로 확인됐어요.
실패를 사용자에게 숨기는 UI는 좋지만, 개발 중에는 원인을 볼 수 있는 진단 경로를 꼭 함께 만들어야 해요.

---

## 6. 무료 개발자 계정으로는 App Group 서명이 안 됨

**증상**
```
Provisioning profile "iOS Team Provisioning Profile: com.jack1259.transkey" doesn't match
the entitlements file's value for the com.apple.security.application-groups entitlement.
```

**원인**
무료 개인 팀(Personal Team)은 App Group 권한을 프로비저닝 프로필에 넣을 수 없어요.
또 예시용 번들 ID(`com.example.transkey`)는 Apple에 등록할 수 없었어요.

**해결**
- 번들 ID와 App Group을 `com.jack1259.transkey`, `group.com.jack1259.transkey`로 변경했어요.
- 프로젝트 파일은 그대로 두고, 무료 계정 실기기 빌드에서만 엔타이틀먼트를 비워서 설치했어요.
  ```bash
  xcodebuild -scheme TransKey -configuration Release \
    -destination 'id=<기기 UDID>' DEVELOPMENT_TEAM=<팀 ID> \
    CODE_SIGN_ENTITLEMENTS= -allowProvisioningUpdates build
  ```
- 개인 Team ID는 공개 저장소에 올리지 않도록 프로젝트 파일이 아닌 빌드 옵션으로만 넘겼어요.

**남은 제한**: 이 방식에서는 앱 설정이 키보드에 공유되지 않아요(키보드는 기본값으로 동작). 유료 개발자 계정이 필요해요.

---

## 5. 번역 언어가 영어·일본어·스페인어로 고정됨

**증상**
번역 대상 언어가 코드에 enum으로 고정돼 있어서 다른 언어를 추가할 수 없었어요.

**해결**
- `Language`를 enum에서 **BCP-47 문자열 기반 구조체**로 바꿨어요. 저장 형식은 그대로 `"en"` 같은 문자열이라 기존 설정과 호환돼요.
- 기기의 Apple 번역이 지원하는 언어 목록(`LanguageAvailability().supportedLanguages`, 약 20개)을 실시간으로 받아와요.
- **번역 언어 화면**: 언어 팩이 설치된 언어는 토글로 켜고(최대 3개), 없는 언어는 "받기" 버튼으로 받아요.
- 언어 팩은 아이폰 전체가 공유해서, 번역 앱 등 다른 곳에서 받은 언어 팩도 앱으로 돌아오면 자동으로 인식해요.
- 온보딩의 언어 팩 단계에서도 **"다른 언어도 받기"** 버튼으로 같은 화면을 열 수 있어요.

---

## 4. 시뮬레이터에서 Apple 번역이 동작하지 않음

**증상**
시뮬레이터에서는 모든 언어 쌍이 "지원 안 함"으로 나왔어요. 시스템 로그에도
`Translation isn't supported on the current device`가 남았어요.

**해결**
화면 흐름을 시뮬레이터에서도 확인할 수 있도록, **시뮬레이터 빌드에서만** 단어 15개짜리 데모 사전
(`SimulatorDemoProvider`)으로 폴백하게 했어요. 실기기 빌드에는 포함되지 않아요.

```swift
#if targetEnvironment(simulator)
FallbackTranslationProvider(primary: AppleOnDeviceProvider(), secondary: SimulatorDemoProvider())
#else
AppleOnDeviceProvider()
#endif
```

---

## 3. Swift 6에서 TranslationSession을 넘기면 컴파일 오류

**증상**
```
error: sending 'session' risks causing data races
```

**원인**
`TranslationSession`은 Sendable이 아니에요. SwiftUI의 `.translationTask` 클로저(MainActor)에서 받은 세션을
비격리(nonisolated) 비동기 함수에 넘기면, Swift 6의 데이터 레이스 검사에 걸려요.

**해결**
클로저를 `@concurrent`로 만들어 세션을 처음부터 끝까지 비격리 컨텍스트 안에서만 다루고,
결과만 `@MainActor` 뷰모델로 넘겼어요.

```swift
.translationTask(model.configuration) { @concurrent [model] session in
    try? await session.prepareTranslation()
    await model.finishPreparation(...)
}
```

---

## 2. 키보드가 뜨자마자 크래시

**증상**
TransKey로 전환하면 키보드가 잠깐 보였다가 시스템 키보드로 되돌아갔어요. 빌드는 정상이었어요.

**원인** (시스템 로그)
```
Fatal error: Use of unimplemented initializer 'init(nibName:bundle:)' for class 'KeyboardViewController'
```
테스트용 의존성 주입 이니셜라이저(`init(settingsStore:)`)를 추가하면서, 시스템이 키보드를 띄울 때 호출하는
`init(nibName:bundle:)`이 상속되지 않게 됐어요.

**해결**
```swift
override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    self.settingsStore = UserDefaultsSettingsStore()
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
}
```

**배운 점**: 컴파일은 통과하는 오류라, 실제로 키보드를 띄워 보지 않았다면 놓쳤을 문제예요.

---

## 1. 시뮬레이터에서 화면 키보드가 안 올라옴

**증상**
iPhone 18 Pro 시뮬레이터에서만 TransKey는 물론 시스템 키보드도 안 올라왔어요.

**원인**
맥 키보드로 시뮬레이터에 직접 타이핑하면 iOS가 "외장 키보드가 연결됐다"고 기억하고 화면 키보드를 숨겨요
(`HardwareKeyboardLastSeen`). TransKey 버그가 아니었어요.

**해결**
시뮬레이터 창에서 **⌘K**(I/O › Keyboard › Toggle Software Keyboard)로 다시 띄우거나,
시뮬레이터를 끈 상태에서 해당 설정 값을 지웠어요.
