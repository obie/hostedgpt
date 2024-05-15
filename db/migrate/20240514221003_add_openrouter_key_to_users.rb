class AddOpenrouterKeyToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :openrouter_key, :string
  end
end
