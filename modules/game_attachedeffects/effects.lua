--[[
    register(id, name, thingId, thingType, config)
    config = {
        speed, disableWalkAnimation, shader, drawOnUI, opacity
        duration, loop, transform, hideOwner, followOwner, size{width, height}
        offset{x, y, onTop}, dirOffset[dir]{x, y, onTop},
        light { color, intensity}, drawOrder(only for tiles),
        bounce{minHeight, height, speed},
        pulse{minHeight, height, speed},
        fade{start, end, speed}

        onAttach, onDetach
    }
]]
--
AttachedEffectManager.register(1, 'Spoke Lighting', 12, ThingCategoryEffect, {
    speed = 0.5,
    onAttach = function(effect, owner)
        print('onAttach: ', effect:getId(), owner:getName())
    end,
    onDetach = function(effect, oldOwner)
        print('onDetach: ', effect:getId(), oldOwner:getName())
    end
})

-- Use the paperdoll system instead of attachedEffect for this kind of attachment, it’s more consistent.
AttachedEffectManager.register(2, 'Bat Wings', 307, ThingCategoryCreature, {
    speed = 5,
    disableWalkAnimation = true,
    shader = 'Outfit - Rainbow',
    followOwner = true,
    dirOffset = {
        [North] = { 0, -10, true },
        [East] = { 5, -5 },
        [South] = { -5, 0 },
        [West] = { -10, -5, true }
    },
    onAttach = function(effect, owner)
        owner:setBounce(0, 10, 5000)
    end,
    onDetach = function(effect, oldOwner)
        oldOwner:setBounce(0, 0)
    end
})

AttachedEffectManager.register(3, 'Angel Light', 50, ThingCategoryEffect, {
    opacity = 0.5,
    drawOnUI = false
})

AttachedEffectManager.register(4, 'Four Angel Light', 0, 0, {
    onAttach = function(effect, owner)
        local angelLight = g_attachedEffects.getById(3)
        local angelLight1 = angelLight:clone()
        local angelLight2 = angelLight:clone()
        local angelLight3 = angelLight:clone()
        local angelLight4 = angelLight:clone()

        angelLight1:setOffset(-50, 50, true)
        angelLight2:setOffset(50, 50, true)
        angelLight3:setOffset(50, -50, true)
        angelLight4:setOffset(-50, -50, true)

        effect:attachEffect(angelLight1)
        effect:attachEffect(angelLight2)
        effect:attachEffect(angelLight3)
        effect:attachEffect(angelLight4)
    end
})

AttachedEffectManager.register(5, 'Transform', 40, ThingCategoryCreature, {
    transform = true,
    duration = 5000,
    onAttach = function(effect, owner)
        local e = Effect.create()
        e:setId(7)
        owner:getTile():addThing(e)
    end,
    onDetach = function(effect, oldOwner)
        local e = Effect.create()
        e:setId(50)
        oldOwner:getTile():addThing(e)
    end
})

AttachedEffectManager.register(6, 'Lake Monster', 34, ThingCategoryEffect, {
    hideOwner = true,
    duration = 1500,
    -- loop = 1,
    onDetach = function(effect, oldOwner)
        local e = Effect.create()
        e:setId(54)
        oldOwner:getTile():addThing(e)
    end
})

AttachedEffectManager.register(7, 'Pentagram Aura', '/images/game/effects/pentagram', ThingExternalTexture, {
    size = { 128, 128 },
    offset = { 50, 45 }
})

AttachedEffectManager.register(8, 'Ki', '/images/game/effects/ki', ThingExternalTexture, {
    size = { 140, 110 },
    offset = { 60, 75, true },
    pulse = { 0, 50, 3000 },
    --fade = { 0, 100, 1000 },
})

AttachedEffectManager.register(9, 'Thunder', '/images/game/effects/thunder', ThingExternalTexture, {
    loop = 1,
    offset = { 215, 230 }
})

AttachedEffectManager.register(10, 'Dynamic Effect', 0, 0, {
    duration = 500,
    onAttach = function(effect, owner)
        local spriteSize = g_gameConfig.getSpriteSize()
        local length = 3

        local missile = AttachedEffect.create(38, ThingCategoryMissile)
        missile:setDuration(effect:getDuration())
        missile:setDirection(5)
        missile:setOffset(spriteSize * length, 0)
        missile:setBounce(0, 15, 1000)
        missile:move(Position.translated(owner:getPosition(), -length, 0), owner:getPosition())
        effect:attachEffect(missile)

        missile = AttachedEffect.create(38, ThingCategoryMissile)
        missile:setDuration(effect:getDuration())
        missile:setDirection(3)
        missile:setOffset(-(spriteSize * length), 0)
        missile:setBounce(0, 15, 1000)
        missile:move(Position.translated(owner:getPosition(), length, 0), owner:getPosition())

        effect:attachEffect(missile)
    end,
    onDetach = function(effect, oldOwner)
        local e = Effect.create()
        e:setId(50)
        oldOwner:getTile():addThing(e)
    end
})

