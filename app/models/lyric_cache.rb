class LyricCache < ApplicationRecord
  validates :original_text, presence: true, uniqueness: true
  validates :translated_text, presence: true

  def self.fetch_translation(original_text)
    find_by(original_text: original_text)&.translated_text
  end

  def self.store_translation(original_text, translated_text)
    create!(original_text: original_text, translated_text: translated_text)
  rescue ActiveRecord::RecordNotUnique
    find_by(original_text: original_text)&.translated_text
  end
end
