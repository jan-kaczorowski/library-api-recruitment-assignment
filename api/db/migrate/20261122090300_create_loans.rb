class CreateLoans < ActiveRecord::Migration[8.1]
  def change
    create_table :loans do |t|
      t.references :book_copy, null: false, foreign_key: true, index: false
      t.references :reader, null: false, foreign_key: true
      t.datetime :borrowed_at, null: false
      t.date :due_on, null: false
      t.datetime :returned_at
      t.datetime :three_day_reminder_sent_at
      t.datetime :due_day_reminder_sent_at
      t.timestamps

      t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at",
        name: "loans_return_after_checkout"
      t.index [ :book_copy_id, :borrowed_at ]
      t.index :book_copy_id, unique: true, where: "returned_at IS NULL",
        name: "idx_loans_one_open_per_copy"
      t.index :due_on, where: "returned_at IS NULL",
        name: "idx_loans_open_by_due_on"
    end
  end
end
