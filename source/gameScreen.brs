' ********************************************************************************************************
' ********************************************************************************************************
' **  Roku Donkey Kong Channel - http://github.com/lvcabral/Donkey-Kong-Roku
' **
' **  Created: October 2016
' **  Updated: February 2017
' **
' **  Remake in BrigthScript developed by Marcelo Lv Cabral - http://lvcabral.com
' ********************************************************************************************************
' ********************************************************************************************************

Sub PlayGame()
    'Clear screen (needed for non-OpenGL devices)
    m.mainScreen.Clear(m.colors.black)
    m.mainScreen.SwapBuffers()
    m.mainScreen.Clear(m.colors.black)
    'Initialize flags and aux variables
    m.debug = false
    m.gameOver = false
    m.freeze = false
    'Game Loop
    m.clock.Mark()
    while true
        event = m.port.GetMessage()
        if type(event) = "roUniversalControlEvent" and m.board.sprite <> invalid
            'Handle Remote Control events
            id = event.GetInt()
            if id = m.code.BUTTON_BACK_PRESSED
                StopAudio()
                DestroyChars()
                DestroyStage()
                m.jumpman = invalid
                exit while
            else if id = m.code.BUTTON_INSTANT_REPLAY_PRESSED
                StopAudio()
                ResetGame()
                m.jumpman.usedCheat = true
                m.clock.Mark()
            else if id = m.code.BUTTON_PLAY_PRESSED
                PauseGame()
            else if id = m.code.BUTTON_INFO_PRESSED
                if m.jumpman.lives < m.settings.startLives + 1
                    m.jumpman.lives++
                    m.jumpman.usedCheat = true
                end if
            else if ControlNext(id)
                if m.board.name = "rivets" then FinishLevelScene()
                NextBoard()
                m.jumpman.usedCheat = true
            else if ControlDebug(id)
                m.debug = not m.debug
            else
                m.jumpman.cursors.update(id)
            end if
        else if event = invalid
            'Game screen process
            ticks = m.clock.TotalMilliseconds()
            if ticks > m.speed
                'Update sprites
                if m.board.redraw then DrawBoard()
                KongUpdate()
                LadyUpdate()
                MobsLauncher()
                ObjectsUpdate()
                if m.startup then BoardStartup()
                JumpmanUpdate()
                SoundUpdate()
                'Paint Screen
                m.compositor.AnimationTick(ticks)
                m.compositor.DrawAll()
                DrawScore()
                DrawGrid()
                m.mainScreen.SwapBuffers()
                if m.freeze then stop
                m.freeze = false
                m.clock.Mark()
                UpdateBonusTimer()
                UpdateDifficulty()
                'Check jumpman death
                if not m.gameOver
                    if not m.jumpman.alive
                        StopAudio()
                        JumpmanDeath()
                        if m.jumpman.lives = 0
                            m.gameOver = true
                        else
                            ResetGame()
                            LevelHeightScreen()
                            m.clock.Mark()
                        end if
                    else if m.board.name = "rivets" and m.rivets = 0
                        FinishLevelScene()
                        AddScore(m.currentBonus)
                        NextBoard()
                    else if CheckBoardSuccess()
                        DestroyMobs()
                        BoardCompleteScene()
                        AddScore(m.currentBonus)
                        NextBoard()
                    end if
                end if
                if m.gameOver
                    StopAudio()
                    GameOver()
                    CheckHighScores()
                    DestroyChars()
                    DestroyStage()
                    m.jumpman = invalid
                    exit while
                end if
            end if
        end if
    end while
End Sub

Sub NextBoard()
    if m.currentBoard = m.level.Count()
        m.currentBoard = 1
        m.currentLevel++
    else
        m.currentBoard++
    end if
    ResetGame()
    LevelHeightScreen()
    m.clock.Mark()
End Sub

Sub LevelHeightScreen()
    PlaySound("start-board")
    m.mainScreen.Clear(m.colors.black)
    DrawScore(false)
    kong = CreateObject("roBitmap", "pkg:/assets/images/height-kong.png")
    for b = 1 to m.currentBoard
        label = CreateObject("roBitmap", "pkg:/assets/images/height-" + itostr(b) + ".png")
        m.gameScreen.DrawObject(64, 430 - (kong.GetHeight() * (b -1)) - label.GetHeight(), label)
        m.gameScreen.DrawObject((m.gameWidth - kong.GetWidth()) / 2, 430 - kong.GetHeight() * b, kong)
    next
    m.gameScreen.DrawText("HOW HIGH CAN YOU GET?", 58, 448, m.colors.white, m.gameFont)
    m.mainScreen.SwapBuffers()
    Sleep(2500)
End Sub

Sub DrawBoard()
    bmp = CreateObject("roBitmap", "pkg:/assets/images/board-" + m.board.name + ".png")
    rgn = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
    if m.board.sprite = invalid
        m.board.sprite = m.compositor.NewSprite(0, m.yOff, rgn, m.const.BOARD_Z)
    else
        m.board.sprite.SetRegion(rgn)
    end if
    m.board.sprite.SetMemberFlags(0)
    'Draw objects
    for i = 0 to m.objects.Count() - 1
        DrawObject(m.objects[i])
    next
    m.board.redraw = false
End Sub

