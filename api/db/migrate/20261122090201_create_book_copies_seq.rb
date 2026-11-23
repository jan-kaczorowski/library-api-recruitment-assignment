class CreateBookCopiesSeq < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE SEQUENCE book_copies_serial_number_seq
        START 100000 MINVALUE 100000 MAXVALUE 999999 NO CYCLE
        OWNED BY book_copies.serial_number;
    SQL
    # Lambda so Rails emits raw SQL instead of a quoted string literal
    change_column_default :book_copies, :serial_number, -> { "nextval('book_copies_serial_number_seq')" }
  end

  def down
    change_column_default :book_copies, :serial_number, nil
    execute <<~SQL
        DROP SEQUENCE IF EXISTS book_copies_serial_number_seq;
    SQL
  end
end
