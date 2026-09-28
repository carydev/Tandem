# 배포하기

이 저장소는 `carydev/Tandem`으로 배포된다. 부트스트랩과 문서에 그 주소가 이미 박혀 있다.
**포크해서 본인 것으로 쓸 사람**은 아래 1-2단계를 따르고, carydev 본인이면 3단계부터 보면 된다.

## 1. 저장소 만들기 (포크하는 경우)

깃헙에서 새 저장소를 만든다.
**공개(public)로 만들어야** 한 줄 설치가 된다. 비공개면 받는 쪽도 인증이 필요해서 `gh` CLI를 써야 한다.

## 2. 저장소 주소 바꾸기 (포크하는 경우)

`boot.ps1`의 `$Repo`, `boot.sh`의 `REPO`, 그리고 `README.md` / `README.ko.md` / `QUICKSTART.txt`의 설치 명령에서
`carydev/Tandem`을 본인 것으로 바꾼다.

**저장소 이름은 대소문자를 구분한다.** raw.githubusercontent URL이 그대로 타기 때문이다.

## 3. 올리기

```powershell
git init
git add .
git commit -m "TANDEM v1.0"
git branch -M main
git remote add origin https://github.com/carydev/Tandem.git
git push -u origin main
```

## 4. 확인

다른 폴더에서 실제로 한 줄 설치가 되는지 본다.

```powershell
mkdir test-proj; cd test-proj; git init
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

---

## 쓰는 사람 입장에서의 설치 방법 세 가지

저장소 README에 이 셋 중 원하는 걸 안내한다.

### A. 한 줄 (가장 간단)

```powershell
iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1 | iex
```

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash
```

옵션을 주려면:

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/main/boot.ps1))) -DocsRoot docs/ops
```

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/main/boot.sh | bash -s -- docs/ops
```

**주의**: 인터넷에서 받은 스크립트를 바로 실행하는 방식이다. 편하지만 받는 쪽이 내용을 못 보고 돌린다.
팀이나 회사에 배포한다면 B나 C를 권하는 편이 낫다.

### B. 클론 후 실행 (내용을 보고 돌린다)

```powershell
git clone https://github.com/carydev/Tandem.git
cd <설치할-프로젝트>
..\<REPO>\install.ps1
```

### C. 릴리스 zip

깃헙 Releases에 zip을 올려 두면 클론 없이 받을 수 있다.

```powershell
gh release create v1.0 tandem-v1.0.zip --title "TANDEM v1.0" --notes "초기 배포"
```

받는 쪽:

```powershell
iwr https://github.com/carydev/Tandem/releases/download/v1.0/tandem-v1.0.zip -OutFile t.zip
Expand-Archive t.zip -DestinationPath tandem-kit
.\tandem-kit\install.ps1
```

---

## 더 나아가려면

### 버전 태그

`boot.sh`와 `boot.ps1`은 브랜치 대신 태그도 받는다. 안정판을 고정해서 쓰게 할 수 있다.

```bash
curl -fsSL https://raw.githubusercontent.com/carydev/Tandem/v1.0/boot.sh | TANDEM_REF=v1.0 bash
```

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/carydev/Tandem/v1.0/boot.ps1))) -Ref v1.0
```

### npx 로 배포

`package.json`을 만들고 npm에 올리면 이렇게 된다.

```bash
npx <패키지명>
```

`bin` 필드에 install 스크립트를 연결하면 된다. npm 계정과 배포 과정이 추가로 필요하다.

### Claude Code 플러그인

Claude Code는 플러그인 마켓플레이스를 지원한다. 저장소를 플러그인 형식으로 맞추면
`/plugin` 으로 설치하게 만들 수 있다. 역할과 커맨드는 이미 `.claude/` 구조라 옮기기 쉽다.
다만 TANDEM은 `.codex/`와 운영 문서도 같이 깔아야 해서 설치 스크립트가 여전히 필요하다.

### 비공개 저장소로 배포

조직 내부용이면 비공개로 두고 `gh` CLI를 쓴다.

```bash
gh repo clone carydev/Tandem /tmp/tandem && /tmp/tandem/install.sh
```

받는 쪽이 저장소 접근 권한과 `gh` 로그인을 갖고 있어야 한다.

---

## 배포 전 점검

- [ ] (포크한 경우) `boot.ps1`, `boot.sh`, `README.md`, `README.ko.md`, `QUICKSTART.txt` 의 저장소 주소 교체
- [ ] 저장소 이름 대소문자가 URL과 정확히 일치하는지
- [ ] 빈 폴더에서 한 줄 설치 실제로 해보기
- [ ] 기존 `CLAUDE.md`가 있는 프로젝트에서도 해보기 (블록 추가되는지)
- [ ] (포크한 경우) `LICENSE` 의 저작권자 이름 바꾸기
- [ ] `.gitignore` 확인. 설치 결과물(`docs/tandem/`, `tandem/config.json`)이 안 올라가게
- [ ] README 의 스크린샷이나 예시에 개인 정보가 없는지