Sub DrawObject(obj as object)
    region = m.regions.objects.Lookup(obj.frameName)
    if region <> invalid
        x = (obj.blockX * m.const.BLOCK_WIDTH) + obj.offsetX
        y = ((obj.blockY * m.const.BLOCK_HEIGHT) + obj.offsetY) - region.GetHeight()
        if obj.sprite = invalid
            'Create sprite
            if obj.animation <> invalid or obj.belt <> invalid
                if obj.animation <> invalid
                    animation = obj.animation
                else
                    animation = obj.name + obj.side + m.belts[obj.belt].direction
                end if
                actions = m.anims.objects.sequence.Lookup(animation)
                regions = []
                for each action in actions
                    frame = m.regions.objects.Lookup(obj.name + "-" + itostr(action.id))
                    if action.t <> invalid then frame.SetTime(action.t)
                    'Set custom collision parameters if exists
                    if obj.cx <> invalid
                        frame.SetCollisionRectangle(obj.cx, obj.cy, obj.cw, obj.ch)
                        frame.SetCollisionType(1)
                    end if
                    regions.Push(frame)
                next
                obj.sprite = m.compositor.NewAnimatedSprite(x, y + m.yOff, regions, obj.z)
                obj.sprite.SetData(animation)
            else
                'Set custom collision parameters if exists
                if obj.cx <> invalid
                    region.SetCollisionRectangle(obj.cx, obj.cy, obj.cw, obj.ch)
                    region.SetCollisionType(1)
                end if
                'Create sprite
                obj.sprite = m.compositor.NewSprite(x, y + m.yOff, region, obj.z)
                obj.sprite.SetData(obj.name)
            end if
            if not obj.collide
                obj.sprite.SetMemberFlags(0)
            end if
            obj.sprite.SetDrawableFlag(obj.visible)
        end if
    end if
End Sub

Sub MobsLauncher()
    if m.board.name = "rivets"
        if m.fireChars < 5
            m.board.timer += m.speed
            if m.currentLevel <= 2
                launchTime = 4000
            else if m.currentLevel <= 4
                launchTime = 2000
            else
                launchTime = 1000
            end if
            if m.board.timer > launchTime
                if m.jumpman.blockX < 14
                    launcher = m.board.launchers.right
                    direction = m.const.FACE_LEFT
                else
                    launcher = m.board.launchers.left
                    direction = m.const.FACE_RIGHT
                end if
                max = launcher.Count()
                idx = Rnd(max)-1
                spot = launcher[idx]
                floor = GetFloorOffset(spot.blockX, spot.blockY)
                fireChar = CreateFire(m.const.FIRE_FOX, spot.blockX, spot.blockY, 0, floor, direction)
                DrawObject(fireChar)
                m.objects.Push(fireChar)
                m.board.timer = 0
                m.fireChars++
            end if
        end if
    else if m.board.name = "conveyors"
        'Fire Balls
        if m.fireChars < m.difficulty.level
            m.board.timer += m.speed
            launchTime = 1000
            if m.board.timer > launchTime
                if m.jumpman.blockX < 14
                    direction = m.const.FACE_LEFT
                else
                    direction = m.const.FACE_RIGHT
                end if
                spot = m.board.launchers.center
                fireChar = CreateFire(m.const.FIRE_BALL, spot.blockX, spot.blockY, 4, 0, direction, true)
                DrawObject(fireChar)
                m.objects.Push(fireChar)
                m.board.timer = 0
                m.fireChars++
            end if
        end if
        'Cement trays
        for each belt in m.belts
            if belt.cement
                belt.timer += m.speed
                if belt.timer > belt.launch
                    if belt.direction = "L" then x = belt.xr else x = belt.xl
                    cement = CreateCement(x, belt.y)
                    DrawObject(cement)
                    m.objects.Push(cement)
                    belt.timer = 0
                    belt.launch = Rnd(8) * 1000
                end if
            end if
        next
    else if m.board.name = "elevators"
        if m.fireChars < 2
            direction = m.const.FACE_LEFT
            spot = m.board.launchers.left
            floor = GetFloorOffset(spot.blockX, spot.blockY)
            fireLeft = CreateFire(m.const.FIRE_BALL, spot.blockX, spot.blockY, 0, floor, direction)
            DrawObject(fireLeft)
            m.objects.Push(fireLeft)
            spot = m.board.launchers.right
            floor = GetFloorOffset(spot.blockX, spot.blockY)
            fireRight = CreateFire(m.const.FIRE_BALL, spot.blockX, spot.blockY, 0, floor, direction)
            DrawObject(fireRight)
            m.objects.Push(fireRight)
            m.fireChars += 2
        end if
        m.board.timer += m.speed
        if m.currentLevel <= 2
            launchTime = 2000
        else if m.currentLevel < 4
            launchTime = 1500
        else
            launchTime = 1000
        end if
        if m.board.timer > launchTime
            offsetX = Rnd(3) * 8
            spring = CreateSpring(0, m.kong.blockY, -(32 + offsetX) )
            DrawObject(spring)
            m.objects.Push(spring)
            m.board.timer = 0
        end if
    end if
End Sub

