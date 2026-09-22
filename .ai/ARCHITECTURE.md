# Архитектура: Gen Alpha Brainrot Multiplayer Tycoon

## Карта острова и окружение (WorldBuilder)
- **Уровень поверхности**: `GROUND_Y = 3` — верхний уровень диска острова (`IslandBase`, радиус 250 стадов).
- **Радиус арены**: `TycoonConfig.ARENA_RADIUS = 180` стадов от центра `(0, 0, 0)`.
- **Центральная Арена**: золотой пьедестал царя горы в координатах `(0, 3.6, 0)`.
- **Центральные Доски Лидеров (LeaderboardService)**:
  - `WealthBoard`: неоновый дисплей $22 \times 16$ стадов в координатах `(-22, 11, -22)`, сортировка по Ауре.
  - `PvPBoard`: неоновый дисплей $22 \times 16$ стадов в координатах `(22, 11, -22)`, сортировка по PvP фрагам и добыче.
- **Динамический AirDrop (AirDropService)**:
  - Спуск золотого контейнера каждые 210 секунд на радиальные дороги острова. Зона удержания 4 секунды, награда +$10,000 Aura.
- **Дорожная сеть и бордюры (Road Kit)**:
  - 8 радиальных дорог, соединяющих край центральной площади (`ROAD_START = 22`) и вход каждой базы (`ROAD_END_DIST = BASE_RADIUS - 2 = 178`).
  - По обеим сторонам дорожного полотна уложены бетонные бордюры (`RoadCurb`), неоновые разделительные полосы и фонари с фракционной подсветкой.

## Архитектура 2-этажной базы (PlotBuilder)
- **Габариты основания**: $56 \times 76$ стадов (просторная планировка).
- **1-й этаж**:
  - `MainConveyor`: длина 34, ширина 5, скорость 16.
  - `Collector` + `WithdrawPad`: руда накапливается в сейфе; при наступании на пад средства переводятся в кошелек со звуком кассы и всплывающими числами.
  - `LaserGate`: силовой барьер в проеме $12 \times 14$, уничтожающий чужаков.
  - `BrainrotWalls`: стены периметра высотой 14 стадов ($Y = 0..14$) с неоновой окантовкой.
  - `LaserGate`: защитные лазерные ворота с пультом `GateControlSwitch` (ProximityPrompt и клик). Владелец может включать/выключать режим охраны: в гостевом режиме лазер мягко-зеленый и гости могут свободно входить без урона.
  - `BrainrotWalls`: стены периметра 56x76 высотой Y=14.
  - `Lighting_Floor1` и `Windows_Floor1`: опциональная ветка прокачки 1-го этажа (неоновые люстры и панорамные тонированные окна в неоновых наличниках).
  - `Upgrader_Laser`: лазер x2.
  - `AbilityStand_1` [1 / E] и `AbilityStand_Tactical` [2 / R].
  - `Stairs_To_Floor2`: 20 широких ступеней (ширина 8 стадов) от $Z = 24$ до $Z = -6$ с подъемом на $Y = 14$.
  - Кнопка постройки 2-го этажа вынесена на открытое пространство перед лестницей ($Z = 26$).
