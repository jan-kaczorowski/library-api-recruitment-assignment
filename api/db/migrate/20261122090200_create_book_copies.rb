class CreateBookCopies < ActiveRecord::Migration[8.1]
  def change
    create_table :book_copies do |t|
      t.references :book, null: false, foreign_key: true
      t.integer :serial_number, null: false
      t.datetime :archived_at
      t.timestamps

      t.check_constraint "serial_number BETWEEN 100000 AND 999999",
        name: "book_copies_serial_number_six_digits"
      t.index :serial_number, unique: true
    end
  end
end