Sub ObjectsUpdate()
    flames = invalid
    for i = 0 to m.objects.Count() - 1
        obj = m.objects[i]
        if obj.sprite <> invalid
            spriteName = obj.sprite.GetData()
            if spriteName = "score"
                if obj.countdown = invalid
                    obj.countdown = 40
                else
                    obj.countdown--
                end if
                if obj.countdown = 0
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    if obj.name = "rivet" and GetBlockType(obj.blockX, obj.blockY) = m.const.MAP_RIVET
                        m.board.map[obj.blockY][Int(obj.blockX / 2)].rivet = invalid
                    end if
                end if
            else if obj.belt <> invalid
                if Right(spriteName, 1) <> m.belts[obj.belt].direction
                    animation = obj.name + obj.side + m.belts[obj.belt].direction
                    actions = m.anims.objects.sequence.Lookup(animation)
                    regions = []
                    for each action in actions
                        frame = m.regions.objects.Lookup(obj.name + "-" + itostr(action.id))
                        if action.t <> invalid then frame.SetTime(action.t)
                        regions.Push(frame)
                    next
                    x = obj.sprite.GetX()
                    y = obj.sprite.GetY()
                    obj.sprite.Remove()
                    obj.sprite = m.compositor.NewAnimatedSprite(x, y, regions, obj.z)
                    obj.sprite.SetData(animation)
                    if not obj.collide
                        obj.sprite.SetMemberFlags(0)
                    end if
                end if
            else if spriteName = "platform"
                elevator = m.elevators[obj.elevator]
                platform = elevator.p[obj.platform]
                curY = ((platform.y * m.const.BLOCK_HEIGHT) + platform.o)
                SetBlockProperties(obj.blockX, platform.y, 0)
                if elevator.up
                    topY = ((elevator.t * m.const.BLOCK_HEIGHT) + elevator.ot)
                    if curY > topY
                        platform.o -= 2
                        if platform.o < -4
                            platform.y--
                            platform.o += m.const.BLOCK_HEIGHT
                        end if
                        obj.sprite.MoveOffset(0, -2)
                        mapY = platform.y
                        mapO = platform.o - 16
                        if mapO < 0
                             mapY--
                             mapO += m.const.BLOCK_HEIGHT
                        end if
                        SetBlockProperties(obj.blockX, mapY, mapO, obj.platform)
                    else
                        platform.y = elevator.b
                        platform.o = elevator.ob
                        curY = ((platform.y * m.const.BLOCK_HEIGHT) + platform.o) - m.const.BLOCK_HEIGHT
                        obj.sprite.MoveTo(obj.sprite.GetX(), curY + m.yOff)
                        mapY = platform.y
                        mapO = platform.o - 16
                        SetBlockProperties(obj.blockX, mapY, mapO, obj.platform)
                    end if
                else
                    botY = ((elevator.b * m.const.BLOCK_HEIGHT) + elevator.ob)
                    if curY < botY
                        platform.o += 2
                        if platform.o > m.const.BLOCK_HEIGHT + 8 and platform.y < 13
                            platform.y++
                            platform.o -= m.const.BLOCK_HEIGHT
                        end if
                        obj.sprite.MoveOffset(0, 2)
                        mapY = platform.y
                        mapO = platform.o - 16
                        if mapO > m.const.BLOCK_HEIGHT and mapY < 13
                            mapY++
                            mapO -= m.const.BLOCK_HEIGHT
                        end if
                        SetBlockProperties(obj.blockX, mapY, mapO, obj.platform)
                    else
                        platform.y = elevator.t
                        platform.o = elevator.ot
                        curY = ((platform.y * m.const.BLOCK_HEIGHT) + platform.o) - m.const.BLOCK_HEIGHT
                        obj.sprite.MoveTo(obj.sprite.GetX(), curY + m.yOff)
                        mapY = platform.y
                        mapO = platform.o - 16
                        SetBlockProperties(obj.blockX, mapY, mapO, obj.platform)
                    end if
                end if
                if m.jumpman.platform <> invalid and Int(m.jumpman.blockX / 2) = Int(obj.blockX / 2) and m.jumpman.platform = obj.platform
                    if elevator.up
                        m.jumpman.offsetY -= 2
                    else
                        m.jumpman.offsetY += 2
                    end if
                    if m.jumpman.offsetY < 0
                        m.jumpman.blockY--
                        m.jumpman.offsetY += m.const.BLOCK_HEIGHT
                    else if m.jumpman.offsetY >= m.const.BLOCK_HEIGHT
                        m.jumpman.blockY++
                        m.jumpman.offsetY -= m.const.BLOCK_HEIGHT
                    end if
                end if
            else if spriteName = "flames"
                flames = obj
            else if Left(spriteName, 7) = "barrel-"
                obj.update(m.jumpman.blockX, m.jumpman.blockY)
                if spriteName <> obj.animation
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    DrawObject(obj)
                end if
                if Abs(obj.offsetX) <= m.const.BLOCK_WIDTH * 2
                    region = obj.sprite.GetRegion()
                    x = (obj.blockX * m.const.BLOCK_WIDTH) + obj.offsetX
                    y = ((obj.blockY * m.const.BLOCK_HEIGHT) + obj.offsetY) - region.GetHeight()
                    if obj.bounce <> invalid
                        if obj.action = m.const.BARREL_ROLL
                            bounceArray = [0, 1, 2, 2, 2, 1, 0, 0, 0, 1, 1]
                        else
                            bounceArray = [0, 3, 6, 6, 6, 3, 0, 0, 0, 2, 1]
                        end if
                        y -= bounceArray[obj.bounce]
                        obj.bounce++
                        if obj.bounce = bounceArray.Count() then obj.bounce = invalid
                    end if
                    obj.sprite.MoveTo(x, y + m.yOff)
                    objHit = obj.sprite.CheckCollision()
                    if objHit <> invalid and objHit.GetData() = "oil"
                        obj.sprite.Remove()
                        obj.sprite = invalid
                        if flames <> invalid and flames.sprite <> invalid and not flames.visible
                            flames.sprite.SetDrawableFlag(true)
                            flames.visible = true
                        end if
                        if obj.animation.Right(1) = "b" and m.fireChars < 5
                            fireChar = CreateFire(m.const.FIRE_BALL, obj.blockX, obj.blockY, obj.offsetX, obj.offsetY, m.const.FACE_RIGHT, true)
                            DrawObject(fireChar)
                            m.objects.Push(fireChar)
                            m.fireChars++
                        end if
                    end if
                else
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    print "destroyed barrel sprite "; m.objects.Count()
                end if
            else if Left(spriteName, 4) = "fire"
                obj.update(m.jumpman.blockX, m.jumpman.blockY)
                redraw = (spriteName <> obj.animation)
                if m.jumpman.hammer <> invalid and m.jumpman.hammer.countdown > 0
                    if Right(obj.name, 3) = "red"
                        obj.name = obj.name.Replace("red", "blue")
                        redraw = true
                    end if
                else if Right(obj.name, 4) = "blue"
                    obj.name = obj.name.Replace("blue", "red")
                    redraw = true
                end if
                if redraw
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    DrawObject(obj)
                end if
                if Abs(obj.offsetX) <= m.const.BLOCK_WIDTH * 2
                    region = obj.sprite.GetRegion()
                    x = (obj.blockX * m.const.BLOCK_WIDTH) + obj.offsetX
                    y = ((obj.blockY * m.const.BLOCK_HEIGHT) + obj.offsetY) - region.GetHeight()
                    if obj.move < obj.MOVE_LSPAWN
                        bounceArray = [0, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2, 0]
                        y -= bounceArray[obj.bounce]
                        obj.bounce++
                        if obj.bounce = bounceArray.Count() then obj.bounce = 0
                    end if
                    obj.sprite.MoveTo(x, y + m.yOff)
                else
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    print "destroyed fire sprite "; m.objects.Count()
                end if
            else if spriteName = "cement"
                obj.update()
                if Abs(obj.offsetX) <= m.const.BLOCK_WIDTH * 2
                    region = obj.sprite.GetRegion()
                    x = (obj.blockX * m.const.BLOCK_WIDTH) + obj.offsetX
                    y = ((obj.blockY * m.const.BLOCK_HEIGHT) + obj.offsetY) - region.GetHeight()
                    obj.sprite.MoveTo(x, y + m.yOff)
                    objHits = obj.sprite.CheckMultipleCollisions()
                    if objHits <> invalid
                        for each hit in objHits
                            if hit.GetData() = "flames" and hit.GetX() = obj.sprite.GetX()
                                obj.sprite.Remove()
                                obj.sprite = invalid
                                print "destroyed cement sprite at flames "; m.objects.Count()
                            end if
                        next
                    end if
                else
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    print "destroyed cement sprite off screen "; m.objects.Count()
                end if
            else if spriteName = "spring"
                obj.update()
                if obj.blockY <= 13
                    region = obj.sprite.GetRegion()
                    x = (obj.blockX * m.const.BLOCK_WIDTH) + obj.offsetX
                    y = ((obj.blockY * m.const.BLOCK_HEIGHT) + obj.offsetY) - region.GetHeight()
                    obj.sprite.MoveTo(x, y + m.yOff)
                else
                    obj.sprite.Remove()
                    obj.sprite = invalid
                    print "destroyed spring sprite off screen "; m.objects.Count()
                end if
            else if spriteName = "ladder"
                obj.timer += m.speed
                if obj.state = m.const.LADDER_AT_TOP
                    if obj.timer > obj.delay
                        obj.state = m.const.LADDER_MOVE_DOWN
                        obj.step = 0
                        LadderState(obj.blockX, obj.blockY-1, false)
                    end if
                else if obj.state = m.const.LADDER_MOVE_DOWN
                    obj.step++
                    if obj.step <= m.const.BLOCK_HEIGHT
                        obj.sprite.MoveOffset(0, 1)
                    else
                        obj.state = m.const.LADDER_AT_BOTTOM
                        da = [100, 200, 300, 500, 1000, 2000]
                        obj.delay = da[Rnd(6) - 1]
                        obj.timer = 0
                    end if
                else if obj.state = m.const.LADDER_AT_BOTTOM
                    if obj.timer > obj.delay
                        obj.state = m.const.LADDER_MOVE_UP
                        obj.step = 0
                    end if
                else if obj.state = m.const.LADDER_MOVE_UP
                    obj.step++
                    if obj.step <= m.const.BLOCK_HEIGHT
                        obj.sprite.MoveOffset(0, -1)
                    else
                        obj.state = m.const.LADDER_AT_TOP
                        obj.delay = 4000 '4 seconds on top
                        obj.timer = 0
                        LadderState(obj.blockX, obj.blockY-1, true)
                    end if
                end if
            end if
        end if
    next
    if flames <> invalid then m.oilOnFire = flames.visible