- **2-й этаж**:
  - `Floor2_Foundation`: сплошное перекрытие $56 \times 76$ ровно на высоте стен $Y = 14$ (без щелей и зависаний в воздухе) с вырезом под лестничный пролет и желоб.
  - `Floor2_Walls`: защитные ограждения периметра и лестничного проема ($Y = 14..24$) с неоновыми перилами.
  - `Lighting_Floor2` и `Windows_Floor2`: опциональная ветка прокачки 2-го этажа (дизайнерские световые пилоны и панорамный фасад с видом на арену).
  - `Floor2_Conveyor`: верхний конвейер с желобом сброса `OreDropChute` прямо в нижний коллектор.
  - `Upgrader_Quantum` (x3) и `Upgrader_Annihilator` (x5).
  - `Dropper_Galactic` (+60 Aura/1.1c).
  - **Арсенал 6 способностей фракции**:
    - `AbilityStand_1` [1 / E]: Базовая способность.
    - `AbilityStand_Tactical` [2 / R]: Тактическая способность.
    - `AbilityStand_Ultimate` [3 / Q]: Ультимативная способность.
    - `AbilityStand_Special` [4 / F]: Спец-способность фракции (стойка на 2 этаже).
  - `AbilityStand_Mobility` [5 / Z]: Мобильность и мем-маневры (стойка на 2 этаже).
  - `AbilityStand_Godmode` [6 / X]: Финишер Бога Фракции (стойка на 2 этаже).
  - **Стойки и Инвентарь (ProximityPrompt)**:
    - На каждой стойке способностей смонтирован `ProximityPrompt` ("Забрать [Название]", радиус 10, задержка 0.3s).
    - При смерти персонажа способность не восстанавливается автоматически — игрок возвращается на базу и забирает предмет со стенда.
    - При смене базы старые способности принудительно удаляются через `AbilityService.clearPlayerTools(player)`.
    - Всего 48 глубоко проработанных тематических способностей в игре (уникальные механики для всех 8 фракций без генерик-заглушек).
  - `OreDropChute & Chute Hole`: Физический вырез в перекрытии 2 этажа (X = -4..+4, Z = 3.5..11.5) и наклонный гладкий желоб с бортиками, по которому кубы со 2 этажа безупречно скатываются на конвейер и в сборщик 1 этажа. Кнопка `Floor2_Conveyor` вынесена на безопасную координату (10, 14.5, 10), не блокируя проем.
  - `Ore Despawn`: Таймер исчезновения несобранной руды установлен ровно на 20 секунд (`Debris:AddItem(ore, 20)`).
  - `TycoonRoof`: Сплошная защитная крыша (58x78 на Y = 24..25), полностью исключающая возможность залететь на базу сверху, с неоновыми энерго-шинами и потолочным освещением.
  - `Rebirth_Portal`: Физический алтарь перерождения на 2 этаже, вынесенный в просторный левый сектор базы (X = -18, Z = 18) без помех от конвейера. Выполнен в строгом темном каркасе с золотыми неоновыми линиями и четкой контрастной вывеской на темном фоне. Вход в поле выполняет `TycoonService.performRebirth`, оповещает через `RebirthEvent` с фанфарами и вспышкой, сбрасывает базу и сохраняет повышенный множитель и ранг.
  - `FactionMonument`: 3D-монумент фракции на крыше `TycoonRoof` со световым столпом `SkyBeacon` на 400 стадов ввысь.
- **Оптимизация текста (Anti-Clutter UI)**:
  - `AlwaysOnTop = false` для всех внутриигровых табличек — стены и перекрытия физически блокируют чужой текст.
  - Дистанция отображения кнопок снижена до 28-30 стадов, исключая наслоения.

## Сочность и Game Feel (JuiceEffects)
- **SFX & Pitch Jitter**: Воспроизведение звуков кассы (`cash`), покупки (`buy`), ошибок (`error`), сирены (`siren`), фанфар (`fanfare`), способностей (`powerup`, `slam`, `parry` и др.) со случайной вариацией высоты тона (`PlaybackSpeed 0.94..1.06`) для устранения монотонности.
- **Floating Numbers**: Всплывающий в 3D пространстве текст (+$$$ / урон / фраги).
- **Кнопки**: Анимация сжатия (Squash & Stretch) при покупке и вибрация при недостатке средств.
- **Вспышки экрана и Bloom Pulse**: Золотой эффект при сборе кассы/лута, красный при смерти, динамический импульс Bloom (`screenBloomFlash`) при ультимейтах.
- **Trauma-based Camera Shake**: Физическая тряска экрана по шуму Перлина с квадратичным затуханием ($Trauma^2$), направленный толчок камеры (`cameraKick`).
- **Хитстоп (Hitstop Engine)**: Микро-фриз на 0.07с (`hitstop`) кастера и цели для ощущения сокрушительной массы удара (min 0.07с enforced).
- **Target Impact Flash**: Кратковременный белый световой оверлей на теле жертвы (`impactFlash`) при получении урона.
- **PointLight Dynamic Burst**: Вспышка динамического источника света (`spawnLightBurst`) с тенями и экспоненциальным затуханием, LOD-отсечкой на 120 стадов и минимальной длительностью 0.25с.

