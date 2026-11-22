class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |t|
      t.integer :card_number, null: false
      t.string :full_name, null: false
      t.string :email, null: false
      t.timestamps

      t.check_constraint "card_number BETWEEN 100000 AND 999999",
        name: "readers_card_number_six_digits"
      t.check_constraint "email <> '' AND email = lower(trim(email))",
        name: "readers_email_normalized"
      t.index :card_number, unique: true
      t.index :email, unique: true
    end
  end
end