End Sub

Sub DrawScore(showBonus = true as boolean)
    'Paint lifes
    life = m.regions.objects.Lookup("life")
    for t = 1 to m.jumpman.lives
        m.gameScreen.DrawObject(16 * t, 12, life)
    next
    'Paint score
    leftOff = ((m.mainWidth - 640) / 2)
    m.gameLeft.Clear(m.colors.black)
    if m.flash = invalid or not showBonus then m.flash = {timer:0, on: true}
    m.flash.timer += m.const.GAME_SPEED
    if m.flash.timer > 240
        m.flash.timer = 0
        m.flash.on = not m.flash.on
    end if
    if m.flash.on
        m.gameLeft.DrawText("1UP", leftOff + 24, 12, m.colors.red, m.gameFont)
    end if
    m.gameLeft.DrawText(zeroPad(m.gameScore, 6), leftOff, 28, m.colors.white, m.gameFont)
    m.gameRight.Clear(m.colors.black)
    m.gameRight.DrawText("HIGH", 16, 12, m.colors.red, m.gameFont)
    m.gameRight.DrawText(zeroPad(m.highScore, 6), 0, 28, m.colors.white, m.gameFont)
    m.gameScreen.DrawText("L=" + zeroPad(m.currentLevel), 340 , 12, m.colors.blue, m.gameFont)
    if showBonus
        if m.currentBonus > 999
            m.gameScreen.DrawText(itostr(m.currentBonus), 354, m.yOff + 32, Val(m.board.fontColors[0], 0), m.gameFont)
        else
            m.gameScreen.DrawText(zeroPad(m.currentBonus, 3), 370, m.yOff + 32, Val(m.board.fontColors[1], 0), m.gameFont)
        end if
    end if