## Серверные службы
- `TycoonService`: Экономика, Сейф (`vaultCashMap`), DataStore (`UpdateAsync` с compare-and-set), PvP-лут (`creator` тег), безопасное списание `deductCash` и `addCashRaw` (без множителя для трансферов), NaN/Infinity guard (`sanitizeNum`), проверка владения в `withdrawVault`, параллельное сохранение в `BindToClose` (25с deadline), подключение составных множителей `getExtraMultiplier`, очистка Tools при Rebirth, полная persistence через callbacks (`getPetDataForSave`, `getRetentionDataForSave`, `getProcessedReceipts`, `getPvPStatsForSave`).
- `MonetizationService`: Промышленная обработка чеков `MarketplaceService.ProcessReceipt` с двойной идемпотентностью (RAM + DataStore `ProcessedReceipts_v1`), кэшированием геймпасов (VIP x2, Double Cash x2), реализацией AUTO_COLLECT и SPEED_PERK.
- `RetentionService`: Механика удержания игроков (сессионные подарки Playtime Gifts 5..60м и ежедневный стрик Daily Streak по UTC).
- `PetService`: Индустриальный движок питомцев (взвешенный генератор шансов яиц, `PetService.getEquippedPetDefs`, `equipBest`, суммирование множителей, лимит инвентаря `MAX_INVENTORY_SIZE=75`, `HttpService:GenerateGUID` для UUID). Persistence через `initPlayer(savedPets)` / `getInventoryForSave()`. Сетевой мост через `OpenEggEvent` и `EquippedPetsEvent`.
- `PetFollower` (клиентский модуль): Высокопроизводительный рендеринг питомцев на клиенте через `Heartbeat` (не `RenderStepped`), parenting в `Workspace.PetModels` folder. Поддерживает позиционирование по кругу за спиной персонажа, плавную интерполяцию (Lerp) и синусоидальное парение (`math.sin(time)`).
- `LightingThemes`: Архитектурный модуль атмосферы и освещения по стандарту Future Lighting (`Technology.Future`). Конфигурирует `Atmosphere`, `BloomEffect`, `ColorCorrectionEffect` и `SunRaysEffect`, предоставляя 6 художественных тем (`Cyberpunk`, `SunsetGlow`, `MidnightSciFi`, `CandyDream`, `Wasteland`, `CleanStudio`).
- `PlotManager`: Распределение 8 баз, привязка владельцев.
- `PlotBuilder`: Генерация баз, конвейеров, апгрейдеров, портала Rebirth и монументов:
  - **Панорамные прозрачные окна**: Реальные оконные проемы в стенах 1-го этажа (`BrainrotWalls`) и фасаде 2-го этажа (`Floor2_Walls`), заполненные высокопрозрачным тонированным стеклом (`Transparency = 0.55`) в неоновых рамах.
  - **Подвесной желоб руды 2-го этажа (`OreDropChute`)**: Рассчитан под углом $46^\circ$ с парящим сходом на высоте $Y=5.2$ над Коллектором. Просвет над конвейером 1-го этажа превышает 4.2 стада, полностью исключая заторы руды 1-го этажа.
  - **Храм Rebirth (`Rebirth_Portal`)**: Расположен в просторном правом крыле 2-го этажа ($X=18, Z=20$) в виде величественного святилища с золотыми инкрустациями, четким контрастным билбордом и свободной зоной подхода ($Z=12$).
  - **Комплексная многоуровневая система освещения баз и интерьеров**:
    - Глобальный Ambient (`155, 155, 170`) и OutdoorAmbient (`170, 170, 185`) в `Lighting` сервисе — гарантируют, что закрытые помещения и этажи под крышей никогда не проваливаются в черную тень.
    - Встроенные угловые световые пилоны 1-го этажа (`BaseLightPillar`, `Range = 22`, `Brightness = 0.55`, `Transparency = 0.55`) — приглушённый акцентный свет сразу при создании базы.
    - Встроенные потолочные LED панели (`CeilingLightPanel`) на нижней стороне перекрытия 2-го этажа, светящие вниз на 1-й этаж (`SurfaceLight`, `Brightness = 3.2`, `Range = 45`).
    - Встроенные светящиеся колонны 2-го этажа (`Floor2AmbientPillar`, `Brightness = 2.8`, `Range = 46`) — освещают 2-й этаж сразу при постройке фундамента.
    - Люстры 1-го этажа (`Lighting_Floor1`: 5 люстр с `PointLight Brightness = 0.65, Range = 24` и `SurfaceLight Brightness = 0.5, Range = 18`, trim `Transparency = 0.5`).
    - Пентхаус-освещение 2-го этажа (`Lighting_Floor2`: 6 пилонов + центральная гранд-люстра `Brightness = 4.2`, `Range = 65`).
    - Потолочные световые балки под крышей (`TycoonRoof`, `PL Brightness = 0.55, Range = 20`, `SL Brightness = 0.45, Range = 18`, `beam Transparency = 0.45`).
    - Неоновые полосы стен (`BrainrotWalls`, `Transparency = 0.15`) — приглушены для предотвращения пересвечивания.
