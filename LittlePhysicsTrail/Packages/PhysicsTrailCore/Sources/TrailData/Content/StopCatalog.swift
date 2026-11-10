//
//  StopCatalog.swift
//  TrailData
//
//  All journey content, in journey order. One stop per big physics idea, ten items each.
//  Facts are written for ages 4–8: one or two short sentences, read aloud after a correct drop.
//  See docs/CURRICULUM.md for learning goals and docs/ADDING_A_STOP.md before editing.
//

import TrailDomain

public enum StopCatalog {

    public static let all: [JourneyStop] = [
        sinkOrFloat, magnets, pushOrPull, light, hotAndCold, sound, ramp, matter,
    ]

    // MARK: 1 · Buoyancy

    static let sinkOrFloat = JourneyStop(
        id: "float",
        title: "Sink or Float",
        emoji: "🛁",
        theme: .sky,
        bigIdea: BigIdea(
            headline: "Light-for-its-size things float!",
            explanation: "Water pushes up on everything in it. If a thing is light for its size, that push holds it up and it floats. If it is heavy for its size, it sinks.",
            tryAtHome: "Fill a bowl with water. Guess first, then test a spoon, a cork and an orange!"
        ),
        question: "Will it sink or float?",
        bins: [SortBin(id: "float", title: "Floats", emoji: "🛟"), SortBin(id: "sink", title: "Sinks", emoji: "⚓️")],
        items: [
            item("duck", "Rubber duck", "🦆", "float", "The duck is full of air, so it is light for its size and floats."),
            item("rock", "Rock", "🪨", "sink", "A rock is heavy for its size, so it sinks to the bottom."),
            item("apple", "Apple", "🍎", "float", "Apples have tiny pockets of air inside, so they float!"),
            item("coin", "Coin", "🪙", "sink", "A coin is small, but its metal is heavy for its size. Down it goes!"),
            item("leaf", "Leaf", "🍃", "float", "A leaf is thin and light, so the water holds it up."),
            item("key", "Key", "🔑", "sink", "Metal keys are heavy for their size, so they sink."),
            item("wood", "Log", "🪵", "float", "Wood is lighter than water. That is why logs float down rivers."),
            item("ball", "Beach ball", "🏐", "float", "A ball full of air bobs right on top of the water."),
            item("spoon", "Spoon", "🥄", "sink", "A metal spoon is heavy for its size, so it sinks."),
            item("ship", "Big ship", "🚢", "float", "Ships are made of heavy metal, but their hollow shape is full of air. So they float!"),
        ],
        finishTitle: "Splash! You're a floating expert! 🎉"
    )

    // MARK: 2 · Magnetism

    static let magnets = JourneyStop(
        id: "magnets",
        title: "Magnet Magic",
        emoji: "🧲",
        theme: .coral,
        bigIdea: BigIdea(
            headline: "Magnets pull on iron and steel!",
            explanation: "A magnet has an invisible pull. It pulls things made of iron or steel. It does not pull wood, plastic, paper, cloth or food.",
            tryAtHome: "Take a fridge magnet on a hunt around the kitchen. What sticks?"
        ),
        question: "Will the magnet pull it?",
        bins: [SortBin(id: "sticks", title: "Sticks", emoji: "🧲"), SortBin(id: "nope", title: "No pull", emoji: "🚫")],
        items: [
            item("clip", "Paper clip", "📎", "sticks", "Paper clips are made of steel, and magnets pull on steel!"),
            item("pencil", "Pencil", "✏️", "nope", "A pencil is mostly wood. Magnets can't pull wood."),
            item("bolt", "Nut and bolt", "🔩", "sticks", "Bolts are made of steel, so the magnet pulls them close."),
            item("teddy", "Teddy bear", "🧸", "nope", "Cloth and stuffing aren't metal, so the magnet leaves them alone."),
            item("screwdriver", "Screwdriver", "🪛", "sticks", "The tip of a screwdriver is steel. Click, it jumps to the magnet!"),
            item("apple", "Apple", "🍎", "nope", "Food isn't iron or steel, so there is no pull."),
            item("chain", "Chain", "⛓️", "sticks", "A steel chain sticks to a magnet one link after another."),
            item("paper", "Drawing", "📄", "nope", "Magnets don't pull paper — but they pull right through it. That's how fridge magnets hold drawings!"),
            item("pin", "Safety pin", "🧷", "sticks", "Safety pins are steel, so a magnet can pick them up."),
            item("cup", "Plastic cup", "🥤", "nope", "Plastic isn't metal. The magnet can't feel it at all."),
        ],
        finishTitle: "Click! You found the magnet's friends! 🎉"
    )