End Sub

Sub DrawGrid()
    if m.debug
        bmp = CreateObject("roBitmap", "pkg:/assets/images/board-grid.png")
        rgn = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
        if m.board.grid = invalid
            m.board.grid = m.compositor.NewSprite(0, m.yOff, rgn, m.const.CHARS_Z + 10)
        end if
    else if m.board.grid <> invalid
        m.board.grid.Remove()
        m.board.grid = invalid
    end if
End Sub

Sub JumpmanUpdate()
    m.jumpman.update()
    region = m.regions.jumpman.Lookup(m.jumpman.frameName)
    if region <> invalid
        region.SetCollisionRectangle(11, 16, 10, 16)
        region.SetCollisionType(1)
        x = (m.jumpman.blockX * m.const.BLOCK_WIDTH) + m.jumpman.offsetX
        y = ((m.jumpman.blockY * m.const.BLOCK_HEIGHT) + m.jumpman.offsetY) - region.GetHeight()
        if m.jumpman.state = m.jumpman.STATE_MOVE
            PlaySound("walk", false, 50)
        else if m.jumpman.state = m.jumpman.STATE_JUMP and m.jumpman.frame = 1
            PlaySound("jump")
        end if
        if m.jumpman.sprite = invalid
            m.jumpman.sprite = m.compositor.NewSprite(x, y + m.yOff, region, m.const.CHARS_Z)
            m.jumpman.sprite.SetData("jumpman")
        else
            m.jumpman.sprite.SetRegion(region)
            m.jumpman.sprite.MoveTo(x, y + m.yOff)
            'Check jump over objects
            if m.jumpman.state = m.jumpman.STATE_JUMP and m.jumpman.frame = 10  'top of the jump
                pts = 0
                for i = 0 to m.objects.Count() - 1
                    obj = m.objects[i]
                    if obj.sprite <> invalid
                        if obj.name = "rivet" and m.jumpman.jump <> m.const.ACT_JUMP_UP
                            if Abs(m.jumpman.blockX-obj.blockX) <= 1 and obj.blockY > m.jumpman.blockY and obj.blockY - m.jumpman.blockY <= 2
                                pts = 100
                                score = obj.sprite
                                score.MoveOffset(-8, 0)
                                if m.rivets > 0 then m.rivets--
                                exit for
                            end if
                        else if Right(obj.name, 7) = "rolling" or Left(obj.name, 4) = "fire" or obj.name = "cement"
                            if Abs(m.jumpman.blockX-obj.blockX) <= 1 and obj.blockY >= m.jumpman.blockY and obj.blockY - m.jumpman.blockY <= 2
                                if pts = 0
                                    pts = 100
                                    x = obj.sprite.GetX()
                                    y = obj.sprite.GetY() - 8
                                    rg = m.regions.objects.Lookup("points-100")
                                    score = m.compositor.NewSprite(x, y, rg, m.const.OBJECTS_Z)
                                    m.objects.Push({name: "score", sprite: score, blockX: obj.blockX, blockY: obj.blockY})
                                else if pts = 100
                                    pts = 300
                                else
                                    pts = 500
                                end if
                            end if
                        end if
                    end if
                next
                if pts > 0
                    AddScore(pts)
                    PlaySound("get-item")
                    score.SetRegion(m.regions.objects.Lookup("points-" + itostr(pts)))
                    score.SetMemberFlags(0)
                    score.SetData("score")
                end if
            end if
            'Check collision with objects
            objSprite = m.jumpman.sprite.CheckCollision()
            if objSprite <> invalid
                objName = objSprite.GetData()
                if objName = "hat" or objName = "parasol" or objName = "purse" or objName = "rivet"
                    print "collected item: " + objName
                    if objName = "rivet"
                        ptr = m.regions.objects.Lookup("points-100")
                        AddScore(100)
                        objSprite.MoveOffset(-8, 0)
                        if m.rivets > 0 then m.rivets--
                    else if m.currentLevel = 1
                        ptr = m.regions.objects.Lookup("points-300")
                        AddScore(300)
                    else if m.currentLevel = 2
                        ptr = m.regions.objects.Lookup("points-500")
                        AddScore(500)
                    else
                        ptr = m.regions.objects.Lookup("points-800")
                        AddScore(800)
                    end if
                    objSprite.SetRegion(ptr)
                    objSprite.SetMemberFlags(0)
                    objSprite.SetData("score")
                    PlaySound("get-item")
                else if objName = "hammer"
                    print "got hammer!"
                    m.jumpman.hammer = {}
                    m.jumpman.hammer.countdown = m.const.HAMMER_TIME
                    m.jumpman.hammer.color = "hbr"
                    m.jumpman.hammer.up = true
                    m.jumpman.hammer.sprite = objSprite
                    StopAudio()
                    PlaySong("background-3", true)
                else if objName = "oil"
                    print "Ignore oil"
                else
                    m.jumpman.alive = m.jumpman.immortal
                end if
            end if
            if not m.jumpman.alive
                if m.jumpman.hammer <> invalid
                    m.jumpman.hammer.sprite.Remove()
                    m.jumpman.hammer.sprite = invalid
                    m.jumpman.hammer = invalid
                end if
            else if m.jumpman.state = m.jumpman.STATE_JUMP and m.jumpman.hammer <> invalid
                m.jumpman.hammer.sprite.MoveTo(x + 4, y - 20 + m.yOff)
            else if Left(m.jumpman.charAction, 3) = "hit"
                m.jumpman.hammer.countdown--
                if m.jumpman.hammer.countdown = 0
                    'replace jumpman frame
                    m.jumpman.charAction = m.jumpman.charAction.Replace("hit", "run")
                    m.jumpman.frame = 0
                    m.jumpman.frameName = m.jumpman.getFrameName(m.jumpman.charAction, m.jumpman.frame)
                    region = m.regions.jumpman.Lookup(m.jumpman.frameName)
                    region.SetCollisionRectangle(11, 16, 10, 16)
                    region.SetCollisionType(1)
                    m.jumpman.sprite.SetRegion(region)
                    'remove hammer sprite
                    m.jumpman.hammer.sprite.Remove()
                    m.jumpman.hammer.sprite = invalid
                    m.jumpman.hammer = invalid
                    'restore board background audio
                    StopAudio()
                    if m.board.audio <> invalid then PlaySong(m.board.audio, true)
                else
                    if m.jumpman.hammer.countdown < m.const.HAMMER_TIME / 2
                        if m.jumpman.hammer.countdown mod 3 = 0
                            if m.jumpman.hammer.color = "hbr"
                                m.jumpman.hammer.color = "hor"
                            else
                                m.jumpman.hammer.color = "hbr"
                            end if
                        end if
                    end if
                    haction = m.jumpman.charAction.Replace("hit", m.jumpman.hammer.color)
                    if m.jumpman.hammer.up then ps = "Up" else ps = "Dn"
                    if m.jumpman.state <> m.jumpman.STATE_STOP
                        hframe = m.jumpman.getFrameName(haction + ps, m.jumpman.frame)
                    else
                        hframe = m.jumpman.getFrameName(haction + ps, 2)
                    end if
                    hrgn = m.regions.jumpman.Lookup(hframe)
                    hx = x
                    hy = y
                    if hrgn.GetWidth() > m.const.BLOCK_WIDTH * 2
                        if Mid(haction, 4, 4) = "Left"
                            hx -= (hrgn.GetWidth() - m.const.BLOCK_WIDTH * 2)
                            hrgn.SetCollisionRectangle(0, 12, 14, 16)
                        else
                            hrgn.SetCollisionRectangle(42, 12, 14, 16)
                        end if
                    else if hrgn.GetHeight() > m.const.BLOCK_HEIGHT
                        hy -= (hrgn.GetHeight() - m.const.BLOCK_HEIGHT)
                        if Mid(haction, 4, 4) = "Left"
                            hrgn.SetCollisionRectangle(6, 2, 18, 10)
                        else
                            hrgn.SetCollisionRectangle(8, 2, 18, 10)
                        end if
                    end if
                    hrgn.SetCollisionType(1)
                    m.jumpman.hammer.sprite.SetRegion(hrgn)
                    m.jumpman.hammer.sprite.MoveTo(hx, hy + m.yOff)
                    objHit = m.jumpman.hammer.sprite.CheckCollision()
                    if objHit <> invalid and CanSmash(objHit)
                        print "hit barrel or fire char"
                        SmashMob(objHit)
                        'points distribution:
                        'orange = 300
                        'blue = 25% 300, 50% 500, 25% 800
                        'fire = 50% 300, 33% 500, 17% 800
                        if Right(objHit.GetData(), 1) = "o"
                            pts = 300
                        else if Right(objHit.GetData(), 1) = "b" or objHit.GetData() = "cement"
                            apt = [300, 500, 500, 800]
                            pts = apt[Rnd(4) - 1]
                        else
                            apt = [300, 300, 300, 500, 500, 800]
                            pts = apt[Rnd(6) - 1]
                            m.fireChars--
                        end if
                        AddScore(pts)
                        objHit.SetRegion(m.regions.objects.Lookup("points-" + itostr(pts)))
                        objHit.SetMemberFlags(0)
                        objHit.SetData("score")
                        PlaySound("get-item")
                    end if
                end if
            end if
        end if
    end if