- `AbilityService`: Инвентарные тулы способностей, серверный rate-limit (0.3с debounce на `OnServerEvent`), `os.clock()` для субсекундных кулдаунов, PvP-урон с `addCashRaw` (без множителя), `MaxHealth` cap 250, восстановление `WalkSpeed` из `getBaseWalkSpeed`, сохранение transparency при invisibility, обработка уже подключённых игроков, серверная репликация через `AbilityVFXEvent:FireAllClients`. Victim-side VFX: `fireVictimVFX` (VICTIM_IMPACT), `fireBlind` (BLIND) для клиентских эффектов на жертве. Атрибуты: `Invulnerable`, `ReflectDamage`, `DamageVulnerability`, `DoubleDamage`, `TripleDamage`, `SigmaCritActive`, `StunImmune`, `KnockbackImmune`, `AbilityDisabled`. Ongoing godmode VFX: серия ударов через `task.delay` для Skibidi/Sigma/TungTung. Mobility landing AoE: `mobility_land` события для FanumTax/TungTung/CaseOh/Grimace.
- `CharacterAnimator` (клиентский движок процедурной анимации):
  - Полнофункциональная система процедурной анимации без внешних ассетов Roblox (работает автономно для R15 и R6 аватаров).
  - Управление суставами `Motor6D` (`RightShoulder`, `LeftShoulder`, `RightElbow`, `LeftElbow`, `Waist/RootJoint`, `Neck`) через `TweenService` с динамической интерполяцией C0 CFrame.
  - Централизованное управление твинами суставов: таблица со слабыми ссылками `activeJointTweens` и функция `tweenJoint` с обязательной отменой (`:Cancel()`), полным освобождением памяти C++ (`:Destroy()`) предыдущих и завершенных твинов (`tw.Completed`), исключая дерганье и утечки памяти.
  - Валидация живого состояния `isCharacterAlive(character)` и автоматический сброс позы при гибели: регистрация события `Humanoid.Died` в слабом кэше `deadConnections` с вызовом `CharacterAnimator.stopAnimation(character)`, исключающая застревание трупа с выкрученными суставами.
  - Корректная кинематика R6 и R15:
    * В R15 сустав `rootJoint` корректно находится в `HumanoidRootPart:FindFirstChild("Root")` (с fallback на `LowerTorso.Root`).
    * В R6 `RootJoint` наклон торса вперед/назад (Pitch в `playGigachadFlex` и `playGroundPound`) управляется локальной осью Y (`CFrame.Angles(0, angle, 0)`), исключая боковой крен (Roll-глюк).
    * Вращение вокруг вертикальной оси (Yaw в `playSpinSalute`) выполняется по оси Y для R15 и по оси Z для R6.
  - Контроль завершения `PlaybackState.Completed` в `playSpinSalute`: исключает резкие рывки C0 при отмене первой фазы вращения.
  - Инкремент токена `activeAnimTokens[character]` при вызове `restoreJoints`: отменяет любые незавершенные отложенные фазы ударов (`task.delay`) предыдущих способностей.
  - Экспорт метода экстренной остановки `CharacterAnimator.stopAnimation(character)` для интеграции с системами оглушения, рэгдолла и смерти.
  - Защита от заклинивания поз: мгновенный сброс неиспользуемых суставов `restoreJoints(character, joints, 0.08)` в начале любой анимации при прерывании или быстрой смене способностей.
  - Автоматическое кэширование начального положения суставов (`originalC0Cache`) со слабыми ссылками (`__mode = "k"`), предотвращающими утечки памяти при смерти и респавне персонажей.
  - Набор из 8 сигнатурных поз мемов поколения Альфа:
    * `playShhhPose`: легендарный жест тишины (поднятие пальца к губам, наклон головы и выдвижение челюсти) для ультимейта Сигмы и абилок Мьюинга.
    * `playGigachadFlex`: двойной бицепс-флекс (поднятие и сгибание обоих предплечий с наклоном груди назад).
    * `playSigmaTilt`: фирменный холодный наклон головы вбок и легкий разворот торса.
    * `playGroundPound`: сокрушительный прыжковый удар двумя руками о землю.
    * `playHammerSwing`: тяжелый замах кузнечным молотом с разворотом торса.
    * `playRizzlerFlourish`: манерный флуриш рукой у виска с наклоном.
    * `playSpinSalute`: вихревой поворот вокруг вертикальной оси с армейским салютом.
    * `playMoneySnatch`: выпад двумя руками вперед для захвата наличных.