    // MARK: 3 · Forces

    static let pushOrPull = JourneyStop(
        id: "forces",
        title: "Push or Pull",
        emoji: "💪",
        theme: .orange,
        bigIdea: BigIdea(
            headline: "A force is a push or a pull!",
            explanation: "Things don't move by themselves. A push moves something away from you. A pull brings it closer. Pushes and pulls are called forces.",
            tryAtHome: "Roll a toy car. Give it a gentle push, then a big push. Which goes farther?"
        ),
        question: "Is it a push or a pull?",
        bins: [SortBin(id: "push", title: "Push", emoji: "🫸"), SortBin(id: "pull", title: "Pull", emoji: "🪢")],
        items: [
            item("cart", "Shopping cart", "🛒", "push", "You push a cart to make it roll away from you."),
            item("kite", "Kite string", "🪁", "pull", "You pull the string to bring your kite closer."),
            item("kick", "Kicking a ball", "⚽️", "push", "A kick is a quick push that sends the ball flying."),
            item("sled", "Sled rope", "🛷", "pull", "You pull a sled up the hill by its rope."),
            item("bell", "Doorbell button", "🔔", "push", "You push the button to ring the bell. Ding dong!"),
            item("fish", "Reeling a fish", "🎣", "pull", "Reeling in the line pulls the fish toward you."),
            item("piano", "Piano key", "🎹", "push", "Each key you push makes a little hammer hit a string."),
            item("socks", "Socks on", "🧦", "pull", "You pull your socks up onto your feet."),
            item("carrot", "Carrot from soil", "🥕", "pull", "You pull a carrot to get it out of the ground."),
            item("highfive", "High five", "🖐️", "push", "In a high five, two hands push on each other. Smack!"),
        ],
        finishTitle: "Wow, what a strong scientist! 🎉"
    )

    // MARK: 4 · Light

    static let light = JourneyStop(
        id: "light",
        title: "Light & Shadow",
        emoji: "💡",
        theme: .sun,
        bigIdea: BigIdea(
            headline: "Some things make light, some bounce it!",
            explanation: "The Sun, a lamp and a candle make their own light. Most other things only bounce light into our eyes — that's how we see them. When something blocks light, it makes a shadow.",
            tryAtHome: "In a dark room, shine a flashlight on your hand to make shadow animals on the wall."
        ),
        question: "Does it make its own light?",
        bins: [SortBin(id: "glows", title: "Makes light", emoji: "✨"), SortBin(id: "dark", title: "No light", emoji: "🌑")],
        items: [
            item("sun", "Sun", "☀️", "glows", "The Sun is a giant hot star. It makes the light for our whole day!"),
            item("bulb", "Light bulb", "💡", "glows", "Electricity makes the bulb glow bright."),
            item("moon", "Moon", "🌙", "dark", "Surprise! The Moon has no light of its own. It shines because sunlight bounces off it."),
            item("flashlight", "Flashlight", "🔦", "glows", "A battery powers a little bulb that makes light."),
            item("mirror", "Mirror", "🪞", "dark", "A mirror doesn't make light. It bounces light back so you can see yourself."),
            item("candle", "Candle", "🕯️", "glows", "The hot flame of a candle gives off light."),
            item("books", "Books", "📚", "dark", "Books need light to be seen. In the dark, you can't read them!"),
            item("star", "Star", "⭐️", "glows", "Stars are faraway suns making their own light."),
            item("diamond", "Diamond", "💎", "dark", "Diamonds sparkle by bouncing light around — they don't make any."),
            item("fire", "Campfire", "🔥", "glows", "Fire makes heat and light. That's why it glows at night."),
        ],
        finishTitle: "You lit up the trail! 🎉"
    )

    // MARK: 5 · Heat