End Sub

Sub JumpmanDeath()
    Sleep(1000)
    DestroyMobs()
    PlaySound("death")
    m.jumpman.state = m.jumpman.STATE_MOVE
    if Right(m.jumpman.charAction,4) = "Left"
        m.jumpman.charAction = "dieLeft"
    else
        m.jumpman.charAction = "dieRight"
    end if
    m.jumpman.frame = 0
    while true
        ticks = m.clock.TotalMilliseconds()
        if ticks > m.speed
            m.jumpman.frameUpdate()
            m.jumpman.sprite.SetRegion(m.regions.jumpman.Lookup(m.jumpman.frameName))
            m.compositor.DrawAll()
            DrawScore()
            m.mainScreen.SwapBuffers()
            m.clock.Mark()
        end if
        if m.jumpman.frame = 0 then exit while
    end while
    Sleep(2000)
End Sub

Sub SmashMob(sprite as object)
    PlaySound("smash")
    sprite.SetZ(m.const.OBJECTS_Z + 1)
    region = sprite.GetRegion()
    if region.GetHeight() < m.const.BLOCK_HEIGHT then sprite.MoveOffset(0, -8)
    obj = {}
    obj.frame = 0
    while true
        ticks = m.clock.TotalMilliseconds()
        if ticks > m.speed
            actionArray = m.anims.objects.sequence.Lookup("explode")
            frame = actionArray[obj.frame]
            frameName = "explode-" + itostr(frame.id)
            if obj.cycles = invalid
                obj.cycles = Int(frame.t / m.speed)
            else
                obj.cycles--
            end if
            if obj.cycles = 0
                obj.frame++
                obj.cycles = invalid
            end if
            sprite.SetRegion(m.regions.objects.Lookup(frameName))
            m.compositor.DrawAll()
            DrawScore()
            m.mainScreen.SwapBuffers()
            m.clock.Mark()
            if obj.frame = actionArray.Count() then exit while
        end if
    end while
