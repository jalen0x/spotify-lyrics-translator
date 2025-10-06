class CreateLyricCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :lyric_caches do |t|
      t.text :original_text, null: false
      t.text :translated_text, null: false

      t.timestamps
    end

    add_index :lyric_caches, :original_text, unique: true, length: 255
  end
end