- `CinematicCamera` (клиентский режиссер кинематографической камеры):
  - Модуль драматического управления перспективой камеры во время активации ключевых способностей:
    * `focusCutIn`: кинематографический наезд перед лицом/грудью персонажа с настраиваемым голландским углом (Dutch Angle: наклон горизонта на 10-15 градусов), компрессией FOV и динамическим трекингом персонажа в `RunService.RenderStepped` с защитой от клиппинга.
    * Динамическая защита от клиппинга и окклюзии: рейкасты коллизий исключают всех игроков сервера (`Players:GetPlayers()`), предотвращая упирание камеры во врагов в тесном бою; в цикле `RenderStepped` выполняется проверка окклюзии в реальном времени (`dynRay`), предотвращающая пробитие стен при движении или отбрасывании.
    * `groundSlamPerspective`: драматический нижний ракурс снизу вверх с непрерывным отслеживанием перемещений персонажа в `RenderStepped`, проверкой уровня пола (0, -6, 0) и препятствий позади персонажа (`-root.CFrame.LookVector * desiredDist`) с динамической защитой от пробития стен.
    * `explosiveSnapBack`: мгновенный отскок камеры с импульсом FOV и экраном тряски в момент импакта ультимейтов.
    * Сохранение кастомного FOV игрока: `originalFOV` фиксируется только на время синематика и нормализуется в расширенном безопасном диапазоне `math.clamp(originalFOV, 60, 105)`, предотвращая сброс соревновательных настроек FOV.
    * Защищенный сброс (`resetCamera` / `safeReset`): отключение соединения `cameraUpdateConnection:Disconnect()`, обязательная отмена и удаление твинов камеры `activeCameraTween:Cancel()` + `activeCameraTween:Destroy()`, гарантированное возвращение `CameraType.Custom` и `CameraSubject` к Humanoid при дисконнекте, смерти или респавне (`localPlayer.CharacterAdded`).
