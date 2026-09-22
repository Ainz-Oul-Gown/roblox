# 🔍 ПОЛНЫЙ АУДИТ И ПЛАН ИСПРАВЛЕНИЯ: 48 СПОСОБНОСТЕЙ + VFX ДВИЖОК

## Описание проблемы и результаты построчного аудита

В результате глубокого сравнения спецификаций в [TycoonConfig.luau](file:///x:/roblox/src/shared/TycoonConfig.luau) с кодом в [AbilityService.luau](file:///x:/roblox/src/server/AbilityService.luau), [AbilityVFX.luau](file:///x:/roblox/src/client/AbilityVFX.luau), [JuiceEffects.luau](file:///x:/roblox/src/client/JuiceEffects.luau) и [init.client.luau](file:///x:/roblox/src/client/init.client.luau) выявлен **61 дефект**, классифицированный на 4 группы:

- **Группа A**: 20 ранее найденных багов способностей *(оригинальный аудит)*
- **Группа B**: 18 **НОВЫХ** багов/недоработок способностей *(текущий аудит)*
- **Группа C**: 15 **НОВЫХ** багов VFX-движка [AbilityVFX.luau](file:///x:/roblox/src/client/AbilityVFX.luau) *(архитектура, рассинхрон, утечки)*
- **Группа D**: 8 **НОВЫХ** дефектов таймингов анимаций *(слишком быстрые, невидимые эффекты)*

---

## Группа A: 20 ранее найденных багов (оригинал)

| № | Фракция | Слот | Название (Спецификация) | Выявленный баг и решение |
| :- | :--- | :--- | :--- | :--- |
| A1 | **TungTung** | `tactical` | ⚡ Наковальня Сахура *(стан врага на 3с)* | 🔴 **САМОЗАМЕДЛЕНИЕ**: `hum.WalkSpeed = 6` замедляло кастера. Переделать на сброс наковальни на врага, 40 урона и стан ВРАГА на 3с. |
| A2 | **Rizzler** | `mobility` | 🌹 Лепестковый Блинк *(блинк сквозь стены)* | 🔴 **НЕ БЛИНК**: импульс скорости вместо мгновенного блинка. Переделать на `PivotTo` + розовая бомба 35 урона. |
| A3 | **Sigma** | `mobility` | 🔪 Теневой Шаг *(телепорт за спину)* | 🔴 **DESYNC**: серверный `root.CFrame` без сброса скорости. Добавить `PivotTo` + `TELEPORT` RemoteEvent. |
| A4 | **Mewing** | `tactical` | 💪 Алмазный Подбородок *(отражение 40% урона)* | 🔴 **ПОДМЕНА**: хил `MaxHealth += 30`. Реализовать `ReflectDamage = 0.4` + `KnockbackImmune = true` на 5с. |
| A5 | **Sigma** | `special` | 🐺 Lone Wolf *(гарантированный крит 90)* | 🔴 **МЁРТВЫЙ АТРИБУТ**: `SigmaCritActive` не проверяется в `applyDamage`. Добавить обработку. |
| A6 | **CaseOh** | `special` | 💥 BAN HAMMER METEOR *(75 урона)* | 🔴 **ПОДМЕНА**: `MaxHealth += 50` (Mukbang Heal). Переделать на банхаммер с неба. |
| A7 | **Rizzler** | `tactical` | ✨ Ризз Гипноз *(замирание 3.5с)* | 🔴 **ПОДМЕНА**: лечил кастера + скорость. Переделать на гипноз врага 3.5с. |
| A8 | **Rizzler** | `special` | 💘 Cupid's Arrow *(40 урона + танец 3с)* | 🔴 **ПОДМЕНА**: воровал кэш. Переделать на стрелу + танец/стан. |
| A9 | **Grimace** | `tactical` | 🧃 Коктейльная Лужа *(замедление + период. урон)* | 🔴 **ПОДМЕНА**: давал щит кастеру. Переделать на лужу под врагами. |
| A10 | **Grimace** | `special` | 🟣 Birthday Eclipse *(запрет прыжков + 15 ур/с)* | 🔴 **ПОДМЕНА**: стягивал врагов (Shake Vortex). Добавить `JumpPower = 0` + DoT 4с. |
| A11 | **CaseOh** | `tactical` | 🧲 Горизонт Событий *(купол, притягивание)* | 🔴 **ПОДМЕНА**: личный щит + ускорение. Переделать на гравитационный купол. |
| A12 | **CaseOh** | `godmode` | 🌍 Смещение Земной Оси *(подброс + -50% HP)* | 🔴 **БАГ ФИЗИКИ**: CFrame телепорт вместо подброса. Исправить на `AssemblyLinearVelocity` вверх + 50% HP среза. |
| A13 | **Mewing** | `godmode` | 👑 Альфа Доминация *(удвоенный урон 7с)* | 🟡 **НЕДОРАБОТКА**: нет `DoubleDamage = true` атрибута. Добавить + обработку в `applyDamage`. |
| A14 | **Sigma** | `base` | 🕶️ Phonk Rage *(двойная скорость + силовое поле)* | 🟡 **НЕДОРАБОТКА**: только скорость, нет `DamageReduction = 0.4`. |
| A15 | **FanumTax** | `godmode` | 🍕 Мега-Пиршество *(щит бессмертия 4с)* | 🟡 **НЕДОРАБОТКА**: полный хил вместо `Invulnerable = true` на 4с. |
| A16 | **TungTung** | `ultimate` | 🌋 Итальянский Торнадо *(вихрь 6с + бессмертие)* | 🟡 **НЕДОРАБОТКА**: одиночный удар вместо серии + бессмертие. |
| A17 | **Grimace** | `godmode` | 💀 Ритуал 23 Июня *(85 урона + стан)* | 🟡 **НЕДОРАБОТКА**: нет стана врагов на 3.5с. |
| A18 | **FanumTax** | `mobility` | 🥤 Cola Rocket Jump *(взрывная волна)* | 🟡 **НЕДОРАБОТКА**: только прыжок, нет AoE при приземлении. |
| A19 | **TungTung** | `mobility` | ⚡ Молот-Джамп *(приземление на врагов)* | 🟡 **НЕДОРАБОТКА**: только прыжок, нет сплэша при приземлении. |
| A20 | **Skibidi** | `godmode` | 👑 Титан Скибиди *(иммунитет к стану)* | 🟡 **НЕДОРАБОТКА**: нет `StunImmune = true` на 8с. |

---

## Группа B: 18 НОВЫХ багов и недоработок способностей

> [!CAUTION]
> Эти дефекты ранее не были обнаружены и являются результатом глубокого построчного аудита всех 48 слотов.

| № | Фракция | Слот | Название | Строки AbilityService | Что делает код | Что должен делать по спеке TycoonConfig | Тип дефекта |
| :- | :--- | :--- | :--- | :---: | :--- | :--- | :--- |
| B1 | **CaseOh** | `base` | CaseOh Slam | [710-724](file:///x:/roblox/src/server/AbilityService.luau#L710-L724) | Стягивает врагов к кастеру (`diff.Unit * 50`) | «Гравитационный слэм: **сбивает всех с ног** мощным сотрясением земли!» → должен подбрасывать врагов вверх (нокдаун) | 🔴 **ПЕРЕПУТАНА МЕХАНИКА с CaseOh_Tactical** |
| B2 | **CaseOh** | `mobility` | Вафельный Каток | [753-768](file:///x:/roblox/src/server/AbilityService.luau#L753-L768) | Вертикальный прыжок + AoE при приземлении (Belly Flop) | «Превращается в **неостановимый шар массы и катится**, сметая всё на пути (40 урона)!» → горизонтальный перекат/рывок | 🔴 **ПОДМЕНА МЕХАНИКИ**: вертикальный прыжок вместо горизонтального переката |
| B3 | **Rizzler** | `ultimate` | Взрыв Сверхризза | [809-822](file:///x:/roblox/src/server/AbilityService.luau#L809-L822) | 55 урона + разворот спиной + замедление 6 WS на 3с | «Наносит **50** урона и **отключает способности** врагов на **5** сек!» | 🔴 **3 расхождения**: 1) Урон 55≠50, 2) Нет блокировки способностей, 3) Длительность 3с≠5с |
| B4 | **Rizzler** | `godmode` | Аура Гипер-Ризза 999+ | [854-869](file:///x:/roblox/src/server/AbilityService.luau#L854-L869) | Полный хил + 70 урона + стан 4с + 15% кража ауры | «Запрет атаки на **7с** и **+100% урон** по ним!» | 🔴 **3 расхождения**: 1) Нет `DamageVulnerability = 1.0`, 2) Стан 4с≠7с, 3) Нет запрета атаки |
| B5 | **Sigma** | `ultimate` | Сигма Доминация | [439-452](file:///x:/roblox/src/server/AbilityService.luau#L439-L452) | 55 урона + замедление WS=6 на 5с | «Замедляет всех врагов на 60% и **утраивает урон**!» | 🔴 **НЕДОРАБОТКА**: нет `TripleDamage` или множителя x3 для кастера |
| B6 | **Sigma** | `godmode` | Brazilian Phonk Overload | [501-516](file:///x:/roblox/src/server/AbilityService.luau#L501-L516) | WalkSpeed 36 + **одноразовый** 70 урона + возврат через 8с | «Скорость молнии и **автоматические удары молнией (20 урона/с)!**» | 🔴 **НЕДОРАБОТКА**: одиночный 70 урон вместо DoT 20/с по 8с. Нужен цикл |
| B7 | **Skibidi** | `godmode` | Титан Скибиди-Крушитель | [330-346](file:///x:/roblox/src/server/AbilityService.luau#L330-L346) | WS 28 + **одноразовый** 80 AoE + возврат 8с | «На 8с: иммунитет к стану, **сплэш-удары молотом по земле** (80 урона)!» → многократные удары | 🔴 **НЕДОРАБОТКА**: одиночный удар вместо серии ударов за 8с |
| B8 | **TungTung** | `godmode` | Ярость Вулкана Этна | [940-954](file:///x:/roblox/src/server/AbilityService.luau#L940-L954) | Одноразовый 85 AoE + WS 30 на 8с | «Извержение лавы и **дождь из раскаленных молотов**: 85 урона и **огненный след на 10с!**» | 🟡 **НЕДОРАБОТКА**: нет периодического урона, длительность 8с≠10с |
| B9 | **FanumTax** | `tactical` | Ловушка Фастфуда | [541-570](file:///x:/roblox/src/server/AbilityService.luau#L541-L570) | Одноразовый 15 урон + замедление при касании | «Масло на **8** сек: враг **скользит, падает**!» | 🟡 **НЕДОРАБОТКА**: нет «скольжения» (ragdoll), единоразовый урон |
| B10 | **Mewing** | `special` | Looksmaxing Flash | [382-396](file:///x:/roblox/src/server/AbilityService.luau#L382-L396) | 25 урона + WalkSpeed 4 на 4с | «**Ослепляет** врагов белой вспышкой!» | 🟡 **НЕДОРАБОТКА**: нет ослепления жертвы (нужен FireClient → screenBloomFlash на экран врага) |
| B11 | **Mewing** | `godmode` | Альфа Доминация | [424](file:///x:/roblox/src/server/AbilityService.luau#L424) | `AssemblyLinearVelocity = (0, **-30**, 0)` | «Враги **падают ниц**» → нокдаун | 🟡 **БАГ ФИЗИКИ**: отрицательный Y **вдавливает врагов в пол**, а не опрокидывает. Нужен stun/ragdoll |
| B12 | **Grimace** | `ultimate` | Катаклизм Гримаса | [655-666](file:///x:/roblox/src/server/AbilityService.luau#L655-L666) | Одноразовый 60 урона + подброс | «Туман **на всю арену**: **15 урона в секунду** всем!» | 🔴 **ПОДМЕНА**: одиночный удар вместо DoT зоны 15/с × 4-5с |
| B13 | **Grimace** | `mobility` | Слизистый Прыжок | [682-693](file:///x:/roblox/src/server/AbilityService.luau#L682-L693) | Прыжок + 30 урона | «Разливает **липкую жижу, приковывающую** врагов к земле!» | 🟡 **НЕДОРАБОТКА**: нет персистентной зоны замедления после приземления |
| B14 | **FanumTax** | `ultimate` | Великий Налоговый Аудит | [571-591](file:///x:/roblox/src/server/AbilityService.luau#L571-L591) | 40 урона + 30% кража + 50 хил | «Высасывает 30% кошелька + лечит 50 HP» → урон 40 не в спеке | 🟢 **МИНОР**: 40 урона как бонус |
| B15 | **TungTung** | `special` | Базука Сахура | [920-936](file:///x:/roblox/src/server/AbilityService.luau#L920-L936) | 3 волны по 22 урона (66 итого) | «Мощный разрыв и **55** урона!» → единичный удар | 🟡 **РАСХОЖДЕНИЕ УРОНА**: 66≠55 и 3 волны вместо 1 удара |
| B16 | **Skibidi** | `mobility` | Скибиди Ракета | [315-329](file:///x:/roblox/src/server/AbilityService.luau#L315-L329) | Импульс + урон 35 в радиусе 14 studs **при касте** | «Рывок на 50 studs со сбиванием (35 урона)» | 🟡 **АРХИТЕКТУРНЫЙ**: проверка врагов **только в момент каста**, враги по пути рывка не получают урон |
| B17 | **Grimace** | `base` | Grimace Cloud | [632-648](file:///x:/roblox/src/server/AbilityService.luau#L632-L648) | Конусная атака + 22 урона + замедление WS=8 на 3с | «**Ядовитое** фиолетовое облако с **периодическим** уроном!» | 🟡 **НЕДОРАБОТКА**: одиночный урон вместо DoT облака |
| B18 | **Skibidi** | `tactical` | Скибиди Броня | [268-277](file:///x:/roblox/src/server/AbilityService.luau#L268-L277) | DR 0.5 + WS 26, но `_prevSpeed` берётся **после** изменения WS | «-50% урона и ускорение на 6с» → функционально почти верно | 🟢 **МИНОР**: `_prevSpeed = getBaseWalkSpeed()` уже вызывается правильно, скорость восстанавливается |

---

## Группа C: 15 НОВЫХ багов VFX-движка (AbilityVFX.luau)

> [!WARNING]
> VFX-движок содержит архитектурные проблемы, рассинхроны с сервером и утечки производительности.

| № | Проблема | Строки | Описание | Тип |
| :- | :--- | :---: | :--- | :--- |
| C1 | **Рассинхрон VFX ↔ сервер: CaseOh_Base** | VFX [858-865](file:///x:/roblox/src/client/AbilityVFX.luau#L858-L865), Srv [710-724](file:///x:/roblox/src/server/AbilityService.luau#L710-L724) | VFX показывает «Ground Slam» (земля трескается), но сервер делает **притягивание** к кастеру | 🔴 |
| C2 | **Рассинхрон VFX ↔ сервер: CaseOh_Tactical** | VFX [867-873](file:///x:/roblox/src/client/AbilityVFX.luau#L867-L873), Srv [725-732](file:///x:/roblox/src/server/AbilityService.luau#L725-L732) | VFX показывает «Горизонт Событий» (вихрь + круг), но сервер дает **личный щит + ускорение** | 🔴 |
| C3 | **Рассинхрон VFX ↔ сервер: TungTung_Tactical** | VFX [1017-1032](file:///x:/roblox/src/client/AbilityVFX.luau#L1017-L1032), Srv [888-907](file:///x:/roblox/src/server/AbilityService.luau#L888-L907) | VFX показывает **падающую наковальню**, но сервер делает DR 80% + замедление **кастера** | 🔴 |
| C4 | **Рассинхрон VFX ↔ сервер: Grimace_Tactical** | VFX [801-806](file:///x:/roblox/src/client/AbilityVFX.luau#L801-L806), Srv [649-654](file:///x:/roblox/src/server/AbilityService.luau#L649-L654) | VFX показывает «Лужу» (ground cracks), но сервер дает **щит кастеру** | 🔴 |
| C5 | **Рассинхрон VFX offset: CaseOh_Ultimate** | VFX [877](file:///x:/roblox/src/client/AbilityVFX.luau#L877), Srv [733-749](file:///x:/roblox/src/server/AbilityService.luau#L733-L749) | Метеорит VFX падает на `pos + lookVector * 18`, но урон — от `root.Position`. **Зона взрыва не совпадает с зоной урона** | 🔴 |
| C6 | **Нет LOD-отсечения тяжелых эффектов** | [118](file:///x:/roblox/src/client/AbilityVFX.luau#L118), [186](file:///x:/roblox/src/client/AbilityVFX.luau#L186), [211](file:///x:/roblox/src/client/AbilityVFX.luau#L211), [443](file:///x:/roblox/src/client/AbilityVFX.luau#L443) | `createShockwaveRing`, `createPillarOfLight`, `createBeamLine`, `spawnFallingSkyProp` **не проверяют `isWithinLOD()`**. FPS-просадки при массовых PvP. | 🟡 |
| C7 | **Нет mobile-скейла для ключевых эффектов** | [118](file:///x:/roblox/src/client/AbilityVFX.luau#L118), [186](file:///x:/roblox/src/client/AbilityVFX.luau#L186) | `createShockwaveRing`, `createPillarOfLight` не используют `getQualityScale()`. | 🟡 |
| C8 | **Нет VFX для ongoing/периодических способностей** | Все `godmode` слоты | Способности с длительностью 6-10с проигрывают VFX **только при касте**. Нет визуального цикла повторных ударов. | 🔴 |
| C9 | **Нет VFX жертвы (Victim Impact FX)** | Все combat слоты | Ни одна способность не вызывает `impactFlash()` на **модели жертвы**. | 🟡 |
| C10 | **Нет VFX приземления для mobility** | FanumTax/TungTung `mobility` | Показывают **только взлёт**, нет второй фазы VFX при приземлении. | 🟡 |
| C11 | **FanumTax_Tactical VFX непостоянная** | [723-728](file:///x:/roblox/src/client/AbilityVFX.luau#L723-L728) | **Одноразовый** ground crack вместо персистентной масляной зоны на 8 сек. | 🟡 |
| C12 | **Variable shadowing** | [486-487](file:///x:/roblox/src/client/AbilityVFX.luau#L486-L487) | `local fId = currentFaction` и `local lookVector = look` затеняют параметры функции `play()`. | 🟡 |
| C13 | **Двойное уничтожение в `spawnFallingSkyProp`** | [459-463](file:///x:/roblox/src/client/AbilityVFX.luau#L459-L463) | `Debris:AddItem` + `prop:Destroy()` в `tween.Completed`. | 🟢 |
| C14 | **Grimace_Mobility нет персистентной жижи** | [831-837](file:///x:/roblox/src/client/AbilityVFX.luau#L831-L837) | По спеке прыжок оставляет «липкую жижу», но VFX — только laser-след. | 🟡 |
| C15 | **Нет «слепоты» VFX для Mewing_Special** | [609-616](file:///x:/roblox/src/client/AbilityVFX.luau#L609-L616) | VFX «Looksmaxing Flash» играет вспышку только для **кастера** (`if isSelf then`). Жертвы **не ослеплены**. | 🔴 |

---

## Группа D: 8 дефектов таймингов анимаций

> [!IMPORTANT]
> Ряд VFX-эффектов завершается за 1-3 кадра (при 60 FPS) и фактически **невидим** для игрока. На Mobile (30 FPS) ситуация ещё хуже.

| № | Эффект | Строки | Текущая длит. | Кадров при 60fps | Проблема | Исправление |
| :- | :--- | :---: | :---: | :---: | :--- | :--- |
| D1 | **Sigma_Tactical парирование: лазерные кресты** | [661-662](file:///x:/roblox/src/client/AbilityVFX.luau#L661-L662) | **0.2с** | ~12 | Два `spawnVolumetricLaser` с 0.2с — крест исчезает моментально | → **0.45с** |
| D2 | **Skibidi_Base AnticipationVortex** | [495](file:///x:/roblox/src/client/AbilityVFX.luau#L495) | **0.15с** | ~9 | Частицы едва появляются. На Mobile (~5 кадров) — невидимо | → **0.3с** |
| D3 | **JuiceEffects.impactFlash** | [205-227](file:///x:/roblox/src/client/JuiceEffects.luau#L205-L227) | **0.08с** | ~5 | Highlight за 0.08с — **~2.4 кадра на Mobile**. Невидим на телефонах | → **0.15с** |
| D4 | **JuiceEffects.hitstop** (5 вызовов) | Множественные | **0.05с** | ~3 | 3 кадра при 60fps. На Mobile — **1.5 кадра**, может не сработать | → **0.07с** минимум |
| D5 | **Sigma_Tactical LightBurst** | [663](file:///x:/roblox/src/client/AbilityVFX.luau#L663) | **0.15с** | ~9 | PointLight гаснет быстро, на Mobile без теней незаметен | → **0.25с** + brightness 22 |
| D6 | **screenBloomFlash** (godmode) | [261-293](file:///x:/roblox/src/client/JuiceEffects.luau#L261-L293) | **0.18с** | ~11 | TintColor исчезает мгновенно, не передаёт атмосферу godmode | → **0.35с** для godmode |
| D7 | **createBeamLine** (при 0.2с override) | [211-232](file:///x:/roblox/src/client/AbilityVFX.luau#L211-L232) | **0.2с** | ~12 | Тонкий луч растворяется на грани видимости | → Минимум **0.35с** |
| D8 | **spawnLightBurst** (дальние dist) | [230-257](file:///x:/roblox/src/client/JuiceEffects.luau#L230-L257) | **0.2с** | ~12 | На 50+ studs burst не успевает отрендериться из-за LOD движка | → **0.3с** + LOD check |

---

## Общесистемные исправления боевого ядра

### 1. Архитектура `applyDamage` (критическая переработка)

В [applyDamage](file:///x:/roblox/src/server/AbilityService.luau#L61-L80) добавить обработку **всех** боевых атрибутов:

```
1. Invulnerable       → цель бессмертна, урон = 0
2. SigmaParryActive   → отражение 75% урона назад (уже есть)
3. ReflectDamage      → отражение 40% урона (Мьюинг)
4. DamageReduction    → % поглощение (уже есть)
5. DamageVulnerability → +100% урон (Риззлер годмод)
6. SigmaCritActive    → фиксированные 90 урона + сброс
7. DoubleDamage       → урон атакующего x2 (Мьюинг годмод)
8. TripleDamage       → урон атакующего x3 (Сигма ультимейт)
```

### 2. Защита от перманентного стана (Stun Lock Fix)

Вспомогательная функция `applyStun(targetHum, duration)`:
- Проверяет `targetPlayer:GetAttribute("StunImmune")`.
- **Не сохраняет `prevSpeed = 0`** если WalkSpeed уже 0.
- Восстанавливает через `math.max(targetHum.WalkSpeed, TycoonService.getBaseWalkSpeed(targetPlayer))`.
- Уникальный ключ стана на жертву для отмены старого при наложении нового.

### 3. Исправление потери скорости от геймпасса `SPEED_PERK`

В [TycoonService.getBaseWalkSpeed](file:///x:/roblox/src/server/TycoonService.luau#L87-L93):
- Проверять наличие геймпасса `SPEED_PERK` → возвращать **28** вместо 16.

### 4. Клиппинг сквозь стены + клиентская синхронизация

- Блинки проходят сквозь стены.
- Проверяется высота Y (луч вниз для поиска пола).
- Сервер: `char:PivotTo(targetCF)` + сброс скорости + FireClient `"TELEPORT"`.
- Клиент: мгновенный `char:PivotTo(targetCF)`.

### 5. Увеличение минимальных таймингов

- `hitstop` минимум: 0.05с → **0.07с**.
- `impactFlash`: 0.08с → **0.15с**.

### 6. Victim-Side VFX System (новое)

- При уроне: `abilityVFXEvent:FireClient(victimPlayer, "VICTIM_IMPACT", fId, slot, damageAmount)` → `impactFlash` + screen edge vignette.
- Для «ослепляющих» (Mewing_Special): `abilityVFXEvent:FireClient(victimPlayer, "BLIND", 4.0)` → fullscreen `screenBloomFlash`.

### 7. Ongoing VFX для периодических способностей (новое)

- Для DoT-способностей сервер отправляет повторные `abilityVFXEvent:FireAllClients` каждые N секунд.
- Или клиент запускает визуальный цикл на `duration` секунд при получении начального VFX.

---

## Proposed Changes

### [MODIFY] [AbilityService.luau](file:///x:/roblox/src/server/AbilityService.luau)
- Полная переработка `applyDamage` со всеми 8 боевыми атрибутами (§1).
- Реализовать безопасный `applyStun` с защитой от stun-lock (§2).
- Реализовать `getClipBlinkCFrame` для сквозных блинков (§4).
- Исправить все 20 дефектов группы A.
- Исправить все 18 дефектов группы B.
- Добавить Victim-Side FireClient для эффектов на стороне жертвы (§6).
- Добавить периодические FireAllClients для ongoing-способностей (§7).

### [MODIFY] [AbilityVFX.luau](file:///x:/roblox/src/client/AbilityVFX.luau)
- Исправить все 15 дефектов группы C.
- Добавить `isWithinLOD()` на все тяжёлые эффекты (C6).
- Добавить `getQualityScale()` на ударные кольца и столбы (C7).
- Реализовать Victim Impact handler (C9, C15).
- Реализовать ongoing VFX циклы для godmode-способностей (C8).
- Синхронизировать VFX с механикой для C1-C5.
- Добавить VFX второй фазы приземления для mobility (C10).
- Убрать variable shadowing (C12).

### [MODIFY] [JuiceEffects.luau](file:///x:/roblox/src/client/JuiceEffects.luau)
- `impactFlash`: 0.08с → 0.15с (D3).
- `hitstop` минимум: 0.05с → 0.07с (D4).
- `screenBloomFlash` для godmode: → 0.35с (D6).

### [MODIFY] [TycoonService.luau](file:///x:/roblox/src/server/TycoonService.luau)
- В `getBaseWalkSpeed(player)` добавить учет геймпасса `SPEED_PERK` (скорость 28).

### [MODIFY] [init.client.luau](file:///x:/roblox/src/client/init.client.luau)
- Добавить обработчик `"TELEPORT"` для безлагового блинка.
- Добавить обработчик `"VICTIM_IMPACT"` и `"BLIND"`.

### [MODIFY] [abilityVfxSfx.test.js](file:///x:/roblox/tests/abilityVfxSfx.test.js)
- Тесты на все новые механики, тайминги и рассинхроны.

---

## Verification Plan

### Automated Tests
1. `npm test` — проверка всех тестов.
2. `npm run build` — проверка компиляции Rojo.

### Manual Verification
1. **Все 48 способностей**: механика совпадает с описанием в TycoonConfig.
2. **Стан-лок**: два игрока станят третьего — скорость восстанавливается.
3. **VFX синхрон**: визуальные эффекты совпадают с зоной урона.
4. **Тайминги**: все VFX видны минимум 4+ кадров при 60fps.
5. **Mobile**: нет FPS-просадок, все эффекты видны.
6. **Ongoing VFX**: godmode-способности показывают визуальный цикл на всю длительность.
