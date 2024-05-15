class AIBackends::OpenRouter
  attr :client

  # Rails system tests don't seem to allow mocking because the server and the
  # test are in separate processes.
  #
  # In regular tests, mock this method or the TestClients::OpenAI class to do
  # what you want instead.
  def self.client
    if Rails.env.test?
      TestClients::OpenAI
    else
      ::OpenRouter::Client
    end
  end

  # Example model record {"id":"nousresearch/nous-capybara-7b:free","name":"Nous: Capybara 7B (free)","description":"The Capybara series is a collection of datasets and models made by fine-tuning on data created by Nous, mostly in-house.\n\nV1.9 uses unalignment techniques for more consistent and dynamic control. It also leverages a significantly better foundation model, [Mistral 7B](/models/mistralai/mistral-7b-instruct).\n\nNote: this is a free, rate-limited version of [this model](/models/nousresearch/nous-capybara-7b). Outputs may be cached. Read about rate limits [here](/docs#limits).","pricing":{"prompt":"0","completion":"0","image":"0","request":"0"},"context_length":4096,"architecture":{"modality":"text","tokenizer":"Mistral","instruct_type":"airoboros"},"top_provider":{"max_completion_tokens":null,"is_moderated":false},"per_request_limits":{"prompt_tokens":"Infinity","completion_tokens":"Infinity"}}
  def self.models(id=nil)
    @models ||= begin
      access_token = User.where.not(openrouter_key: nil).pluck(:openrouter_key).first
      client.new(access_token:).models
    end

    @models.tap do |list|
      return list.find { |m| m["id"] == id } if id.present?
    end
  end

  def self.model_options
    models.sort_by { |m| m["name"] }.collect do |model|
      [model["name"], model["id"]]
    end
  end

  def initialize(user, assistant, conversation, message)
    @client = self.class.client.new(access_token: user.openai_key)
    @assistant = assistant
    @conversation = conversation
    @message = message
  end

  def get_next_chat_message(&chunk_received_handler)
    stream_response_text = ""

    response_handler = proc do |intermediate_response, bytesize|
      chunk = intermediate_response.dig("choices", 0, "delta", "content")
      print chunk if Rails.env.development?
      if chunk
        stream_response_text += chunk
        yield chunk
      end
    rescue ::GetNextAIMessageJob::ResponseCancelled => e
      raise e
    rescue ::Faraday::UnauthorizedError => e
      raise "OpenRouter key is invalid. Please update your key in your account settings. #{e.message}"
    rescue => e
      puts "\nUnhandled error in AIBackends::OpenRouter response handler: #{e.message}"
      puts e.backtrace
    end

    response_handler = nil unless block_given?

    response = @client.complete(
      system_message + preceding_messages,
      model: @assistant.model,
      stream: response_handler,
      extras: {
        max_tokens: 2_000, # we should really set this dynamically, based on the model, to the max
        # todo: add many more additional parameters here
      }
    )

    response_text = if response.is_a?(Hash) && response.dig("choices")
      response.dig("choices", 0, "message", "content")
    else
      response
    end

    if response_text.blank? && stream_response_text.blank?
      raise ::Faraday::ParsingError
    else
      response_text
    end
  end

  private

  def system_message
    return [] if @assistant.instructions.blank?

    [{
      role: 'system',
      content: @assistant.instructions
    }]
  end

  def preceding_messages
    @conversation.messages.for_conversation_version(@message.version).where("messages.index < ?", @message.index).collect do |message|
      if @assistant.images && message.documents.present?

        content = [{ type: "text", text: message.content_text }]
        content += message.documents.collect do |document|
          { type: "image_url", image_url: { url: document.file_data_url(:large) }}
        end

        {
          role: message.role,
          content: content
        }
      else
        {
          role: message.role,
          content: message.content_text || ""
        }
      end
    end
  end
end