- `AbilityVFX` (клиентский движок эффектов):
  - 48 уникальных наборов визуальных и звуковых эффектов (8 фракций x 6 слотов способностей), реализованных по 4-фазной модели (Anticipation -> Release -> World Fracture -> Dissipation).
  - Интеграция с `CharacterAnimator` и `CinematicCamera`: все 8 фракций сопровождаются фирменными позами персонажей и ракурсами камеры при касте способностей с активным вызовом `CinematicCamera.explosiveSnapBack` на фазах решающего импакта ультимейтов и финишеров.
  - Очистка отладочного спама: удален избыточный print из горячего пути `AbilityVFX.play`.
  - Световые неоновые столбы (`createPillarOfLight`), ударные волны расширения (`createShockwaveRing`), двухконтурные текстурированные волны (`spawnTexturedShockwave`), лазерные лучи (`createBeamLine`), объемные лучи с белым сердечником (`spawnVolumetricLaser`).
  - Процедурная физика мира: вылет 3D-камней земли (`spawnEarthFracture`: материал Slate/Basalt с анти-гравитационным зависанием), декали трещин с растворением (`spawnGroundCracks`), втягивающий вихрь частиц (`spawnAnticipationVortex`), вращающийся рунический круг под ногами (`spawnMagicCircle`).
  - Атмосферный наклонный вход падающих объектов (`spawnFallingSkyProp`: метеориты КейсОха, банхаммеры, наковальни и пиццы) с формированием детонационного кратера, света и камней.
  - Оптимизация и бюджетирование: адаптивный лимит активных 3D-камней (`MAX_ACTIVE_ROCKS`: 14 на смартфонах, 24 на ПК) с FIFO-вытеснением старых объектов, динамическое масштабирование партиклов (`getQualityScale()`), отключение теней `PointLight.Shadows` на мобильных GPU и дистанционный отсев (`isWithinLOD`, порог 120 стадов) для гарантированных 60 FPS на смартфонах и слабых ПК.
  - Пространственный 3D-звук (`JuiceEffects.play3DSound`) с затуханием по дистанции.
  - Динамическая кинематографическая отдача: тряска экрана (`JuiceEffects.traumaShake`), направленный толчок (`cameraKick`) и импульс FOV (`JuiceEffects.fovPulse`) с защитой от накопления дрейфа.
  - Ongoing VFX: циклические пульсы эффектов для godmode (Sigma молнии, Skibidi землетрясения, Grimace токсин, TungTung кузнечные удары) через `task.delay`.
  - Victim-side: `VICTIM_IMPACT` (impactFlash + traumaShake на жертве), `BLIND` (белый screenBloomFlash для ослепления), `TELEPORT` (PivotTo на клиенте).
  - Mobility landing: `mobility_land` VFX для FanumTax/TungTung/CaseOh/Grimace (кратер + ударная волна при приземлении).
  - Persistent VFX: нефтяная лужа для FanumTax tactical (`OilPuddleVFX`), слизистая лужа для Grimace mobility (`SlimePuddleVFX`).

## Стандарты типизации (`--!strict` Luau 2026)
- **Безопасные type casts**: Прямые касты `Instance → BasePart`, `Instance → Humanoid` и другие подтипы **запрещены** в `--!strict`. Вместо них используются:
  - `FindFirstChildOfClass("Humanoid")` — нативно возвращает `Humanoid?`.
  - `:: any :: BasePart?` — двойной каст через `any` для именных поисков (`FindFirstChild("HumanoidRootPart")`).
  - `:: any :: IntValue?`, `:: any :: RemoteEvent?` и т.д. — аналогично для всех подтипов Instance.
