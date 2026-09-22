# Task List — 61 дефект: Способности + VFX движок

## 1. TycoonService.luau
- [x] SPEED_PERK в getBaseWalkSpeed

## 2. AbilityService.luau — Системные функции
- [x] applyDamage: 8 атрибутов (Invulnerable, Reflect, Vuln, Crit, DoubleDmg, TripleDmg)
- [x] applyStun: stun-lock защита, StunImmune, уникальный ключ
- [x] getClipBlinkCFrame: сквозные блинки
- [x] Victim-side FireClient helper

## 3. AbilityService.luau — Группа A (20 багов)
- [x] A1: TungTung tactical — наковальня на врага
- [x] A2: Rizzler mobility — PivotTo блинк + бомба
- [x] A3: Sigma mobility — PivotTo + TELEPORT remote
- [x] A4: Mewing tactical — ReflectDamage + KnockbackImmune
- [x] A5: Sigma special — SigmaCritActive в applyDamage
- [x] A6: CaseOh special — BAN HAMMER meteor logic
- [x] A7: Rizzler tactical — гипноз врага 3.5с
- [x] A8: Rizzler special — стрела + танец/стан
- [x] A9: Grimace tactical — лужа под врагами
- [x] A10: Grimace special — JumpPower=0 + DoT 4с
- [x] A11: CaseOh tactical — гравитационный купол
- [x] A12: CaseOh godmode — подброс + 50% HP среза
- [x] A13: Mewing godmode — DoubleDamage атрибут
- [x] A14: Sigma base — DamageReduction 0.4
- [x] A15: FanumTax godmode — Invulnerable 4с
- [x] A16: TungTung ultimate — серия + Invulnerable 6с
- [x] A17: Grimace godmode — стан 3.5с
- [x] A18: FanumTax mobility — AoE при приземлении
- [x] A19: TungTung mobility — сплэш при приземлении
- [x] A20: Skibidi godmode — StunImmune 8с + серия ударов

## 4. AbilityService.luau — Группа B (18 новых багов)
- [x] B1: CaseOh base — нокдаун вверх
- [x] B2: CaseOh mobility — горизонтальный перекат
- [x] B3: Rizzler ultimate — урон 50, блок способностей 5с
- [x] B4: Rizzler godmode — DamageVulnerability, стан 7с
- [x] B5: Sigma ultimate — TripleDamage атрибут
- [x] B6: Sigma godmode — DoT молнии 20/с
- [x] B7: Skibidi godmode — серия ударов 8с
- [x] B8: TungTung godmode — периодический урон, 10с
- [x] B9: FanumTax tactical — зона скольжения
- [x] B10: Mewing special — BLIND FireClient
- [x] B11: Mewing godmode — stun вместо Y=-30
- [x] B12: Grimace ultimate — DoT 15/с
- [x] B13: Grimace mobility — персистентная зона жижи
- [x] B15: TungTung special — урон 55 за 1 удар
- [x] B16: Skibidi mobility — проверка по пути рывка
- [x] B17: Grimace base — DoT облако

## 5. JuiceEffects.luau — Группа D (тайминги)
- [x] D3: impactFlash 0.08с → 0.15с
- [x] D4: hitstop 0.05с → 0.07с
- [x] D6: screenBloomFlash godmode → 0.35с

## 6. AbilityVFX.luau — Группа C (VFX движок)
- [ ] C1: CaseOh_Base VFX — рассинхрон
- [ ] C2: CaseOh_Tactical VFX — рассинхрон
- [ ] C3: TungTung_Tactical VFX — рассинхрон
- [ ] C4: Grimace_Tactical VFX — рассинхрон
- [ ] C5: CaseOh_Ultimate offset — выровнять pos
- [ ] C6: isWithinLOD на ShockwaveRing/Pillar/Beam/SkyProp
- [ ] C7: getQualityScale на ShockwaveRing/Pillar
- [ ] C8: ongoing VFX циклы для godmode
- [ ] C9: Victim impact handler
- [ ] C10: VFX приземления для mobility
- [ ] C11: FanumTax_Tactical — персистентная зона
- [ ] C12: variable shadowing fix
- [ ] C13: двойное уничтожение fix
- [ ] C14: Grimace_Mobility — лужа VFX
- [ ] C15: Mewing_Special — BLIND VFX для жертв
- [ ] D1: Sigma parry cross 0.2с → 0.45с
- [ ] D2: AnticipationVortex 0.15с → 0.3с
- [ ] D5: LightBurst 0.15с → 0.25с
- [ ] D7: BeamLine минимум 0.35с
- [ ] D8: LightBurst LOD check

## 7. init.client.luau — Клиент
- [ ] TELEPORT handler
- [ ] VICTIM_IMPACT handler
- [ ] BLIND handler

## 8. Тесты
- [ ] Обновить tests/abilityVfxSfx.test.js