End Sub

Sub KongUpdate()
    m.kong.update()
    region = m.regions.kong.Lookup(m.kong.frameName)
    x = (m.kong.blockX * m.const.BLOCK_WIDTH) + m.kong.offsetX
    y = ((m.kong.blockY * m.const.BLOCK_HEIGHT) + m.kong.offsetY) - region.GetHeight()
    if Left(m.kong.charAction, 4) = "roll"
        if m.kong.sprite = invalid
            m.kong.sprite = m.compositor.NewSprite(x, y + m.yOff, region, m.const.CHARS_Z)
            m.kong.sprite.SetData("kong")
        else
            m.kong.sprite.SetRegion(region)
            m.kong.sprite.MoveTo(x, y + m.yOff)
        end if
        if m.kong.frame = 0 and m.kong.barrels >= 0
            if m.kong.barrels = m.const.OIL_BARREL_FREQ - 1
                m.kong.charAction = "rollBlueBarrel"
            else
                m.kong.charAction = "rollOrangeBarrel"
            end if
        end if
        if m.kong.frameEvent = "barrel"
            m.kong.barrels++
            if m.kong.barrels = 0
                color = "b"
                action = m.const.BARREL_WILD
            else
                if m.kong.barrels >= m.const.OIL_BARREL_FREQ and m.fireChars < 5
                    color = "b"
                else
                    color = "o"
                end if
                action = m.const.BARREL_ROLL
                if Rnd(16) = 16 then action = m.const.BARREL_WILD
            end if
            barrel = CreateBarrel(color, action)
            DrawObject(barrel)
            m.objects.Push(barrel)
            if color = "b" then m.kong.barrels = 0
        end if
    else if m.kong.sprite = invalid or m.kong.sprite.GetData() <> m.kong.charAction
        actions = m.anims.kong.sequence.Lookup(m.kong.charAction)
        regions = []
        for each action in actions
            frame = m.regions.kong.Lookup("kong-" + itostr(action.id))
            if action.t <> invalid then frame.SetTime(action.t)
            regions.Push(frame)
        next
        if m.kong.sprite <> invalid then m.kong.sprite.Remove()
        m.kong.sprite = m.compositor.NewAnimatedSprite(x, y + m.yOff, regions,  m.const.CHARS_Z)
        m.kong.sprite.SetData(m.kong.charAction)
    else
        m.kong.sprite.MoveTo(x, y + m.yOff)
    end if
End Sub

Sub LadyUpdate()
    if m.lady.face = m.const.FACE_AUTO
        if m.jumpman.blockX < 14
            curFace = m.const.FACE_LEFT
        else
            curFace = m.const.FACE_RIGHT
        end if
    else
        curFace = m.lady.face
    end if
    if curFace = m.const.FACE_LEFT
        m.lady.charAction = "faceLeft"
    else
        m.lady.charAction = "faceRight"
    end if
    actions = m.anims.lady.sequence.Lookup(m.lady.charAction)
    m.lady.frameName = "pauline-" + itostr(actions[m.lady.frame].id)
    region = m.regions.lady.Lookup(m.lady.frameName)
    if region <> invalid
        'Show Pauline
        x = (m.lady.blockX * m.const.BLOCK_WIDTH) + m.lady.offsetX
        y = ((m.lady.blockY * m.const.BLOCK_HEIGHT) + m.lady.offsetY) - region.GetHeight()
        if m.lady.sprite = invalid
            m.lady.sprite = m.compositor.NewSprite(x, y + m.yOff, region, m.const.CHARS_Z)
            m.lady.sprite.SetData("lady")
            m.lady.sprite.SetMemberFlags(0)
        else
            m.lady.sprite.SetRegion(region)
            m.lady.sprite.MoveTo(x, y + m.yOff)
        end if
        'Show help shout
        if m.lady.frame >= 94
            if curFace = m.const.FACE_LEFT
                x -= 56
                y += 8
            else
                x += 30
                y += 6
            end if
            helpFrame = "help-" + m.lady.help.color + "-" + itostr(curFace)
            hrg = m.regions.lady.Lookup(helpFrame)
            if hrg <> invalid
                if m.lady.help.sprite = invalid
                    m.lady.help.sprite = m.compositor.NewSprite(x, y, hrg, m.const.CHARS_Z)
                else
                    m.lady.help.sprite.SetRegion(hrg)
                    m.lady.help.sprite.MoveTo(x, y)
                end if
                m.lady.help.sprite.SetMemberFlags(0)
                m.lady.help.sprite.SetDrawableFlag(true)
            end if
        else if m.lady.help.sprite <> invalid
            m.lady.help.sprite.SetDrawableFlag(false)
        end if
        m.lady.frame++
        if m.lady.frame = actions.Count() then m.lady.frame = 0
    end if
End Sub

Sub BoardStartup()
    m.compositor.DrawAll()
    DrawScore()
    m.mainScreen.SwapBuffers()
    Sleep(1000)
    if not m.jumpman.alive
        m.jumpman.alive = true
        m.jumpman.lives--
    end if
    m.startup = false
    StopSound()
    if m.board.audio <> invalid then PlaySong(m.board.audio, true)
