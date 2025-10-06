# frozen_string_literal: true

class TranslateController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_api_key

  def create
    lines = params[:lines]

    if lines.blank? || !lines.is_a?(Array)
      render json: { error: "Request body must include non-empty 'lines' array" }, status: :bad_request
      return
    end

    translations = translate_lines(lines)
    render json: { translations: translations }
  rescue StandardError => e
    Rails.logger.error("Translation failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    render json: { translations: lines }
  end

  private

  def verify_api_key
    api_key = request.headers["X-API-Key"]
    expected_key = Rails.application.credentials.api_key

    if api_key.blank? || api_key != expected_key
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def build_translation_prompt
    <<~PROMPT
      You are a translation engine for Spotify lyrics.

      GOAL
      Translate each input lyric line to Simplified Chinese (zh-CN).

      RULES
      - Preserve the input order exactly; output MUST have the same number of elements as input.
      - If a line is already in Simplified Chinese, return it unchanged.
      - If a line contains only symbols, punctuation, or whitespace, return it unchanged.
      - Do NOT add explanations, numbering, or extra fields.

      OUTPUT (VALID JSON ONLY; no extra text, no code fences)
      ["<translated_line_1>", "<translated_line_2>", ...]

      Each element is a string; the array length MUST match the input array length.
    PROMPT
  end

  def translate_lines(lines)
    translations = []
    lines_to_translate = []
    line_indices = []

    lines.each_with_index do |line, index|
      cached = LyricCache.fetch_translation(line)
      if cached
        translations[index] = cached
      else
        lines_to_translate << line
        line_indices << index
      end
    end

    if lines_to_translate.any?
      new_translations = call_openai_api(lines_to_translate)

      new_translations.each_with_index do |translated, i|
        original = lines_to_translate[i]
        index = line_indices[i]

        translations[index] = translated
        LyricCache.store_translation(original, translated)
      end
    end

    translations
  end

  def call_openai_api(lines)
    base_url = Rails.application.credentials.openai.base_url.chomp("/")

    client = OpenAI::Client.new(
      api_key: Rails.application.credentials.openai.api_key,
      base_url: base_url
    )

    response = client.chat.completions.create(
      model: Rails.application.credentials.openai.model,
      messages: [
        {
          role: "system",
          content: build_translation_prompt
        },
        {
          role: "user",
          content: lines.to_json
        }
      ]
    )

    content = response.choices.first.message.content
    raise "Missing translation content in OpenAI response" if content.blank?

    translations = JSON.parse(content.strip)
    translations.is_a?(Array) ? translations : []
  end
end
