<div align="center">

# Mission Control Labels

macOS Mission Control의 모든 창 위에 **제목과 앱 이름을 항상 표시**하는 메뉴바 앱입니다.

[English](README.md) · **한국어**

![Mission Control 위에 표시된 라벨](design/readme-hero.png)

</div>

## 소개

Mission Control은 창을 한눈에 펼쳐 보여주지만, 어떤 창인지는 마우스를 올려야 알 수 있습니다. Mission Control Labels는 Mission Control이 열려 있는 동안 **모든 창에 제목과 앱 이름을 표시**합니다. 원래의 창 선택, 드래그, Esc, Spaces 이동은 그대로 동작합니다.

- 손쉬운 사용(Accessibility) 권한만 사용합니다. 화면 기록 권한, SIP 해제, 비공개 API를 쓰지 않습니다.
- 라벨은 클릭을 통과시키므로 Mission Control 조작을 방해하지 않습니다.
- 창 제목을 기록하거나 외부로 전송하지 않습니다.

## 주요 기능

![라벨 구조](design/readme-label-closeup.png)

- **제목 우선 표시** — 1줄에 창 제목, 2줄에 앱 이름. 제목이 없으면 앱 이름만 표시합니다.
- **위치 선택** — 중앙, 왼쪽 위, 오른쪽 위, 왼쪽 아래, 오른쪽 아래 중 메뉴에서 고를 수 있습니다.
- **VS Code 워크스페이스 우선** — VS Code, Cursor, Windsurf 등은 1줄에 워크스페이스 이름, 2줄에 `파일명 · Code`를 표시합니다.
- **다중 디스플레이** — 연결된 모든 화면에서 동작합니다.

## 요구 사항

- macOS 14 이상 (macOS 26, Apple Silicon에서 확인)
- 빌드용 Xcode 16 이상
- 손쉬운 사용 권한

## 설치

현재는 소스에서 직접 빌드합니다.

```sh
git clone https://github.com/hmu332233/mission-control-labels.git
cd mission-control-labels
scripts/build-app.sh release
open build/MissionControlLabels.app
```

1. 처음 실행하면 권한 요청이 나타납니다. **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 `MissionControlLabels`를 허용하세요.
2. Mission Control(F3 또는 Control–↑)을 열면 각 창에 라벨이 표시됩니다.
3. 메뉴바의 사각형 아이콘에서 표시 켜기/끄기, 라벨 위치, 종료를 선택할 수 있습니다.

로그인 시 자동 실행이 필요하면 앱을 `/Applications`로 옮긴 뒤 **시스템 설정 → 일반 → 로그인 항목**에 추가하세요.

> [!NOTE]
> 빌드 스크립트는 키체인의 Apple Development 인증서로 서명합니다. 인증서가 없으면 ad-hoc 서명을 사용하며, 이 경우 재빌드할 때마다 손쉬운 사용 권한을 다시 부여해야 합니다.

## 문제 해결

- **라벨이 나타나지 않음** — 메뉴에서 권한 상태를 확인하세요. 재빌드 후라면 손쉬운 사용 목록에서 항목을 지우고 다시 추가하세요.
- **일부 창에 앱 이름만 표시됨** — 해당 앱이 창 제목을 제공하지 않는 경우로, 정상 동작입니다.

## 라이선스

[MIT](LICENSE)
