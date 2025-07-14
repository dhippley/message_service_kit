defmodule MockProvider.SimulationGenerator do
  @moduledoc """
  Module for generating different types of conversation simulation scenarios.
  """

  alias MockProvider.ChaosGenerator

  @doc """
  Generates a complete chaos scenario with random participants and messages.
  """
  def generate_chaos_scenario do
    # Generate two random phone numbers
    phone1 = ChaosGenerator.generate_random_phone()
    phone2 = ChaosGenerator.generate_random_phone()

    # Random number of messages (between 4 and 12)
    message_count = Enum.random(4..12)

    # Generate random messages alternating between the two participants
    messages = ChaosGenerator.generate_chaos_messages(phone1, phone2, message_count)

    %{
      name: "chaos",
      participants: %{
        participant_a: phone1,
        participant_b: phone2
      },
      messages: messages
    }
  end

  @doc """
  Generates the epic dialogue between Gandalf, Aragorn and the Mouth of Sauron at the Black Gate.
  """
  def generate_lotr_black_gate_scenario do
    # Generate random phone numbers for the participants
    gandalf_phone = ChaosGenerator.generate_random_phone()
    mouth_of_sauron_phone = ChaosGenerator.generate_random_phone()

    %{
      name: "lotr_black_gate",
      participants: %{
        gandalf: gandalf_phone,
        mouth_of_sauron: mouth_of_sauron_phone
      },
      # Mouth of Sauron uses webhook (incoming threats), Gandalf/Aragorn uses API (outgoing responses)
      messages: [
        %{from: gandalf_phone, to: mouth_of_sauron_phone, body: "*Aragorn shouting* Let the Lord of the Black Land come forth! Let justice be done upon him", delay: 0, endpoint: "api"},
        %{from: mouth_of_sauron_phone, to: gandalf_phone, body: "*black gate opens slowly* My master Sauron the Great bids thee welcome. Is there any in this rout with authority to treat with me?", delay: 3000, endpoint: "webhook"},
        %{from: gandalf_phone, to: mouth_of_sauron_phone, body: "We do not come to treat with Sauron, faithless and accursed. Tell your master this: the armies of Mordor must disband. He is to depart these lands, never to return.", delay: 3000, endpoint: "api"},
        %{from: mouth_of_sauron_phone, to: gandalf_phone, body: "Old Greybeard! I have a token I was bidden to show thee. *throws mithril shirt*", delay: 4000, endpoint: "webhook"},
        %{from: gandalf_phone, to: mouth_of_sauron_phone, body: "Silence!", delay: 2000, endpoint: "api"},
        %{from: mouth_of_sauron_phone, to: gandalf_phone, body: "The Halfling was dear to thee, I see. Know that he suffered greatly at the hands of his host. Who would've thought on so small could endure so much pain? And he did Gandalf, he did", delay: 3500, endpoint: "webhook"},
        %{from: mouth_of_sauron_phone, to: gandalf_phone, body: "And who is this? Isildur's heir? It takes more to make a king than a broken elvish blade", delay: 3500, endpoint: "webhook"},
        %{from: gandalf_phone, to: mouth_of_sauron_phone, body: "*rides forward with Andúril raised shouting* I do not believe it! I will not!", delay: 2500, endpoint: "api"},
      ]
    }
  end
end