End Sub

Function CheckBoardSuccess() as boolean
    return (m.board.complete <> invalid and m.jumpman.blockY = m.board.complete.y and m.jumpman.offsetY = m.board.complete.o)
End Function

Sub UpdateBonusTimer()
    m.bonus.timer += m.speed
    if m.currentBonus >= 100 and m.bonus.timer > m.bonus.time
        m.currentBonus -= 100
        m.bonus.timer = 0
    else if m.currentBonus = 0 and m.bonus.timer > 4283 and m.jumpman.state <> m.jumpman.STATE_JUMP
        m.jumpman.alive = m.jumpman.immortal
    end if
End Sub

Sub UpdateDifficulty()
    m.difficulty.timer += m.speed
    if m.difficulty.timer > 33333
        m.difficulty.timer = 0
        if m.difficulty.level < 5 then m.difficulty.level++
        print "changed difficulty to "; m.difficulty.level
    end if
End Sub

Sub DestroyChars()
    if m.kong <> invalid
        if m.kong.sprite <> invalid
            m.kong.sprite.Remove()
            m.kong.sprite = invalid
        end if
        m.kong = invalid
    end if
    if m.lady <> invalid
        if m.lady.sprite <> invalid
            m.lady.sprite.Remove()
            m.lady.sprite = invalid
        end if
        if m.lady.help.sprite <> invalid
            m.lady.help.sprite.Remove()
            m.lady.help.sprite = invalid
        end if
        m.lady = invalid
    end if
    if m.jumpman <> invalid
        if m.jumpman.sprite <> invalid
            m.jumpman.sprite.Remove()
            m.jumpman.sprite = invalid
        end if
        if m.jumpman.hammer <> invalid
            if m.jumpman.hammer.sprite <> invalid
                m.jumpman.hammer.sprite.Remove()
                m.jumpman.hammer.sprite = invalid
            end if
            m.jumpman.hammer = invalid
        end if
    end if
    if m.heart <> invalid
        m.heart.Remove()
        m.heart = invalid
    end if
End Sub

Sub DestroyStage()
    if m.board.sprite <> invalid
        m.board.sprite.Remove()
        m.board.sprite = invalid
    end if
    if m.board.grid <> invalid
        m.board.grid.Remove()
        m.board.grid = invalid
    end if
    DestroyObjects()
End Sub

Sub DestroyMobs()
    if m.board.name = "barrels"
        DestroyObjects(["barrel-", "fire", "score"])
    else if  m.board.name = "conveyors"
        DestroyObjects(["cement", "fire", "score"])
    else if  m.board.name = "elevators"
        DestroyObjects(["spring", "fire", "score"])
    else
        DestroyObjects(["fire", "score"])
    end if
End Sub

Sub DestroyObjects(filter = [] as object)
    if m.objects <> invalid
        for i = 0 to m.objects.Count()
            if m.objects[i] <> invalid
                if m.objects[i].sprite <> invalid
                    remove = false
                    if filter.Count() = 0
                        remove = true
                    else
                        for each term in filter
                            if InStr(1, m.objects[i].sprite.GetData(), term) > 0
                                remove = true
                                exit for
                            end if
                        next
                    end if
                    if remove
                        m.objects[i].sprite.Remove()
                        m.objects[i].sprite = invalid
                    end if
                end if
            end if
        next
        if filter.Count() = 0 then m.objects = invalid
    end if
End Sub

Sub PauseGame()
    m.audioPlayer.Pause()
    text = "GAME  PAUSED"
    textWidth = m.gameFont.GetOneLineWidth(text, m.gameWidth)
    textHeight = m.gameFont.GetOneLineHeight()
    x = Cint((m.gameWidth - textWidth) / 2)
    y = 308
    m.gameScreen.DrawRect(x - 32, y - 32, textWidth + 64, textHeight + 64, m.colors.black)
    m.gameScreen.DrawText(text, x, y, Val(m.board.fontColors[0], 0), m.gameFont)
    m.mainScreen.SwapBuffers()
    while true
        key = wait(0, m.port)
        if key = m.code.BUTTON_PLAY_PRESSED then exit while
    end while
    m.audioPlayer.Play()
    m.clock.Mark()
End Sub

Sub GameOver()
    text = "GAME  OVER"
    textWidth = m.gameFont.GetOneLineWidth(text, m.gameWidth)
    textHeight = m.gameFont.GetOneLineHeight()
    x = Cint((m.gameWidth - textWidth) / 2)
    y = 308
    m.gameScreen.DrawRect(x - 32, y - 32, textWidth + 64, textHeight + 64, m.colors.black)
    m.gameScreen.DrawText(text, x, y, Val(m.board.fontColors[0], 0), m.gameFont)
    m.mainScreen.SwapBuffers()
    while true
        key = wait(3000, m.port)
        if key = invalid or key < 100 then exit while
    end while
End Sub

Function ControlNext(id as integer) as boolean
    vStatus = m.settings.controlMode = m.const.CONTROL_VERTICAL and id = m.code.BUTTON_A_PRESSED
    hStatus = m.settings.controlMode = m.const.CONTROL_HORIZONTAL and id = m.code.BUTTON_FAST_FORWARD_PRESSED
    return vStatus or hStatus
End Function

Function ControlDebug(id as integer) as boolean
    vStatus = m.settings.controlMode = m.const.CONTROL_VERTICAL and id = m.code.BUTTON_B_PRESSED
    hStatus = m.settings.controlMode = m.const.CONTROL_HORIZONTAL and id = m.code.BUTTON_REWIND_PRESSED
    return vStatus or hStatus
End Function