    static let hotAndCold = JourneyStop(
        id: "heat",
        title: "Hot & Cold",
        emoji: "🌡️",
        theme: .pink,
        bigIdea: BigIdea(
            headline: "Heat moves from hot to cold!",
            explanation: "Heat is a kind of energy. It always moves from hot things into cold things. That's why ice melts in your warm hand, and cocoa warms your fingers.",
            tryAtHome: "Hold an ice cube in your hand for a moment. Feel how your hand gets cold as the ice melts?"
        ),
        question: "Is it hot or cold?",
        bins: [SortBin(id: "hot", title: "Hot", emoji: "🔥"), SortBin(id: "cold", title: "Cold", emoji: "❄️")],
        items: [
            item("cocoa", "Hot cocoa", "☕️", "hot", "Heat from the cocoa moves into your hands and warms them up."),
            item("icecream", "Ice cream", "🍦", "cold", "Ice cream melts because heat from warm air moves into it."),
            item("ice", "Ice cube", "🧊", "cold", "Ice is frozen water. Warm it up and it melts!"),
            item("volcano", "Volcano", "🌋", "hot", "Lava is melted rock — much hotter than an oven!"),
            item("snowman", "Snowman", "⛄️", "cold", "A snowman stays frozen while the air is colder than ice."),
            item("soup", "Soup", "🍲", "hot", "Blow on hot soup! Moving air carries the heat away."),
            item("desert", "Desert", "🏜️", "hot", "Strong sunshine heats the desert sand all day."),
            item("mountain", "Snowy mountain", "🏔️", "cold", "High up on a mountain the air is colder, so snow stays."),
            item("pizza", "Fresh pizza", "🍕", "hot", "The oven's heat moved into the pizza and baked it."),
            item("popsicle", "Shaved ice", "🍧", "cold", "Shaved ice is tiny bits of ice — brrr!"),
        ],
        finishTitle: "Hot stuff! You did it! 🎉"
    )

    // MARK: 6 · Sound

    static let sound = JourneyStop(
        id: "sound",
        title: "Loud & Quiet",
        emoji: "🔊",
        theme: .teal,
        bigIdea: BigIdea(
            headline: "Sound is a wiggle!",
            explanation: "Sounds are made when things wiggle back and forth very fast. Scientists call it vibrating. Big wiggles make loud sounds, tiny wiggles make quiet sounds.",
            tryAtHome: "Put your fingers on your throat and hum. Can you feel the wiggle?"
        ),
        question: "Is it loud or quiet?",
        bins: [SortBin(id: "loud", title: "Loud", emoji: "📢"), SortBin(id: "quiet", title: "Quiet", emoji: "🤫")],
        items: [
            item("drum", "Drum", "🥁", "loud", "Hit a drum and its skin wiggles big and fast. BOOM!"),
            item("mouse", "Mouse squeak", "🐭", "quiet", "A tiny mouse makes a tiny squeak."),
            item("rocket", "Rocket", "🚀", "loud", "Rocket engines shake the air so hard you can feel the sound!"),
            item("leaves", "Rustling leaves", "🍃", "quiet", "Leaves brushing together make a soft swish."),
            item("siren", "Siren", "🚨", "loud", "Sirens are loud on purpose so everyone hears them."),
            item("cat", "Cat purring", "🐱", "quiet", "A purr is a soft rumble made by little wiggles in the cat's throat."),
            item("lion", "Lion roar", "🦁", "loud", "A lion's roar can be heard far, far away!"),
            item("feather", "Falling feather", "🪶", "quiet", "A feather lands so gently it makes almost no sound."),
            item("trumpet", "Trumpet", "🎺", "loud", "Your lips buzz and make the air inside the trumpet vibrate. Toot!"),
            item("snail", "Snail sliding", "🐌", "quiet", "A slow snail slides along without a sound."),
        ],
        finishTitle: "Hooray! Your ears are super smart! 🎉"
    )

    // MARK: 7 · Gravity, motion & friction

