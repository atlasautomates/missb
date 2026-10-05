# 002 — Google service account + sheet access (HITL)

## Parent PRD

`issues/prd.md`

## What to build

A wizard (per the `wizard` skill) that walks Adrian through: creating a Google
Cloud service account on his account, downloading its JSON key, storing it as
a Modal secret (`missb-google-sa`), and sharing the audit spreadsheet
(`1deoDnkmTk72Hl43irxqc5fX-pW_qOPWCF-AxLHRk96M`) with the service account
email as editor. Ends with a verification call that reads the "missb app
automated input" tab via the service account.

## Acceptance criteria

- [ ] Modal secret `missb-google-sa` exists and contains the key JSON
- [ ] A script authenticated ONLY via the service account reads the tab title
      successfully
- [ ] Key JSON exists nowhere in the repo or brief

## Blocked by

None - can start immediately. (HITL: needs Adrian at a browser.)

## User stories addressed

27, 30 (credential hygiene underpinning the pipeline).
