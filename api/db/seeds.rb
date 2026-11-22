# Seed data for development: Polish classics, a few readers, and multiple copies for some books.
# This is idempotent: uses find_or_create_by / find_or_initialize_by on stable keys.

books = [
  { title: "Lalka", author: "Bolesław Prus", copies: [100001, 100002] },
  { title: "Pan Tadeusz", author: "Adam Mickiewicz", copies: [100003, 100004, 100005] },
  { title: "Quo Vadis", author: "Henryk Sienkiewicz", copies: [100006] },
  { title: "Ferdydurke", author: "Witold Gombrowicz", copies: [100007] },
  { title: "Solaris", author: "Stanisław Lem", copies: [100008] }
]

ActiveRecord::Base.transaction do
  books.each do |attrs|
    book = Book.find_or_create_by!(title: attrs[:title], author: attrs[:author])
    attrs[:copies].each do |serial|
      BookCopy.find_or_create_by!(book: book, serial_number: serial)
    end
  end

  [
    { card_number: 123456, full_name: "Jan Kowalski",   email: "jan.kowalski@example.pl" },
    { card_number: 234567, full_name: "Anna Nowak",     email: "anna.nowak@example.pl" },
    { card_number: 345678, full_name: "Piotr Zieliński", email: "piotr.zielinski@example.pl" }
  ].each do |r|
    reader = Reader.find_or_initialize_by(card_number: r[:card_number])
    reader.full_name = r[:full_name]
    reader.email = r[:email]
    reader.save!
  end
end
