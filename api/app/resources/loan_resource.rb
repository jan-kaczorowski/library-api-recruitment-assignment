class LoanResource
  include Alba::Resource

  attributes :id, :borrowed_at, :due_on, :returned_at

  one :reader, resource: ReaderResource
end
