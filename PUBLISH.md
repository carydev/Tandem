# TANDEM v1.1 배포하기

이 저장소의 설치 명령은 `carydev/Tandem`을 가리킨다. v1.1 설치 대상은 Windows PowerShell 5.1 이상이다. macOS/Linux 스크립트는 v1.0 상태로 남아 있지만 지원하지 않는다.

## 1. 포크 저장소 준비

한 줄 설치를 공개 배포하려면 저장소를 public으로 만든다. 비공개 저장소에는 별도 인증이 필요하다.

`boot.ps1`의 기본 `$Repo`와 `README.md`, `README.ko.md`, `QUICKSTART.txt`의 설치 URL에서 `carydev/Tandem`을 본인 저장소로 바꾼다. 저장소 이름의 대소문자를 URL과 일치시킨다. `boot.sh`는 v1.0 호환용으로만 남으며 v1.1 배포 경로에 포함하지 않는다.

## 2. 버전과 업데이트 알림

배포 전에 루트의 `VERSION` 파일을 릴리스 버전(예: `1.1`)으로 갱신한다. 설치기는 이 파일로 설치 버전을 정하고, 설치된 `tandem/tools/check.ps1`은 원격 저장소의 `VERSION`을 확인해 새 버전을 세션 시작 시 알린다. **`VERSION`을 갱신하지 않으면 업데이트 알림도 새 릴리스를 구분하지 못한다.**

업데이트를 받을 사용자는 설치 때 썼던 Windows 한 줄 명령을 다시 실행한다. 고치지 않은 TANDEM 파일은 자동 교체되고, 사용자가 고친 파일의 새 버전은 `.new`에 놓인다. Codex의 세션 알림 훅은 프로젝트 신뢰와 `/hooks` 승인이 필요하다.

## 3. 배포

변경 파일과 `VERSION`을 함께 검토하고 저장소에 게시한다. 릴리스 태그 예시는 `v1.1`이다. 이미 git 저장소라면 `git init`이나 `git remote add`를 반복하지 않는다.

```powershell
git tag v1.1
git push origin main v1.1
```

릴리스 zip을 제공할 경우 같은 버전 이름으로 만든다. 예:

```powershell
gh release create v1.1 tandem-v1.1.zip --title "TANDEM v1.1" --notes "Windows v1.1"
```

## 4. 설치 확인

빈 Windows 테스트 프로젝트에서 공개한 한 줄 명령을 실행한다. 기존 `CLAUDE.md`나 `AGENTS.md`가 있는 프로젝트에서도 TANDEM 블록이 원본 밖 내용을 보존하는지 확인한다.

```powershell
mkdir test-proj
cd test-proj
git init
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

모드와 언어를 지정하려면:

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -Mode codex-main -Lang ko
```

실제 설치 후 `tandem/config.json`의 모드·언어, `tandem/manifest.json`의 지문, 모드별 파일 배치를 확인한다. 같은 명령을 다시 실행해 업데이트 경로도 점검한다.

## 배포 전 점검

- [ ] `VERSION`과 릴리스 태그가 같은 버전을 가리킨다.
- [ ] 포크라면 `boot.ps1`과 세 문서의 저장소 주소를 바꿨다.
- [ ] Windows 빈 프로젝트와 기존 지시 파일이 있는 프로젝트에서 설치했다.
- [ ] 업데이트 시 사용자 수정 파일이 보존되고 `.new`가 만들어지는지 확인했다.
- [ ] `LICENSE`와 예시에 개인 정보가 없는지 확인했다.
