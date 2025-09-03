class CreateChats < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.text :message
      t.string :role
      t.string :session_id

      t.timestamps
    end

    add_index :chats, :session_id
    add_index :chats, [:session_id, :created_at]
  end
end