AttachedEffectManager.register(11, 'Bat', 307, ThingCategoryCreature, {
    speed = 0.5,
    offset = { 0, 0 },
    bounce = { 20, 20, 2000 }
})

AttachedEffectManager.register(301, 'Fire Aura', 301, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(302, 'Ice Aura', 302, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(303, 'Lightning Aura', 303, ThingCategoryEffect, {
    speed = 0.7,
    drawOnUI = true,
    opacity = 0.9,
    offset = { 0, -5, true }
})

-- Shop Aura Effects
AttachedEffectManager.register(176, 'Shop Aura 176', 176, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(177, 'Shop Aura 177', 177, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(178, 'Shop Aura 178', 178, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(179, 'Shop Aura 179', 179, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(180, 'Shop Aura 180', 180, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(181, 'Shop Aura 181', 181, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(316, 'Shop Aura 316', 316, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(330, 'Shop Aura 330', 330, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(334, 'Shop Aura 334', 334, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(338, 'Shop Aura 338', 338, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(339, 'Shop Aura 339', 339, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(346, 'Shop Aura 346', 346, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(350, 'Shop Aura 350', 350, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(364, 'Shop Aura 364', 364, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(366, 'Shop Aura 366', 366, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(370, 'Shop Aura 370', 370, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(388, 'Shop Aura 388', 388, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(403, 'Shop Aura 403', 403, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(405, 'Shop Aura 405', 405, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(406, 'Shop Aura 406', 406, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(407, 'Shop Aura 407', 407, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(410, 'Shop Aura 410', 410, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(411, 'Shop Aura 411', 411, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(412, 'Shop Aura 412', 412, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(416, 'Shop Aura 416', 416, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(417, 'Shop Aura 417', 417, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(436, 'Shop Aura 436', 436, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(438, 'Shop Aura 438', 438, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(439, 'Shop Aura 439', 439, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(447, 'Shop Aura 447', 447, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(448, 'Shop Aura 448', 448, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(449, 'Shop Aura 449', 449, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(450, 'Shop Aura 450', 450, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(456, 'Shop Aura 456', 456, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(457, 'Shop Aura 457', 457, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(458, 'Shop Aura 458', 458, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(459, 'Shop Aura 459', 459, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(461, 'Shop Aura 461', 461, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(466, 'Shop Aura 466', 466, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(468, 'Shop Aura 468', 468, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(477, 'Shop Aura 477', 477, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(488, 'Shop Aura 488', 488, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(489, 'Shop Aura 489', 489, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(490, 'Shop Aura 490', 490, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(498, 'Shop Aura 498', 498, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(499, 'Shop Aura 499', 499, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(500, 'Shop Aura 500', 500, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(501, 'Shop Aura 501', 501, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(511, 'Shop Aura 511', 511, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(514, 'Shop Aura 514', 514, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(516, 'Shop Aura 516', 516, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(517, 'Shop Aura 517', 517, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(520, 'Shop Aura 520', 520, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(523, 'Shop Aura 523', 523, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(529, 'Shop Aura 529', 529, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(530, 'Shop Aura 530', 530, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(531, 'Shop Aura 531', 531, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(532, 'Shop Aura 532', 532, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(533, 'Shop Aura 533', 533, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(534, 'Shop Aura 534', 534, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(535, 'Shop Aura 535', 535, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(539, 'Shop Aura 539', 539, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(540, 'Shop Aura 540', 540, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(543, 'Shop Aura 543', 543, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(544, 'Shop Aura 544', 544, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(545, 'Shop Aura 545', 545, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(548, 'Shop Aura 548', 548, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(559, 'Shop Aura 559', 559, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(565, 'Shop Aura 565', 565, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(566, 'Shop Aura 566', 566, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(636, 'Shop Aura 636', 636, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(659, 'Shop Aura 659', 659, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(896, 'Shop Aura 896', 896, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(898, 'Shop Aura 898', 898, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(935, 'Shop Aura 935', 935, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(954, 'Shop Aura 954', 954, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(955, 'Shop Aura 955', 955, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(960, 'Shop Aura 960', 960, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(962, 'Shop Aura 962', 962, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(965, 'Shop Aura 965', 965, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(985, 'Shop Aura 985', 985, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(986, 'Shop Aura 986', 986, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(987, 'Shop Aura 987', 987, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(988, 'Shop Aura 988', 988, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(990, 'Shop Aura 990', 990, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(991, 'Shop Aura 991', 991, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(1070, 'Shop Aura 1070', 1070, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})

AttachedEffectManager.register(777, 'Shop Aura 777', 777, ThingCategoryEffect, {
    speed = 0.8,
    drawOnUI = true,
    opacity = 0.85,
    offset = { 0, -5, true }
})
