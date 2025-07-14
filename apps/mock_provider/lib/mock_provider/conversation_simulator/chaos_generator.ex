defmodule MockProvider.ChaosGenerator do
  @moduledoc """
  Helper module for generating random chaos scenarios with random participants
  and random word combinations for message content.
  """

  # vibes
  @random_words [
    "slay", "periodt", "no-cap", "bussin", "fire", "drip", "flex", "vibe", "sus", "bet",
    "fam", "ghosted", "simp", "stan", "tea", "spill", "oop", "yeet", "sheesh", "mid",
    "cringe", "based", "ratio", "cope", "lowkey", "highkey", "deadass", "bruh", "fr", "ong",
    "bestie", "girlie", "sending", "clapped", "slaps", "bops", "bangers", "hits-different", "understood-the-assignment",
    "rent-free", "main-character", "villain-era", "soft-launch", "hard-launch", "gatekeep", "gaslight", "girlboss",
    "rizz", "W", "L", "ratio", "touch-grass", "go-off", "pop-off", "periodt", "ate-and-left-no-crumbs",
    "cleared", "serve", "served", "purr", "icon", "legend", "moment", "iconic", "legendary",
    "mother", "father", "parent", "offspring", "child", "baby", "bestie", "babe", "love",
    "queen", "king", "royalty", "crown", "throne", "palace", "empire", "dynasty", "reign",
    "snatched", "fierce", "gorgeous", "stunning", "beautiful", "pretty", "cute", "adorable", "perfect",
    "flawless", "immaculate", "pristine", "clean", "fresh", "crisp", "sharp", "smooth", "sleek",
    "chefs-kiss", "no-notes", "ten-out-of-ten", "hundred", "million", "billion", "infinite", "endless",
    "forever", "always", "never", "sometimes", "maybe", "perhaps", "definitely", "absolutely", "totally",
    "completely", "entirely", "wholly", "fully", "partially", "somewhat", "kinda", "sorta", "basically",
    "literally", "actually", "honestly", "truly", "really", "genuinely", "seriously", "obviously", "clearly",
    "apparently", "supposedly", "allegedly", "reportedly", "presumably", "theoretically", "hypothetically", "potentially",
    "possibly", "probably", "likely", "unlikely", "doubtful", "questionable", "suspicious", "sketchy", "shady",
    "valid", "invalid", "legit", "fake", "real", "authentic", "genuine", "original", "unique",
    "special", "rare", "common", "basic", "extra", "dramatic", "intense", "extreme", "wild",
    "crazy", "insane", "mental", "psycho", "unhinged", "chaotic", "random", "weird", "strange",
    "odd", "bizarre", "unusual", "different", "unique", "special", "interesting", "cool", "awesome",
    "amazing", "incredible", "fantastic", "wonderful", "great", "good", "okay", "meh", "bad",
    "terrible", "awful", "horrible", "disgusting", "gross", "nasty", "icky", "yucky", "eww",
    "ugh", "bruh", "wtf", "omg", "lol", "lmao", "rofl", "dead", "deceased", "gone",
    "sent", "done", "finished", "over", "through", "complete", "ready", "prepared", "set",
    "go", "stop", "wait", "pause", "play", "fast-forward", "rewind", "repeat", "shuffle",
    "loop", "skip", "next", "previous", "first", "last", "middle", "beginning", "end",
    "start", "finish", "begin", "conclude", "wrap-up", "close", "open", "unlock", "lock",
    "secure", "safe", "protected", "guarded", "watched", "monitored", "tracked", "followed", "stalked",
    "obsessed", "addicted", "hooked", "attached", "connected", "linked", "joined", "united", "together",
    "apart", "separate", "divided", "split", "broken", "fixed", "repaired", "restored", "renewed"
  ]



  @doc """
  Generates a random US phone number with 555 area code.
  """
  def generate_random_phone do
    # Generate a US phone number format +1555NNNNNNN with 555 area code
    exchange = Enum.random(200..999)
    number = Enum.random(1000..9999)
    "+1555#{exchange}#{number}"
  end

  @doc """
  Generates a list of random messages alternating between two participants.
  """
  def generate_chaos_messages(phone1, phone2, count) do
    1..count
    |> Enum.map(fn index ->
      # Alternate between participants
      {from, to} = if rem(index, 2) == 1, do: {phone1, phone2}, else: {phone2, phone1}

      # Alternate between API and webhook endpoints
      endpoint = if rem(index, 2) == 1, do: "webhook", else: "api"

      # Random delay between 0 and 5 seconds
      delay = Enum.random(0..5000)

      # Generate random word salad message (2-8 words)
      word_count = Enum.random(2..8)
      body = generate_random_message(word_count)

      %{
        from: from,
        to: to,
        body: body,
        delay: delay,
        endpoint: endpoint
      }
    end)
  end

  @doc """
  Generates a random message with the specified number of words.
  """
  def generate_random_message(word_count) do
    @random_words
    |> Enum.take_random(word_count)
    |> Enum.join(" ")
  end
end