    static let ramp = JourneyStop(
        id: "ramp",
        title: "Down the Ramp",
        emoji: "🛝",
        theme: .mint,
        bigIdea: BigIdea(
            headline: "Gravity pulls, round things roll!",
            explanation: "Gravity pulls everything down toward the ground. On a ramp, round things roll down easily. Flat things slide, and rubbing called friction slows them down.",
            tryAtHome: "Lean a book against a pillow to make a ramp. Race a ball and a toy block down it!"
        ),
        question: "Will it roll or slide down the ramp?",
        bins: [SortBin(id: "roll", title: "Rolls", emoji: "🛞"), SortBin(id: "slide", title: "Slides", emoji: "⛸️")],
        items: [
            item("ball", "Soccer ball", "⚽️", "roll", "A ball is round all over, so it rolls and rolls."),
            item("box", "Box", "📦", "slide", "A box has flat sides that rub on the ramp. That rubbing is friction."),
            item("orange", "Orange", "🍊", "roll", "Round like a ball, an orange rolls right down."),
            item("brick", "Brick", "🧱", "slide", "A heavy flat brick scrapes slowly down the ramp."),
            item("bowling", "Bowling ball", "🎳", "roll", "Gravity pulls the round bowling ball — it rolls fast!"),
            item("book", "Book", "📕", "slide", "A book lies flat, so it slides instead of rolling."),
            item("skateboard", "Skateboard", "🛹", "roll", "A skateboard is flat, but its wheels are round. So it rolls!"),
            item("dice", "Dice", "🎲", "slide", "Dice have flat faces, so they tumble and slide."),
            item("poolball", "Pool ball", "🎱", "roll", "Smooth and round, a pool ball rolls with very little friction."),
            item("sponge", "Sponge", "🧽", "slide", "A rough sponge has lots of friction. It barely slides at all!"),
        ],
        finishTitle: "Wheee! You rolled to the end! 🎉"
    )

    // MARK: 8 · States of matter

    static let matter = JourneyStop(
        id: "matter",
        title: "Solid, Liquid, Gas",
        emoji: "🧪",
        theme: .purple,
        bigIdea: BigIdea(
            headline: "Stuff can be solid, liquid or gas!",
            explanation: "Everything is made of tiny bits. In a solid they hold tight, so it keeps its shape. In a liquid they slide around, so it pours. In a gas they zoom everywhere and fill up the space.",
            tryAtHome: "Watch an ice cube in a cup: solid ice turns into liquid water. With a grown-up, see steam rise from a hot pot!"
        ),
        question: "Is it a solid, a liquid or a gas?",
        bins: [
            SortBin(id: "solid", title: "Solid", emoji: "🧱"),
            SortBin(id: "liquid", title: "Liquid", emoji: "💧"),
            SortBin(id: "gas", title: "Gas", emoji: "💨"),
        ],
        items: [
            item("ice", "Ice cube", "🧊", "solid", "Ice is solid water. It keeps its shape until it melts."),
            item("milk", "Milk", "🥛", "liquid", "Milk pours and takes the shape of the glass."),
            item("steam", "Steam", "♨️", "gas", "When water gets very hot, it turns into a gas called steam."),
            item("rock", "Rock", "🪨", "solid", "A rock is a solid. It stays the same shape wherever you put it."),
            item("honey", "Honey", "🍯", "liquid", "Honey is a slow, sticky liquid — but it still pours!"),
            item("wind", "Wind", "🌬️", "gas", "Wind is moving air, and air is a gas. You can't see it, but you can feel it!"),
            item("chair", "Chair", "🪑", "solid", "You can sit on a chair because solids hold their shape."),
            item("juice", "Juice", "🧃", "liquid", "Juice is a liquid. Squeeze the box and it flows through the straw."),
            item("balloon", "Air in a balloon", "🎈", "gas", "A gas spreads out to fill the whole balloon."),
            item("bubbles", "Air in bubbles", "🫧", "gas", "Bubbles are tiny balls of gas wrapped in soapy water."),
        ],
        finishTitle: "Amazing! You're a matter master! 🎉"
    )

    private static func item(_ id: String, _ name: String, _ emoji: String, _ binID: String, _ fact: String) -> SortItem {
        SortItem(id: id, name: name, emoji: emoji, binID: binID, fact: fact)
    }
}

/// Serves the built-in catalog.
public struct StaticStopRepository: StopRepository {
    private let stops: [JourneyStop]

    public init(stops: [JourneyStop] = StopCatalog.all) {
        self.stops = stops
    }

    public func allStops() -> [JourneyStop] { stops }
}