- **Callback-свойства**: Все внешне назначаемые callbacks (`onPvPKill`, `onItemPurchased`, `hasAnyBase`, `getExtraMultiplier`, `getPlayerPlotIndex`, `getPetDataForSave`, `getRetentionDataForSave`, `getProcessedReceipts`, `getPvPStatsForSave`) объявлены в TycoonService.luau как `nil :: ((args) -> ret)?` для предотвращения `Cannot add property` ошибок.
- `JuiceEffects`: Каталог 3D/2D звуков (`laser`, `dash`, `explosion`, `electric`, `magic`, `teleport`, `meteor`, `hammer`, `splash`, `whoosh`, `chime`, `horn`, `parry`, `snatch`, `anvil`), парящие мемные надписи, вспышки экрана, процедурный праздничный салют конфетти (`spawnConfetti`).
- `LeaderboardService`: Автоматический учет и визуализация топа богатства и фрагов. Статистика сохраняется до рестарта сервера (не стирается при выходе игрока). Поддерживает `restorePvPStats` для восстановления из DataStore.
- `AirDropService`: Фоновый таймер и спавн ящиков с парашютами и захватом.
- `Сетевые RemoteEvents`:
  - `BuyItemEvent`, `WithdrawCashEvent`, `RebirthEvent`, `ToggleGateEvent`.
  - `AbilityEvent`, `AbilityVFXEvent`, `AdminGiveCashEvent`.
  - `OpenEggEvent`, `EquippedPetsEvent`.
  - `ClaimPlaytimeRewardEvent`, `ClaimDailyRewardEvent`.
  - `PromptPurchaseEvent`.

## Инструменты тестирования и администрирования
- `AdminGiveCashEvent` (`RemoteEvent`): Позволяет мгновенно начислить ауру (по умолчанию $1,000,000$) для быстрого тестирования высокоуровневых апгрейдов, Rebirth и Монументов. Защищен проверкой `isAuthorizedAdmin` (`RunService:IsStudio()` / CreatorId), исключая читерство в боевом режиме.
- **Клиентский доступ**: Кнопка `👑 +1M AURA [P]` в HUD и горячая клавиша `[P]` (с защитой от случайного ввода в чате).
- **Чат-команды**: `/aura [amount]` и `/rich [amount]` (серверный парсинг чата с клампом от 1,000 до 100,000,000 и валидацией прав администратора).
- **Game Feel**: Звук кассы, золотая вспышка экрана, floating 3D text `+1,000,000 AURA 👑`, toast уведомление.

## Локальные навыки разработки (.agents/skills)
В проекте настроена библиотека специализированных AI-навыков Antigravity:
1. `rojo-toolchain-master`: Конфигурация Rojo, sourcemap, сборка и live sync.
2. `luau-clean-code`: Строгая типизация Luau, экспорт типов, правила Selene и StyLua.
3. `roblox-data-persistence`: Архитектурные паттерны ProfileService (session locking, anti-dupe, auto-save).
4. `roblox-architecture-knit`: Сервисно-контроллерная архитектура (Knit/Sleitnick), защита сети.
5. `wally-package-manager`: Управление зависимостями Wally и интеграция типов.
6. `roblox-modern-ui`: Декларативный UI на Fusion/React-Lua, реактивность, анимации (Springs).
7. `roblox-ci-cd-opencloud`: Настройка GitHub Actions, сборка .rbxl и деплой через Open Cloud API.
8. `roblox-game-mode-templates`: Готовые шаблоны режимов (Tycoon, Simulator, Minigames/Arena, Obby).
9. `roblox-ability-combat-system`: Боевой цикл способностей (хитбоксы, воздействие, VFX, 3D/2D SFX, camera shake).
10. `roblox-monetization-core`: Защищенный ProcessReceipt (Developer Hub standard), геймпасы и донаты.
11. `roblox-retention-engine`: Playtime Gifts (5-60м), Daily Streak (UTC дни 1-7) для продвижения в алгоритмах.
12. `roblox-pet-gacha-system`: Стандарт Pet Simulator (взвешенный RNG, инвентарь, Equip Best, полет за игроком).
13. `roblox-economy-simulator`: CLI балансировщик (расчет TTFR, симуляция 1000 циклов, устранение затыков).
14. `roblox-lighting-themes`: 6 кинематографичных пресетов освещения Future Lighting (Cyberpunk, Sunset, Sci-Fi и др.).
15. `roblox-juice-kit`: Каталог легальных звуков Roblox и процедурные эффекты (конфетти, всплески, 3D цифры).
16. `roblox-map-templates`: 4 математически выверенных 3D-шаблона карт (Circular Hub, Simulator Zones, PvP Arena, Obby Course).
