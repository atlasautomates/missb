# Miss B

Miss B is a native Apple Watch app for the RHC Zero Harm Audit. A nurse taps through each room's checks on a shared watch; when the sheet is sent, a listener fills a spreadsheet so nobody has to hand-copy the paper form into a computer.

- Decisions: [BRIEF.md](BRIEF.md)
- Scope: [issues/prd.md](issues/prd.md)

## Watch app

Install XcodeGen if needed: `brew install xcodegen`.

```bash
scripts/generate-xcodeproj.sh
xcodebuild -project MissB.xcodeproj -scheme MissB \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5' \
  build
```

Signing is automatic. If `.env` contains `APPLE_TEAM_ID`, the generator writes it into gitignored `Config/Signing.xcconfig`. If that key is missing, the team stays unset and the watchOS simulator still builds.

## AuditModel

```bash
cd AuditModel && swift test
```

## Listener

```bash
cd listener
uv sync
uv run modal deploy app.py
```

Deploy with Modal profile `adrianp916` active.

Hello endpoint: https://adrianp916--missb-listener-hello.modal.run
